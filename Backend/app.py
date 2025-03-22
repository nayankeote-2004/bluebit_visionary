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
    search_results = wikipedia.search(topic, results=100)  # Get up to 5 related pages
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
        "Nature", "Education", "Entertainment", "Technology", 
        "Science", "Political", "Lifestyle", "Social", 
        "Space", "Food"
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
    

# ...existing code...
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
    
@app.route('/user/<user_id>/recommended-articles', methods=['GET'])
def get_recommended_articles(user_id):
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
            
            # Select 40 articles based on domain percentiles
            articles_to_fetch = 40
            high_percentile_domains = [d for d, p in domain_percentiles.items() if p > 50]
            
            # Distribute articles according to percentiles
            domain_article_counts = {}
            remaining = articles_to_fetch
            
            for domain, percentile in domain_percentiles.items():
                # Skip domains with no collections
                if domain not in db.list_collection_names():
                    continue
                    
                # Calculate articles to fetch for this domain
                domain_count = int(round(articles_to_fetch * (percentile / 100)))
                domain_article_counts[domain] = min(domain_count, remaining)
                remaining -= domain_article_counts[domain]
            
            # If we didn't allocate all 40 articles, distribute the remainder
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
                
                # Add domain name to each article
                for article in domain_articles:
                    article["domain"] = domain
                
                recommended_articles.extend(domain_articles)
            
            # Select 10 more articles from domains with percentile <= 50
            remaining = 10
            if recommended_articles:
                low_percentile_domains = [d for d in domain_scores.keys() 
                                         if d not in high_percentile_domains
                                         and d in db.list_collection_names()]
                
                if low_percentile_domains:
                    articles_per_domain = max(1, remaining // len(low_percentile_domains))
                    
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
                        
                        # Add domain name to each article
                        for article in additional_articles:
                            article["domain"] = domain
                            
                        recommended_articles.extend(additional_articles)
                        remaining -= len(additional_articles)
                        
                        if remaining <= 0:
                            break
            
        else:
            # Simple recommendation for users with fewer than 5 liked articles
            # Get random articles from each interested domain
            articles_per_domain = max(1, 50 // len(domain_collections))
            
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
                    
                    # Add domain name to each article
                    for article in domain_articles:
                        article["domain"] = domain
                    
                    recommended_articles.extend(domain_articles)
        
        # If we have fewer than 50 articles, grab more from random domains
        if len(recommended_articles) < 50:
            remaining = 50 - len(recommended_articles)
            all_domains = ["nature", "education", "entertainment", "technology", 
                          "science", "political", "lifestyle", "social", 
                          "space", "food"]
            
            # Filter to domains with collections and that aren't high percentile
            valid_domains = [d.lower() for d in all_domains 
                           if d.lower() in db.list_collection_names() 
                           and d.lower() not in high_percentile_domains] if 'high_percentile_domains' in locals() else [d.lower() for d in all_domains if d.lower() in db.list_collection_names()]
            
            if valid_domains:
                articles_per_domain = max(1, remaining // len(valid_domains))
                
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
                    
                    # Add domain name to each article
                    for article in extra_articles:
                        article["domain"] = domain
                        
                    recommended_articles.extend(extra_articles)
                    remaining -= len(extra_articles)
                    
                    if remaining <= 0:
                        break
        
        # Ensure no duplicates in the final recommendation list
        seen_ids = set()
        unique_articles = []
        
        for article in recommended_articles:
            if article["id"] not in seen_ids:
                seen_ids.add(article["id"])
                unique_articles.append(article)
        
        return jsonify({
            "recommendedArticles": unique_articles[:50],  # Limit to 50 articles
            "count": len(unique_articles[:50])
        }), 200
            
    except Exception as e:
        return jsonify({"error": f"An error occurred: {str(e)}"}), 500
    


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=True)