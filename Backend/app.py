from flask import Flask, jsonify, request
import wikipediaapi
import wikipedia
import requests
import os

app = Flask(__name__)

def get_wikipedia_data(topic):
    wiki_wiki = wikipediaapi.Wikipedia(
        language='en',
        user_agent='YourAppName/1.0 (https://yourwebsite.com; your-email@example.com)'
    )
    page = wiki_wiki.page(topic)

    if not page.exists():
        return None

    # Get image using the wikipedia library instead
    image_url = None
    try:
        # Try to get images from wikipedia package
        wikipedia_page = wikipedia.page(topic)
        if wikipedia_page.images:
            image_url = wikipedia_page.images[0] if wikipedia_page.images else None
    except:
        # If there's any error, proceed without the image
        pass

    # Get key sections
    sections = []
    for section in page.sections:
        sections.append({"title": section.title, "content": section.text[:300]})  # Limit to 300 chars

    # Get related links
    related_topics = list(page.links.keys())[:5]  # Limit to 5 related topics

    # Fetching summary with Wikipedia library
    summary = wikipedia.summary(topic, sentences=3)

    # Format the response
    data = {
        "title": page.title,
        "summary": summary,
        "image_url": image_url,
        "sections": sections,
        "fun_fact": summary.split(". ")[-1] if "." in summary else "",  # Last sentence as a fun fact
        "related_topics": related_topics
    }
    return data

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

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=True)
