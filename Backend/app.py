from flask import Flask, jsonify, request
import wikipediaapi
import wikipedia
import requests
import os
from flask_bcrypt import Bcrypt
from pymongo import MongoClient
import re
from dotenv import load_dotenv

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
    search_results = wikipedia.search(topic, results=5)  # Get up to 5 related pages
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
    
    # Prepare user document
    user = {
        "fullName": data['fullName'],
        "email": data['email'],
        "phone": data['phone'],
        "password": bcrypt.generate_password_hash(data['password']).decode('utf-8'),
        "bio": data.get('bio', ''),  # Optional field
        "interestedDomains": data.get('interestedDomains', [])  # Optional field
    }
    
    # Insert user into database
    result = users_collection.insert_one(user)
    
    if result.inserted_id:
        # Remove password from response and create a response dict
        # This avoids the ObjectId serialization issue
        response_user = {
            "fullName": user["fullName"],
            "email": user["email"],
            "phone": user["phone"],
            "bio": user["bio"],
            "interestedDomains": user["interestedDomains"]
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
                "interestedDomains": user.get("interestedDomains", [])
            }
            
            return jsonify({
                "message": "Login successful",
                "user": response_user
            }), 200
        else:
            return jsonify({"error": "Invalid password"}), 401
            
    except Exception as e:
        return jsonify({"error": f"An error occurred: {str(e)}"}), 500
    


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=True)
