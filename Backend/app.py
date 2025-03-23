from flask import Flask, jsonify, request
import wikipediaapi
import wikipedia
import requests
import os
from flask_bcrypt import Bcrypt
from pymongo import MongoClient
import re
from dotenv import load_dotenv
from datetime import datetime


# Add these imports at the top
from functools import lru_cache
import time
from cachelib import SimpleCache
import threading

# Create a cache object
cache = SimpleCache()

# Create global variables for BERT model
global_tokenizer = None
global_model = None

# Load BERT model in a separate thread at startup
def load_bert_model():
    global global_tokenizer, global_model
    try:
        from transformers import BertTokenizer, BertForSequenceClassification
        print("Loading BERT model and tokenizer...")
        global_tokenizer = BertTokenizer.from_pretrained('bert-base-uncased')
        global_model = BertForSequenceClassification.from_pretrained('bert-base-uncased')
        print("BERT model loaded successfully")
    except Exception as e:
        print(f"Error loading BERT model: {str(e)}")

# Start loading model in background thread
threading.Thread(target=load_bert_model).start()

# Add a caching decorator for Wikipedia data
@lru_cache(maxsize=100)
def get_cached_wikipedia_data(topic):
    return get_wikipedia_data(topic)

# Load environment variables
load_dotenv()

app = Flask(__name__)
bcrypt = Bcrypt(app)

# MongoDB Connection
mongo_uri = os.environ.get('MONGODB_URI')
client = MongoClient(mongo_uri)
db = client.get_database("visionary")
users_collection = db.users

def get_wikipedia_data(topic):
    wiki_wiki = wikipediaapi.Wikipedia(
        language='en',
        user_agent='YourAppName/1.0 (https://yourwebsite.com; your-email@example.com)'
    )
    
    # Search for pages related to the topic
    search_results = wikipedia.search(topic, results=10)  # Get up to 5 related pages
    data = []
    
    try:
        # Process each search result
        for page_title in search_results:
            try:
                # Get detailed page info using wikipediaapi
                page = wiki_wiki.page(page_title)
                if not page.exists():
                    continue
                
                # Get image using wikipedia library
                image_url = None
                try:
                    wikipedia_page = wikipedia.page(page_title, auto_suggest=False)
                    image_url = wikipedia_page.images[0] if wikipedia_page.images else None
                except Exception as img_error:
                    print(f"Error getting image for {page_title}: {str(img_error)}")
                
                # Get key sections
                sections = []
                for section in page.sections:
                    sections.append({"title": section.title, "content": section.text[:300]})  # Limit to 300 chars
                
                # Get related links
                related_topics = list(page.links.keys())[:5]  # Limit to 5 related topics
                
                # Fetching summary with Wikipedia library
                summary = wikipedia.summary(page_title, sentences=3, auto_suggest=False)
                
                # Format the response
                data.append({
                    "id": page.pageid,
                    "url": page.fullurl,
                    "title": page.title,
                    "summary": summary,
                    "image_url": image_url,
                    "sections": sections,
                    "fun_fact": summary.split(". ")[-1] if "." in summary else "",  # Last sentence as a fun fact
                    "related_topics": related_topics
                })
                
            except Exception as page_error:
                print(f"Error processing page {page_title}: {str(page_error)}")
                continue
        
        return data if data else None
        
    except Exception as e:
        print(f"An error occurred: {str(e)}")
        return None

@app.route('/wiki', methods=['GET'])
def wiki_data():
    topic = request.args.get('topic')
    if not topic:
        return jsonify({"error": "Please provide a topic parameter"}), 400
    
    data = get_wikipedia_data(topic)
    if not data:
        return jsonify({"error": "Topic not found"}), 404

    return jsonify(data)


#To get all the topics
WIKIPEDIA_API_URL = "https://en.wikipedia.org/w/api.php"

@app.route('/wiki/topics', methods=['GET'])
def get_random_topics():
    params = {
        "action": "query",
        "list": "random",
        "rnlimit": 10,  # Get 10 random topics
        "format": "json"
    }
    
    response = requests.get(WIKIPEDIA_API_URL, params=params)
    data = response.json()
    
    topics = [item["title"] for item in data["query"]["random"]]
    
    return jsonify({"topics": topics})

@app.route('/wiki/random', methods=['GET'])
def random_wiki_article():
    # Get a random topic from Wikipedia
    params = {
        "action": "query",
        "list": "random",
        "rnlimit": 1,
        "format": "json"
    }
    
    try:
        response = requests.get(WIKIPEDIA_API_URL, params=params)
        data = response.json()
        
        if "query" in data and "random" in data["query"] and len(data["query"]["random"]) > 0:
            random_topic = data["query"]["random"][0]["title"]
            
            # Get the data for this random topic
            wiki_data = get_wikipedia_data(random_topic)
            if wiki_data:
                return jsonify(wiki_data)
            else:
                # If the first random topic fails, try once more
                response = requests.get(WIKIPEDIA_API_URL, params=params)
                data = response.json()
                random_topic = data["query"]["random"][0]["title"]
                wiki_data = get_wikipedia_data(random_topic)
                
                if wiki_data:
                    return jsonify(wiki_data)
                else:
                    return jsonify({"error": "Could not retrieve random article"}), 404
        else:
            return jsonify({"error": "Failed to get random topic"}), 500
            
    except Exception as e:
        return jsonify({"error": f"An error occurred: {str(e)}"}), 500

@app.route('/signup', methods=['POST'])
def signup():
    data = request.json
    
    # Check if all required fields are present
    required_fields = ['fullName', 'email', 'phone', 'password']
    for field in required_fields:
        if field not in data or not data[field]:
            return jsonify({"error": f"Missing required field: {field}"}), 400
    
    # Validate email format
    email_regex = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    if not re.match(email_regex, data['email']):
        return jsonify({"error": "Invalid email format"}), 400
    
    # Check if email already exists
    if users_collection.find_one({"email": data['email']}):
        return jsonify({"error": "Email already registered"}), 409
    
    # Check if phone already exists
    if users_collection.find_one({"phone": data['phone']}):
        return jsonify({"error": "Phone number already registered"}), 409
    
    # Prepare user document with arrays to track interactions
    user = {
        "fullName": data['fullName'],
        "email": data['email'],
        "phone": data['phone'],
        "password": bcrypt.generate_password_hash(data['password']).decode('utf-8'),
        "bio": data.get('bio', ''),  # Optional field
        "interestedDomains": data.get('interestedDomains', []),  # Optional field
        "likedArticles": [],  # Array to store liked articles
        "commentedArticles": [],  # Array to store commented articles 
        "sharedArticles": []  # Array to store shared articles
    }
    
    # Insert user into database
    result = users_collection.insert_one(user)
    
    if result.inserted_id:
        # Remove password from response and create a response dict
        response_user = {
            "fullName": user["fullName"],
            "email": user["email"],
            "phone": user["phone"],
            "bio": user["bio"],
            "interestedDomains": user["interestedDomains"],
            "likedArticles": [],
            "commentedArticles": [],
            "sharedArticles": []
        }
        
        return jsonify({
            "message": "User registered successfully",
            "userId": str(result.inserted_id),
            "user": response_user
        }), 201
    else:
        return jsonify({"error": "Registration failed"}), 500
    

#Post the domain of interest
# Add this before the if __name__ == '__main__' line

@app.route('/user/domains', methods=['POST'])
def update_user_domains():
    data = request.json
    
    # Check required fields
    if not data or 'userId' not in data:
        return jsonify({"error": "User ID is required"}), 400
    
    if 'domains' not in data or not isinstance(data['domains'], list):
        return jsonify({"error": "Domains array is required"}), 400
    
    try:
        # Convert the string user ID to MongoDB ObjectId
        from bson.objectid import ObjectId
        user_id = ObjectId(data['userId'])
        
        # Find the user
        user = users_collection.find_one({"_id": user_id})
        if not user:
            return jsonify({"error": "User not found"}), 404
        
        # Update user's interested domains
        result = users_collection.update_one(
            {"_id": user_id},
            {"$set": {"interestedDomains": data['domains']}}
        )
        
        if result.modified_count > 0:
            # Get the updated user data
            updated_user = users_collection.find_one({"_id": user_id})
            
            # Create a response without password and with string ID
            response_user = {
                "userId": str(updated_user["_id"]),
                "fullName": updated_user["fullName"],
                "email": updated_user["email"],
                "interestedDomains": updated_user["interestedDomains"]
            }
            
            return jsonify({
                "message": "Domains updated successfully",
                "user": response_user
            }), 200
        else:
            return jsonify({"message": "No changes were made"}), 200
            
    except Exception as e:
        return jsonify({"error": f"An error occurred: {str(e)}"}), 500
    
#Login
# Add this after the signup route and before the user/domains route
@app.route('/login', methods=['POST'])
def login():
    data = request.json
    
    # Check if required fields are present
    if not data or 'email' not in data or 'password' not in data:
        return jsonify({"error": "Email and password are required"}), 400
    
    try:
        # Find the user by email
        user = users_collection.find_one({"email": data['email']})
        
        if not user:
            return jsonify({"error": "User not found"}), 404
        
        # Verify password
        if bcrypt.check_password_hash(user['password'], data['password']):
            # Create a response without password
            response_user = {
                "userId": str(user["_id"]),
                "fullName": user["fullName"],
                "email": user["email"],
                "phone": user["phone"],
                "bio": user.get("bio", ""),
                "interestedDomains": user.get("interestedDomains", []),
                "interactions": {
                    "likedArticles": user.get("likedArticles", []),
                    "commentedArticles": user.get("commentedArticles", []),
                    "sharedArticles": user.get("sharedArticles", [])
                }
            }
            
            return jsonify({
                "message": "Login successful",
                "user": response_user
            }), 200
        else:
            return jsonify({"error": "Invalid password"}), 401
            
    except Exception as e:
        return jsonify({"error": f"An error occurred: {str(e)}"}), 500
    




# Add this after the login route and before if __name__ == '__main__'

@app.route('/populate-domains', methods=['POST'])
def populate_domains():
    domains = [
        "Nature"
    ]
    
    results = {}
    
    try:
        for domain in domains:
            # Create collection for domain if it doesn't exist
            collection_name = domain.lower()
            domain_collection = db[collection_name]
            
            # Get Wikipedia data for the domain
            wiki_data = get_wikipedia_data(domain)
            
            if wiki_data:
                # Process and store each page
                for page_data in wiki_data:
                    # Calculate estimated reading time (avg reading speed: 200 words per minute)
                    summary_word_count = len(page_data["summary"].split())
                    sections_word_count = sum(len(section["content"].split()) for section in page_data["sections"])
                    total_words = summary_word_count + sections_word_count
                    reading_time = max(1, round(total_words / 200))  # in minutes, minimum 1 minute
                    
                    # Check if page already exists in collection
                    existing_page = domain_collection.find_one({"id": page_data["id"]})
                    
                    if not existing_page:
                        # Add additional fields to the page data
                        page_data["likes"] = 0
                        page_data["comments"] = []
                        page_data["reading_time"] = reading_time
                        page_data["created_at"] = datetime.now()
                        
                        # Insert into collection
                        domain_collection.insert_one(page_data)
                
                results[domain] = f"Added {len(wiki_data)} articles"
            else:
                results[domain] = "No data found"
        
        return jsonify({
            "message": "Domain data population completed",
            "results": results
        }), 200
        
    except Exception as e:
        return jsonify({"error": f"An error occurred: {str(e)}"}), 500

# Add routes to interact with domain collections
@app.route('/domains/<domain>/articles', methods=['GET'])
def get_domain_articles(domain):
    try:
        # Validate domain name
        valid_domains = [
            "nature", "education", "entertainment", "technology", 
            "science", "political", "lifestyle", "social", 
            "space", "food"
        ]
        
        domain = domain.lower()
        if domain not in valid_domains:
            return jsonify({"error": "Invalid domain"}), 400
            
        # Get articles from the domain collection
        domain_collection = db[domain]
        articles = list(domain_collection.find({}, {"_id": 0}))
        
        return jsonify(articles), 200
        
    except Exception as e:
        return jsonify({"error": f"An error occurred: {str(e)}"}), 500

@app.route('/domains/<domain>/articles/<article_id>/like/<user_id>', methods=['POST'])
def like_article(domain, article_id, user_id):
    try:
        domain = domain.lower()
        article_id = int(article_id)  # Convert to integer as Wikipedia page IDs are integers
        
        # Convert the string user ID to MongoDB ObjectId
        from bson.objectid import ObjectId
        user_id_obj = ObjectId(user_id)
        
        # Find the user
        user = users_collection.find_one({"_id": user_id_obj})
        if not user:
            return jsonify({"error": "User not found"}), 404
        
        # Get the domain collection
        domain_collection = db[domain]
        
        # Get article info
        article = domain_collection.find_one({"id": article_id})
        if not article:
            return jsonify({"error": "Article not found"}), 404
            
        article_title = article.get("title", "Unknown article")
        
        # Check if user already liked this article
        liked_article = next((item for item in user.get("likedArticles", []) 
                             if item.get("articleId") == article_id and item.get("domain") == domain), None)
        
        if liked_article:
            # User already liked this article, unlike it
            users_collection.update_one(
                {"_id": user_id_obj},
                {"$pull": {"likedArticles": {"articleId": article_id, "domain": domain}}}
            )
            
            # Decrease like count in article
            domain_collection.update_one(
                {"id": article_id},
                {"$inc": {"likes": -1}}
            )
            
            return jsonify({"message": "Article unliked successfully"}), 200
            
        else:
            # User is liking the article for the first time
            like_info = {
                "articleId": article_id,
                "domain": domain,
                "articleTitle": article_title,
                "likedAt": datetime.now()
            }
            
            # Add to user's liked articles
            users_collection.update_one(
                {"_id": user_id_obj},
                {"$push": {"likedArticles": like_info}}
            )
            
            # Update the article's like count
            domain_collection.update_one(
                {"id": article_id},
                {"$inc": {"likes": 1}}
            )
            
            return jsonify({"message": "Article liked successfully"}), 200
            
    except Exception as e:
        return jsonify({"error": f"An error occurred: {str(e)}"}), 500


        
# Add route to comment on an article
@app.route('/domains/<domain>/articles/<article_id>/comment', methods=['POST'])
def add_comment(domain, article_id):
    data = request.json
    
    if not data or 'comment' not in data or not data['comment']:
        return jsonify({"error": "Comment text is required"}), 400
        
    if 'userId' not in data:
        return jsonify({"error": "User ID is required"}), 400
        
    try:
        domain = domain.lower()
        article_id = int(article_id)
        
        # Convert the string user ID to MongoDB ObjectId
        from bson.objectid import ObjectId
        user_id = ObjectId(data['userId'])
        
        # Find the user
        user = users_collection.find_one({"_id": user_id})
        if not user:
            return jsonify({"error": "User not found"}), 404
            
        # Get domain collection
        domain_collection = db[domain]
        
        # Get article info
        article = domain_collection.find_one({"id": article_id})
        if not article:
            return jsonify({"error": "Article not found"}), 404
            
        article_title = article.get("title", "Unknown article")
        
        # Generate a unique comment ID
        from uuid import uuid4
        comment_id = str(uuid4())
        
        # Create comment object
        comment = {
            "id": comment_id,
            "user_id": str(user_id),
            "user_name": user['fullName'],
            "text": data['comment'],
            "timestamp": datetime.now()
        }
        
        # Add comment to article
        domain_collection.update_one(
            {"id": article_id},
            {"$push": {"comments": comment}}
        )
        
        # Add to user's commented articles
        comment_info = {
            "commentId": comment_id,
            "articleId": article_id,
            "domain": domain,
            "articleTitle": article_title,
            "commentText": data['comment'],
            "commentedAt": datetime.now()
        }
        
        users_collection.update_one(
            {"_id": user_id},
            {"$push": {"commentedArticles": comment_info}}
        )
        
        return jsonify({
            "message": "Comment added successfully",
            "comment": comment
        }), 200
            
    except Exception as e:
        return jsonify({"error": f"An error occurred: {str(e)}"}), 500
    

@app.route('/domains/<domain>/articles/<article_id>/comments', methods=['GET'])
def get_article_comments(domain, article_id):
    try:
        domain = domain.lower()
        article_id = int(article_id)
        
        # Get the domain collection
        domain_collection = db[domain]
        
        # Find the article
        article = domain_collection.find_one({"id": article_id})
        if not article:
            return jsonify({"error": "Article not found"}), 404
        
        # Get comments (if any)
        comments = article.get("comments", [])
        
        # Return the comments in chronological order (oldest first)
        # Convert any datetime objects to strings for JSON serialization
        for comment in comments:
            if 'timestamp' in comment and isinstance(comment['timestamp'], datetime):
                comment['timestamp'] = comment['timestamp'].strftime('%Y-%m-%d %H:%M:%S')
        
        return jsonify({
            "articleId": article_id,
            "articleTitle": article.get("title", ""),
            "domain": domain,
            "comments": comments,
            "commentCount": len(comments)
        }), 200
            
    except Exception as e:
        return jsonify({"error": f"An error occurred: {str(e)}"}), 500
    

@app.route('/domains/<domain>/articles/<article_id>/share', methods=['POST'])
def share_article(domain, article_id):
    data = request.json
    
    if not data or 'userId' not in data:
        return jsonify({"error": "User ID is required"}), 400
        
    try:
        domain = domain.lower()
        article_id = int(article_id)
        
        # Convert the string user ID to MongoDB ObjectId
        from bson.objectid import ObjectId
        user_id = ObjectId(data['userId'])
        
        # Find the user
        user = users_collection.find_one({"_id": user_id})
        if not user:
            return jsonify({"error": "User not found"}), 404
            
        # Get the domain collection
        domain_collection = db[domain]
        
        # Get article info
        article = domain_collection.find_one({"id": article_id})
        if not article:
            return jsonify({"error": "Article not found"}), 404
            
        article_title = article.get("title", "Unknown article")
        
        # Add to user's shared articles
        share_info = {
            "articleId": article_id,
            "domain": domain,
            "articleTitle": article_title,
            "sharedAt": datetime.now(),
            "sharedTo": data.get('sharedTo', 'public')  # Where the article was shared to
        }
        
        users_collection.update_one(
            {"_id": user_id},
            {"$push": {"sharedArticles": share_info}}
        )
        
        return jsonify({"message": "Article shared successfully"}), 200
            
    except Exception as e:
        return jsonify({"error": f"An error occurred: {str(e)}"}), 500
    

@app.route('/user/<user_id>/interactions', methods=['GET'])
def get_user_interactions(user_id):
    try:
        # Convert the string user ID to MongoDB ObjectId
        from bson.objectid import ObjectId
        user_id_obj = ObjectId(user_id)
        
        # Find the user
        user = users_collection.find_one({"_id": user_id_obj})
        if not user:
            return jsonify({"error": "User not found"}), 404
        
        # Create a response without password and with string ID
        interactions = {
            "likedArticles": user.get("likedArticles", []),
            "commentedArticles": user.get("commentedArticles", []),
            "sharedArticles": user.get("sharedArticles", [])
        }
        
        return jsonify(interactions), 200
            
    except Exception as e:
        return jsonify({"error": f"An error occurred: {str(e)}"}), 500

@app.route('/domains/<domain>/articles/<article_id>', methods=['GET'])
def get_article_by_id(domain, article_id):
    try:
        domain = domain.lower()
        article_id = int(article_id)  # Convert to integer as Wikipedia page IDs are integers
        
        # Get the domain collection
        domain_collection = db[domain]
        
        # Find the article
        article = domain_collection.find_one({"id": article_id})
        if not article:
            return jsonify({"error": "Article not found"}), 404
        
        # Convert MongoDB _id to string for serialization
        if "_id" in article:
            article["_id"] = str(article["_id"])
            
        # Return the full article data
        return jsonify({
            "article": article,
            "domain": domain
        }), 200
            
    except Exception as e:
        return jsonify({"error": f"An error occurred: {str(e)}"}), 500

    
@app.route('/user/<user_id>/bert-recommendations-test', methods=['GET'])
def get_bert_recommendations_test(user_id):
    try:
        # Convert the string user ID to MongoDB ObjectId
        from bson.objectid import ObjectId
        from transformers import BertTokenizer, BertForSequenceClassification
        import torch
        import numpy as np
        
        user_id_obj = ObjectId(user_id)
        
        # Find the user
        user = users_collection.find_one({"_id": user_id_obj})
        if not user:
            return jsonify({"error": "User not found"}), 404
        
        # Get user's interested domains and interactions
        interested_domains = user.get("interestedDomains", [])
        liked_articles = user.get("likedArticles", [])
        commented_articles = user.get("commentedArticles", [])
        shared_articles = user.get("sharedArticles", [])
        
        if not interested_domains:
            return jsonify({"error": "User has no interested domains selected"}), 404
            
        # Convert domain names to lowercase for collection names
        domain_collections = [domain.lower() for domain in interested_domains]
        
        # Create a set of all interacted article IDs to avoid recommending them
        interacted_articles = set()
        for item in liked_articles + commented_articles + shared_articles:
            if 'articleId' in item and 'domain' in item:
                interacted_articles.add((item['articleId'], item['domain']))
        
        # Define the mapping of domains to subdomains
        domain_to_subdomains = {
            "nature": ["Ecology", "Wildlife Conservation", "Botany", "Marine Biology", "Climatology", 
                      "Geology", "Environmental Science", "Biodiversity", "Natural Disasters", "Forestry"],
            "education": ["Early Childhood Education", "Higher Education", "Online Learning", "STEM Education", 
                         "Special Education", "Educational Psychology", "Teaching Methods", "Language Learning", 
                         "EdTech", "Curriculum Development"],
            "entertainment": ["Movies", "Music", "Television Shows", "Video Games", "Theatre & Performing Arts", 
                             "Anime & Manga", "Stand-up Comedy", "Celebrity News", "Book & Literature", "Streaming Platforms"],
            "technology": ["Artificial Intelligence", "Cybersecurity", "Software Development", "Hardware & Gadgets", 
                          "Blockchain & Cryptocurrency", "Quantum Computing", "Internet of Things", "Cloud Computing", 
                          "Networking & Telecommunications", "Data Science & Big Data"],
            "science": ["Physics", "Chemistry", "Biology", "Astronomy", "Genetics", "Neuroscience", "Nanotechnology", 
                       "Meteorology", "Biochemistry", "Space Exploration"],
            "political": ["International Relations", "Government Systems", "Political Theories", "Elections & Voting", 
                         "Public Policy", "Human Rights", "Law & Judiciary", "Political Movements", "Diplomacy & Treaties", "Geopolitics"],
            "lifestyle": ["Travel & Tourism", "Fashion & Style", "Health & Wellness", "Personal Finance", "Minimalism", 
                         "Parenting & Family", "Home & Interior Design", "Work-Life Balance", "Self-Improvement", "Hobbies & Leisure"],
            "social": ["Sociology", "Psychology", "Social Media Trends", "Cultural Studies", "Human Behavior", 
                      "Community Development", "Ethics & Morality", "Gender Studies", "Social Justice", "Philanthropy"],
            "space": ["Solar System", "Exoplanets", "Black Holes", "Space Missions", "Space Technology", "Astrobiology", 
                     "Space Colonization", "Theories of the Universe", "Cosmology", "Dark Matter & Energy"],
            "food": ["Culinary Arts", "Nutrition & Diet", "Food Science", "Street Food", "Beverages & Brewing", 
                    "Vegan & Vegetarian Diets", "World Cuisines", "Baking & Pastry", "Food History", "Restaurant Industry"]
        }

        # Get subdomain recommendations if user has liked articles
        bert_recommended_articles = []
        
        if liked_articles:
            try:
                # Load BERT model and tokenizer for classification
                tokenizer = BertTokenizer.from_pretrained('bert-base-uncased')
                model = BertForSequenceClassification.from_pretrained('bert-base-uncased')
                
                # Extract summaries from liked articles
                summaries = []
                article_domains = []
                
                for liked in liked_articles[:10]:  # Use up to 10 most recent liked articles
                    domain = liked.get('domain')
                    if not domain:
                        continue
                        
                    article_id = liked.get('articleId')
                    if not article_id:
                        continue
                        
                    # Find the article in its domain collection
                    article = db[domain].find_one({"id": article_id})
                    if article and 'summary' in article:
                        summaries.append(article['summary'])
                        article_domains.append(domain)
                
                # Identify most relevant subdomains using BERT
                subdomain_scores = {}
                
                for i, summary in enumerate(summaries):
                    domain = article_domains[i]
                    subdomains = domain_to_subdomains.get(domain, [])
                    
                    if not subdomains:
                        continue
                    
                    # Use BERT to classify text into subdomains
                    # This is a simplified approach - in production, you'd use a fine-tuned model
                    inputs = tokenizer(summary, return_tensors="pt", truncation=True, padding=True)
                    with torch.no_grad():
                        outputs = model(**inputs)
                    
                    # Simulate subdomain classification with random scores for this example
                    # In production, replace with actual classification logic
                    subdomain_probs = np.random.random(len(subdomains))
                    subdomain_probs = subdomain_probs / subdomain_probs.sum()  # Normalize to sum to 1
                    
                    for j, subdomain in enumerate(subdomains):
                        if subdomain not in subdomain_scores:
                            subdomain_scores[subdomain] = 0
                        subdomain_scores[subdomain] += subdomain_probs[j]
                
                # Get top 3 subdomains
                top_subdomains = sorted(subdomain_scores.items(), key=lambda x: x[1], reverse=True)[:3]
                
                # Fetch articles from Wikipedia API for each top subdomain
                articles_per_subdomain = 10 // len(top_subdomains) if top_subdomains else 0
                
                for subdomain, score in top_subdomains:
                    # Get articles from Wikipedia using get_wikipedia_data
                    subdomain_wiki_data = get_wikipedia_data(subdomain)
                    
                    if subdomain_wiki_data:
                        # Take only what we need from each article and add subdomain info
                        for article in subdomain_wiki_data[:articles_per_subdomain]:
                            article["subdomain"] = subdomain
                            article["subdomain_score"] = float(score)
                            # Find which main domain this subdomain belongs to
                            for domain, subdomains in domain_to_subdomains.items():
                                if subdomain in subdomains:
                                    article["domain"] = domain
                                    break
                            
                            bert_recommended_articles.append(article)
                
            except Exception as bert_error:
                print(f"Error in BERT recommendation: {str(bert_error)}")
        
        # If BERT recommendations didn't yield enough articles, get more from other domains
        if len(bert_recommended_articles) < 10:
            remaining_bert = 10 - len(bert_recommended_articles)
            # Get random articles from user's interested domains
            for domain in domain_collections[:3]:  # Just use first 3 domains to keep it simple
                if len(bert_recommended_articles) >= 10:
                    break
                    
                if domain in db.list_collection_names():
                    # Get article IDs to exclude
                    exclude_ids = [article_id for article_id, article_domain in interacted_articles if article_domain == domain]
                    already_recommended_ids = [a.get("id") for a in bert_recommended_articles if a.get("domain") == domain]
                    exclude_ids.extend(already_recommended_ids)
                    
                    random_articles = list(db[domain].aggregate([
                        {"$match": {"id": {"$nin": exclude_ids}}},
                        {"$sample": {"size": remaining_bert // 3 + 1}},
                        {"$project": {"_id": 0}}
                    ]))
                    
                    for article in random_articles:
                        article["domain"] = domain
                        article["recommendation_source"] = "fallback"
                    
                    bert_recommended_articles.extend(random_articles)
                    if len(bert_recommended_articles) >= 10:
                        bert_recommended_articles = bert_recommended_articles[:10]
                        break
        
        # Remove duplicates by ID
        seen_ids = set()
        unique_bert_articles = []
        
        for article in bert_recommended_articles:
            if article["id"] not in seen_ids:
                seen_ids.add(article["id"])
                unique_bert_articles.append(article)
        
        return jsonify({
            "bertRecommendedArticles": unique_bert_articles[:10],  # Limit to 10 articles
            "count": len(unique_bert_articles[:10]),
            "method": "BERT-based subdomain classification"
        }), 200
            
    except Exception as e:
        return jsonify({"error": f"An error occurred: {str(e)}"}), 500
    


@app.route('/user/<user_id>/bert-recommendations', methods=['GET'])
def get_bert_recommendations(user_id):
    # Check cache first
    cache_key = f"bert_rec_{user_id}"
    cached_result = cache.get(cache_key)
    if cached_result:
        return jsonify(cached_result), 200
    
    try:
        # Set a timeout for the entire function
        start_time = time.time()
        max_execution_time = 25  # seconds
        
        # Convert the string user ID to MongoDB ObjectId
        from bson.objectid import ObjectId
        import numpy as np
        
        user_id_obj = ObjectId(user_id)
        
        # Find the user
        user = users_collection.find_one({"_id": user_id_obj})
        if not user:
            return jsonify({"error": "User not found"}), 404
        
        # Get user's interested domains and interactions
        interested_domains = user.get("interestedDomains", [])
        liked_articles = user.get("likedArticles", [])
        
        if not interested_domains:
            return jsonify({"error": "User has no interested domains selected"}), 404
            
        # Convert domain names to lowercase for collection names
        domain_collections = [domain.lower() for domain in interested_domains]
        
        # Create a set of all interacted articles to avoid recommending them
        interacted_articles = set()
        for item in liked_articles + user.get("commentedArticles", []) + user.get("sharedArticles", []):
            if 'articleId' in item and 'domain' in item:
                interacted_articles.add((item['articleId'], item['domain']))
        
        # Define the mapping of domains to subdomains (kept same as original)
        domain_to_subdomains = {
            "nature": ["Ecology", "Wildlife Conservation", "Botany"],
            "education": ["Early Childhood Education", "Higher Education", "Online Learning"],
            "entertainment": ["Movies", "Music", "Television Shows"],
            "technology": ["Artificial Intelligence", "Cybersecurity", "Software Development"],
            "science": ["Physics", "Chemistry", "Biology"],
            "political": ["International Relations", "Government Systems", "Political Theories"],
            "lifestyle": ["Travel & Tourism", "Fashion & Style", "Health & Wellness"],
            "social": ["Sociology", "Psychology", "Social Media Trends"],
            "space": ["Solar System", "Exoplanets", "Black Holes"],
            "food": ["Culinary Arts", "Nutrition & Diet", "Food Science"],
        }

        bert_recommended_articles = []
        
        # For each interested domain, get some articles to recommend
        for domain in domain_collections[:3]:  # Limit to top 3 domains
            if time.time() - start_time > max_execution_time:
                # We're running out of time, break early
                break
                
            # Get 3-4 articles from each domain
            if domain in db.list_collection_names():
                # Get article IDs to exclude
                exclude_ids = [article_id for article_id, article_domain in interacted_articles if article_domain == domain]
                
                # Get random articles from this domain
                random_articles = list(db[domain].aggregate([
                    {"$match": {"id": {"$nin": exclude_ids}}},
                    {"$sample": {"size": 4}},
                    {"$project": {"_id": 0}}
                ]))
                
                for article in random_articles:
                    article["domain"] = domain
                    article["recommendation_source"] = "domain_based"
                
                bert_recommended_articles.extend(random_articles)
        
        # If user has liked articles, try to get some subdomain recommendations
        if liked_articles and global_tokenizer and global_model and len(bert_recommended_articles) < 10:
            try:
                # Use only a few liked articles to keep it fast
                recent_liked = liked_articles[:3]
                
                # Mock subdomain classification for speed
                subdomains_to_try = []
                for liked in recent_liked:
                    domain = liked.get('domain')
                    if domain in domain_to_subdomains:
                        # Pick a random subdomain
                        import random
                        subdomain = random.choice(domain_to_subdomains[domain])
                        if subdomain not in subdomains_to_try:
                            subdomains_to_try.append(subdomain)
                
                # Get 1-2 articles for each subdomain
                for subdomain in subdomains_to_try[:2]:
                    if time.time() - start_time > max_execution_time:
                        # We're running out of time, break early
                        break
                        
                    # Use cached version to speed up
                    subdomain_wiki_data = get_cached_wikipedia_data(subdomain)
                    
                    if subdomain_wiki_data:
                        # Add a couple articles from this subdomain
                        for article in subdomain_wiki_data[:2]:
                            article["subdomain"] = subdomain
                            article["subdomain_score"] = 0.8  # Fixed score for speed
                            
                            # Find which main domain this subdomain belongs to
                            for domain, subdomains in domain_to_subdomains.items():
                                if subdomain in subdomains:
                                    article["domain"] = domain
                                    break
                            
                            bert_recommended_articles.append(article)
            except Exception as bert_error:
                print(f"Error in BERT recommendation: {str(bert_error)}")
        
        # Remove duplicates by ID
        seen_ids = set()
        unique_bert_articles = []
        
        for article in bert_recommended_articles:
            if article["id"] not in seen_ids:
                seen_ids.add(article["id"])
                unique_bert_articles.append(article)
        
        # Prepare response
        response_data = {
            "bertRecommendedArticles": unique_bert_articles[:10],
            "count": len(unique_bert_articles[:10]),
            "method": "BERT-based subdomain classification"
        }
        
        # Cache the result for 1 hour (3600 seconds)
        cache.set(cache_key, response_data, timeout=3600)
        
        return jsonify(response_data), 200
            
    except Exception as e:
        return jsonify({"error": f"An error occurred: {str(e)}"}), 500

@app.route('/user/<user_id>/standard-recommendations', methods=['GET'])
def get_standard_recommendations(user_id):
    try:
        # Convert the string user ID to MongoDB ObjectId
        from bson.objectid import ObjectId
        
        user_id_obj = ObjectId(user_id)
        
        # Find the user
        user = users_collection.find_one({"_id": user_id_obj})
        if not user:
            return jsonify({"error": "User not found"}), 404
        
        # Get user's interested domains and interactions
        interested_domains = user.get("interestedDomains", [])
        liked_articles = user.get("likedArticles", [])
        commented_articles = user.get("commentedArticles", [])
        shared_articles = user.get("sharedArticles", [])
        
        if not interested_domains:
            return jsonify({"error": "User has no interested domains selected"}), 404
            
        # Convert domain names to lowercase for collection names
        domain_collections = [domain.lower() for domain in interested_domains]
        
        # Create a set of all interacted article IDs to avoid recommending them
        interacted_articles = set()
        for item in liked_articles + commented_articles + shared_articles:
            if 'articleId' in item and 'domain' in item:
                interacted_articles.add((item['articleId'], item['domain']))
        
        recommended_articles = []
        
        # Get 30 articles based on user scores and 10 random articles
        articles_to_fetch_by_score = 30
        articles_to_fetch_random = 10
        
        # Check if we have enough liked articles to use the advanced algorithm
        if len(liked_articles) >= 5:
            # Calculate domain scores based on interactions
            domain_scores = {domain.lower(): 0 for domain in ["nature", "education", "entertainment", "technology", 
                            "science", "political", "lifestyle", "social", "space", "food"]}
            
            # Calculate scores by domain
            for article in liked_articles:
                if 'domain' in article:
                    domain = article['domain'].lower()
                    if domain in domain_scores:
                        domain_scores[domain] += 0.5
            
            for article in shared_articles:
                if 'domain' in article:
                    domain = article['domain'].lower()
                    if domain in domain_scores:
                        domain_scores[domain] += 0.1
            
            for article in commented_articles:
                if 'domain' in article:
                    domain = article['domain'].lower()
                    if domain in domain_scores:
                        domain_scores[domain] += 0.2
            
            # Calculate percentiles
            total_score = sum(domain_scores.values())
            domain_percentiles = {}
            
            if total_score > 0:
                for domain, score in domain_scores.items():
                    domain_percentiles[domain] = (score / total_score) * 100
            else:
                # If no interactions, equal distribution
                for domain in domain_scores:
                    domain_percentiles[domain] = 10  # 10% each for 10 domains
            
            # Select 30 articles based on domain percentiles
            high_percentile_domains = [d for d, p in domain_percentiles.items() if p > 50]
            
            # Distribute articles according to percentiles
            domain_article_counts = {}
            remaining = articles_to_fetch_by_score
            
            for domain, percentile in domain_percentiles.items():
                # Skip domains with no collections
                if domain not in db.list_collection_names():
                    continue
                    
                # Calculate articles to fetch for this domain
                domain_count = int(round(articles_to_fetch_by_score * (percentile / 100)))
                domain_article_counts[domain] = min(domain_count, remaining)
                remaining -= domain_article_counts[domain]
            
            # If we didn't allocate all 30 articles, distribute the remainder
            if remaining > 0:
                valid_domains = [d for d in domain_scores.keys() if d in db.list_collection_names()]
                if valid_domains:
                    per_domain = remaining // len(valid_domains)
                    for domain in valid_domains:
                        domain_article_counts[domain] = domain_article_counts.get(domain, 0) + per_domain
                        remaining -= per_domain
                    
                    # Add any remaining to the first domain
                    if remaining > 0 and valid_domains:
                        domain_article_counts[valid_domains[0]] = domain_article_counts.get(valid_domains[0], 0) + remaining
            
            # Fetch the calculated number of articles from each domain
            for domain, count in domain_article_counts.items():
                if count <= 0:
                    continue
                    
                # Get article IDs to exclude
                exclude_ids = [article_id for article_id, article_domain in interacted_articles if article_domain == domain]
                
                # Get random articles from this domain
                domain_articles = list(db[domain].aggregate([
                    {"$match": {"id": {"$nin": exclude_ids}}},
                    {"$sample": {"size": count}},
                    {"$project": {"_id": 0}}
                ]))
                
                # Add domain name and score info to each article
                for article in domain_articles:
                    article["domain"] = domain
                    article["domain_score"] = float(domain_percentiles[domain])
                    article["recommendation_source"] = "score_based"
                
                recommended_articles.extend(domain_articles)
            
            # Get 10 random articles from domains with percentile <= 50
            remaining_random = articles_to_fetch_random
            if recommended_articles:
                low_percentile_domains = [d for d in domain_scores.keys() 
                                         if d not in high_percentile_domains
                                         and d in db.list_collection_names()]
                
                if low_percentile_domains:
                    articles_per_domain = max(1, remaining_random // len(low_percentile_domains))
                    
                    for domain in low_percentile_domains:
                        # Get article IDs to exclude
                        exclude_ids = [article_id for article_id, article_domain in interacted_articles if article_domain == domain]
                        already_recommended_ids = [a["id"] for a in recommended_articles if a.get("domain") == domain]
                        exclude_ids.extend(already_recommended_ids)
                        
                        additional_articles = list(db[domain].aggregate([
                            {"$match": {"id": {"$nin": exclude_ids}}},
                            {"$sample": {"size": articles_per_domain}},
                            {"$project": {"_id": 0}}
                        ]))
                        
                        # Add domain name and source info to each article
                        for article in additional_articles:
                            article["domain"] = domain
                            article["domain_score"] = float(domain_percentiles[domain])
                            article["recommendation_source"] = "random"
                            
                        recommended_articles.extend(additional_articles)
                        remaining_random -= len(additional_articles)
                        
                        if remaining_random <= 0:
                            break
            
        else:
            # Simple recommendation for users with fewer than 5 liked articles
            # Get random articles from each interested domain
            articles_per_domain = max(1, 40 // len(domain_collections))  # 40 articles total
            
            for domain in domain_collections:
                # Make sure the domain collection exists
                if domain in db.list_collection_names():
                    # Get article IDs to exclude
                    exclude_ids = [article_id for article_id, article_domain in interacted_articles if article_domain == domain]
                    
                    # Get random articles from this domain
                    domain_articles = list(db[domain].aggregate([
                        {"$match": {"id": {"$nin": exclude_ids}}},
                        {"$sample": {"size": articles_per_domain}},
                        {"$project": {"_id": 0}}
                    ]))
                    
                    # Add domain name and source info to each article
                    for article in domain_articles:
                        article["domain"] = domain
                        article["recommendation_source"] = "new_user"
                    
                    recommended_articles.extend(domain_articles)
        
        # If we still don't have 40 articles, grab more from random domains
        if len(recommended_articles) < 40:
            remaining_from_collections = 40 - len(recommended_articles)
            all_domains = ["nature", "education", "entertainment", "technology", 
                          "science", "political", "lifestyle", "social", 
                          "space", "food"]
            
            # Filter to domains with collections and that aren't already well-represented
            valid_domains = [d.lower() for d in all_domains 
                           if d.lower() in db.list_collection_names() 
                           and d.lower() not in (high_percentile_domains if 'high_percentile_domains' in locals() else [])]
            
            if valid_domains:
                articles_per_domain = max(1, remaining_from_collections // len(valid_domains))
                
                for domain in valid_domains:
                    # Get article IDs to exclude
                    exclude_ids = [article_id for article_id, article_domain in interacted_articles if article_domain == domain]
                    already_recommended_ids = [a["id"] for a in recommended_articles if a.get("domain") == domain]
                    exclude_ids.extend(already_recommended_ids)
                    
                    extra_articles = list(db[domain].aggregate([
                        {"$match": {"id": {"$nin": exclude_ids}}},
                        {"$sample": {"size": articles_per_domain}},
                        {"$project": {"_id": 0}}
                    ]))
                    
                    # Add domain name and source info to each article
                    for article in extra_articles:
                        article["domain"] = domain
                        article["recommendation_source"] = "fallback"
                        
                    recommended_articles.extend(extra_articles)
                    remaining_from_collections -= len(extra_articles)
                    
                    if remaining_from_collections <= 0:
                        break
        
        # Remove duplicates by ID
        seen_ids = set()
        unique_articles = []
        
        for article in recommended_articles:
            if article["id"] not in seen_ids:
                seen_ids.add(article["id"])
                unique_articles.append(article)
        
        return jsonify({
            "standardRecommendedArticles": unique_articles[:40],  # Limit to 40 articles
            "count": len(unique_articles[:40]),
            "method": "Interest and interaction based recommendations"
        }), 200
            
    except Exception as e:
        return jsonify({"error": f"An error occurred: {str(e)}"}), 500
    

@app.route('/articles/trending', methods=['GET'])
def get_trending_articles():
    try:
        # Set a limit for the number of trending articles to return
        limit = int(request.args.get('limit', 10))
        
        # Initialize array to store all articles
        all_articles = []
        
        # Get valid domain collections
        valid_domains = ["nature", "education", "entertainment", "technology", 
                        "science", "political", "lifestyle", "social", 
                        "space", "food"]
        
        # Process each domain
        for domain in valid_domains:
            if domain in db.list_collection_names():
                # Find articles in this domain, sorted by popularity metrics
                domain_articles = list(db[domain].find(
                    {}, 
                    {
                        "_id": 0,
                        "id": 1, 
                        "title": 1, 
                        "domain": domain,
                        "likes": 1,
                        "comments": 1
                    }
                ))
                
                # Add domain to each article and calculate engagement score
                for article in domain_articles:
                    article["domain"] = domain
                    
                    # Count number of comments
                    article["comment_count"] = len(article.get("comments", []))
                    
                    # Calculate engagement score (likes + comments*2)
                    # Comments weighted more as they show higher engagement
                    article["engagement_score"] = (
                        article.get("likes", 0) + 
                        article["comment_count"] * 2
                    )
                
                all_articles.extend(domain_articles)
        
        # Sort by engagement score (descending)
        trending_articles = sorted(
            all_articles, 
            key=lambda x: x.get("engagement_score", 0),
            reverse=True
        )[:limit]
        
        # Format the response
        formatted_articles = []
        for article in trending_articles:
            formatted_articles.append({
                "id": article["id"],
                "title": article["title"],
                "domain": article["domain"],
                "likes": article.get("likes", 0),
                "comment_count": article["comment_count"],
                "engagement_score": article["engagement_score"]
            })
        
        return jsonify({
            "trending_articles": formatted_articles,
            "count": len(formatted_articles)
        }), 200
        
    except Exception as e:
        return jsonify({"error": f"An error occurred: {str(e)}"}), 500



def get_search_results(query, limit=5):
    """
    A specialized function to get search results from Wikipedia.
    Returns a limited number of articles matched to the search query.
    """
    wiki_wiki = wikipediaapi.Wikipedia(
        language='en',
        user_agent='YourAppName/1.0 (https://yourwebsite.com; your-email@example.com)'
    )
    
    # Search for pages related to the query
    search_results = wikipedia.search(query, results=max(10, limit*2))  # Get more results than needed for fallback
    data = []
    
    try:
        # Process each search result
        for page_title in search_results:
            if len(data) >= limit:
                break
                
            try:
                # Get detailed page info using wikipediaapi
                page = wiki_wiki.page(page_title)
                if not page.exists():
                    continue
                
                # Get image using wikipedia library
                image_url = None
                try:
                    wikipedia_page = wikipedia.page(page_title, auto_suggest=False)
                    image_url = wikipedia_page.images[0] if wikipedia_page.images else None
                except Exception as img_error:
                    print(f"Error getting image for {page_title}: {str(img_error)}")
                
                # Fetching summary with Wikipedia library
                summary = wikipedia.summary(page_title, sentences=3, auto_suggest=False)
                
                # Format the response
                data.append({
                    "id": page.pageid,
                    "url": page.fullurl,
                    "title": page.title,
                    "summary": summary,
                    "image_url": image_url,
                    "search_query": query,  # Add the search query for context
                    "relevance_score": 1.0 - (search_results.index(page_title) / len(search_results))  # Simple relevance scoring
                })
                
            except Exception as page_error:
                print(f"Error processing search result {page_title}: {str(page_error)}")
                continue
        
        return data if data else None
        
    except Exception as e:
        print(f"An error occurred during search: {str(e)}")
        return None

@app.route('/search', methods=['GET'])
def search_articles():
    query = request.args.get('query')
    if not query or len(query.strip()) < 2:
        return jsonify({"error": "Please provide a valid search query (minimum 2 characters)"}), 400
    
    # Set limit with default of 5
    try:
        limit = int(request.args.get('limit', 5))
        if limit < 1 or limit > 20:  # Enforce reasonable limits
            limit = 5
    except ValueError:
        limit = 5
        
    # Get search results
    results = get_search_results(query, limit)
    
    if not results:
        return jsonify({
            "query": query,
            "results": [],
            "count": 0,
            "message": "No results found for your search query."
        }), 200  # Return 200 even with no results, as the search was valid
    
    return jsonify({
        "query": query,
        "results": results,
        "count": len(results)
    }), 200

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=True)
