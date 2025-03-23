import 'package:flutter/material.dart';
import 'package:tik_tok_wikipidiea/models/post_content.dart';
import 'package:tik_tok_wikipidiea/screens/home/post_details.dart';
import 'package:tik_tok_wikipidiea/config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class LikedArticlesPage extends StatefulWidget {
  const LikedArticlesPage({Key? key}) : super(key: key);

  @override
  _LikedArticlesPageState createState() => _LikedArticlesPageState();
}

class _LikedArticlesPageState extends State<LikedArticlesPage> {
  List<Post> likedPosts = [];
  bool isLoading = true;
  String userId = "";

  @override
  void initState() {
    super.initState();
    _loadUserIdAndFetchLikedArticles();
  }

  Future<void> _loadUserIdAndFetchLikedArticles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getString('userId') ?? "";

      if (userId.isNotEmpty) {
        await _fetchLikedArticles();
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user ID: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchLikedArticles() async {
    if (userId.isEmpty) return;

    setState(() {
      isLoading = true;
    });

    try {
      final baseUrl = Config.baseUrl;
      // Get the user's liked article IDs
      final interactionsResponse = await http.get(
        Uri.parse('$baseUrl/user/$userId/interactions'),
      );

      if (interactionsResponse.statusCode == 200) {
        final data = json.decode(interactionsResponse.body);
        final likedArticleIds = data['likedArticles'] ?? [];

        if (likedArticleIds.isEmpty) {
          setState(() {
            likedPosts = [];
            isLoading = false;
          });
          return;
        }

        // Now fetch details for each liked article
        final List<Post> fetchedPosts = [];

        for (var article in likedArticleIds) {
          try {
            // Extract domain and article ID from the stored format
            final parts = article.split(':');
            if (parts.length == 2) {
              final String domain = parts[0];
              final String articleId = parts[1];

              final articleResponse = await http.get(
                Uri.parse('$baseUrl/domains/$domain/articles/$articleId'),
              );

              if (articleResponse.statusCode == 200) {
                final articleData = json.decode(articleResponse.body);
                final post = Post.fromJson(articleData);
                post.isLiked = true; // Mark as liked
                fetchedPosts.add(post);
              }
            }
          } catch (e) {
            print('Error fetching article details: $e');
          }
        }

        setState(() {
          likedPosts = fetchedPosts;
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load user interactions');
      }
    } catch (e) {
      print('Error fetching liked articles: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _unlikeArticle(Post post) async {
    try {
      final baseUrl = Config.baseUrl;
      final response = await http.post(
        Uri.parse(
          '$baseUrl/domains/${post.domain}/articles/${post.id}/like/$userId',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        setState(() {
          likedPosts.removeWhere(
            (p) => p.id == post.id && p.domain == post.domain,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Article unliked"),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        throw Exception('Failed to unlike article');
      }
    } catch (e) {
      print('Error unliking article: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to unlike article"),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Liked Articles'),
        elevation: theme.appBarTheme.elevation,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (likedPosts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  '${likedPosts.length} liked',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            ),
        ],
      ),
      body:
          isLoading
              ? Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _fetchLikedArticles,
                child:
                    likedPosts.isEmpty
                        ? _buildEmptyState(theme)
                        : _buildLikedArticlesList(
                          likedPosts,
                          theme,
                          isDarkMode,
                        ),
              ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.favorite_border, size: 60, color: Colors.red),
          ),
          SizedBox(height: 24),
          Text('No liked articles yet', style: theme.textTheme.titleLarge),
          SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'Articles you like will appear here for easy access',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton.icon(
            icon: Icon(Icons.home),
            label: Text('Find articles to like'),
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLikedArticlesList(
    List<Post> posts,
    ThemeData theme,
    bool isDarkMode,
  ) {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];

        return Container(
          margin: EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: isDarkMode ? Colors.black26 : Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              color: theme.cardColor,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DetailScreen(post: post),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image with overlay for date and source
                    Stack(
                      children: [
                        // Image
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.network(
                            post.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color:
                                    isDarkMode
                                        ? Colors.grey[800]
                                        : Colors.grey[300],
                                child: Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    size: 50,
                                    color: theme.iconTheme.color,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        // Overlay for source
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.7),
                                ],
                              ),
                            ),
                            padding: EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  post.domain,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Content
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Text(
                            post.title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          SizedBox(height: 8),

                          // Description
                          Text(
                            post.summary,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontSize: 16,
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),

                          SizedBox(height: 16),

                          // Action buttons
                          Row(
                            children: [
                              // Unlike button
                              OutlinedButton.icon(
                                icon: Icon(
                                  Icons.favorite,
                                  color: Colors.red,
                                  size: 18,
                                ),
                                label: Text('Unlike'),
                                onPressed: () => _unlikeArticle(post),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: BorderSide(color: Colors.red),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                              ),

                              SizedBox(width: 12),

                              // Read more button
                              ElevatedButton.icon(
                                icon: Icon(Icons.arrow_forward, size: 18),
                                label: Text('Read more'),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => DetailScreen(post: post),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.primaryColor,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
