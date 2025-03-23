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