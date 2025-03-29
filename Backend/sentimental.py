from flask import Blueprint, Flask, jsonify, request
from pymongo import MongoClient
import os
from dotenv import load_dotenv
from datetime import datetime
from bson.objectid import ObjectId
import pickle
import re
from cachelib import SimpleCache

# Create a Blueprint instead of a Flask app
sentiment_blueprint = Blueprint('sentiment', __name__)
cache = SimpleCache()

# MongoDB Connection is handled in app.py, we'll use the same connection

# Load custom sentiment analysis model and vectorizer
try:
    with open('sentiment_model.pkl', 'rb') as f:
        sentiment_model = pickle.load(f)
    with open('vectorizer.pkl', 'rb') as f:
        vectorizer = pickle.load(f)
    print("Custom sentiment model loaded successfully")
except Exception as e:
    print(f"Error loading custom sentiment model: {str(e)}")
    # Fallback to NLTK if custom model fails to load
    import nltk
    from nltk.sentiment.vader import SentimentIntensityAnalyzer
    try:
        nltk.download('vader_lexicon', quiet=True)
        sentiment_analyzer = SentimentIntensityAnalyzer()
        print("Fallback to NLTK VADER sentiment analyzer")
    except:
        print("NLTK resource download failed. Sentiment analysis will be disabled.")

def preprocess_text(text):
    """Preprocess text for sentiment analysis"""
    if not text:
        return ""
    # Convert to lowercase
    text = text.lower()
    # Remove special characters and numbers
    text = re.sub(r'[^a-zA-Z\s]', '', text)
    # Remove extra spaces
    text = re.sub(r'\s+', ' ', text).strip()
    return text

def analyze_sentiment(text):
    """
    Analyze sentiment of text and return a score between -1 (negative) and 1 (positive)
    Uses custom model if available, otherwise falls back to NLTK VADER
    """
    if not text:
        return 0  # Neutral sentiment for empty text
        
    try:
        # Check if custom model is available
        if 'sentiment_model' in globals() and 'vectorizer' in globals():
            # Preprocess text
            processed_text = preprocess_text(text)
            # Convert to bag of words
            bow = vectorizer.transform([processed_text])
            # Predict sentiment (-1, 0, 1)
            return sentiment_model.predict(bow)[0]
        # Fallback to NLTK if custom model is not available
        elif 'sentiment_analyzer' in globals():
            sentiment_scores = sentiment_analyzer.polarity_scores(text)
            # Get the compound score which ranges from -1 (negative) to 1 (positive)
            return sentiment_scores['compound']
        else:
            # If no sentiment analysis is available
            return 0
    except Exception as e:
        print(f"Error analyzing sentiment: {str(e)}")
        return 0  # Return neutral sentiment on error

@sentiment_blueprint.route('/user/<user_id>/standard-recommendations', methods=['GET'])
def get_standard_recommendations(user_id):
    # Get database from app context
    db = sentiment_blueprint.db
    users_collection = db.users
    
    try:
        # Check cache first
        cache_key = f"std_rec_{user_id}"
        cached_result = cache.get(cache_key)
        if cached_result:
            return jsonify(cached_result), 200
        
        # Convert the string user ID to MongoDB ObjectId
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
            
            # Track domain comment counts separately for sentiment analysis
            domain_comment_counts = {domain.lower(): 0 for domain in domain_scores.keys()}
            
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
            
            # Apply custom sentiment analysis to comments
            for article in commented_articles:
                if 'domain' in article and 'commentText' in article:
                    domain = article['domain'].lower()
                    if domain in domain_scores:
                        # Get sentiment score using custom model (-1, 0, or 1)
                        sentiment_score = analyze_sentiment(article['commentText'])
                        
                        # Adjust comment count based on sentiment
                        if sentiment_score > 0:  # Positive sentiment
                            domain_comment_counts[domain] += 1
                        elif sentiment_score < 0:  # Negative sentiment
                            domain_comment_counts[domain] = max(0, domain_comment_counts[domain] - 1)
                        # Neutral sentiment leaves count unchanged
            
            # Add sentiment-adjusted comment scores to domain scores
            for domain, comment_count in domain_comment_counts.items():
                domain_scores[domain] += comment_count * 0.2
            
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
            
            # Select articles based on domain percentiles
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
            
            # Get additional random articles from domains with percentile <= 50
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
        
        # Prepare response
        response_data = {
            "standardRecommendedArticles": unique_articles[:40],  # Limit to 40 articles
            "count": len(unique_articles[:40]),
            "method": "Interest, interaction, and custom sentiment-based recommendations"
        }
        
        # Cache the result for 30 minutes (1800 seconds)
        cache.set(cache_key, response_data, timeout=1800)
        
        return jsonify(response_data), 200
            
    except Exception as e:
        return jsonify({"error": f"An error occurred: {str(e)}"}), 500

# Define the initialization function to pass database connection and other resources from main app
def init_app(app, database):
    sentiment_blueprint.db = database