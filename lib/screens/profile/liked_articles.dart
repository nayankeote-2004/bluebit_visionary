import 'package:flutter/material.dart';
import 'package:tik_tok_wikipidiea/config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class LikedArticle {
  final String articleId;
  final String domain;
  final String articleTitle;
  final DateTime likedAt;

  LikedArticle({
    required this.articleId,
    required this.domain,
    required this.articleTitle,
    required this.likedAt,
  });

  factory LikedArticle.fromJson(Map<String, dynamic> json) {
    return LikedArticle(
      articleId: json['articleId'],
      domain: json['domain'],
      articleTitle: json['articleTitle'],
      likedAt:
          json['likedAt'] != null && json['likedAt']['\$date'] != null
              ? DateTime.parse(json['likedAt']['\$date'])
              : DateTime.now(),
    );
  }
}

class LikedArticlesPage extends StatefulWidget {
  final List<dynamic> likedArticles;

  const LikedArticlesPage({Key? key, required this.likedArticles})
    : super(key: key);

  @override
  _LikedArticlesPageState createState() => _LikedArticlesPageState();
}

class _LikedArticlesPageState extends State<LikedArticlesPage> {
  List<LikedArticle> articles = [];
  bool isLoading = true;
  String userId = "";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Load user ID from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getString('userId') ?? "";

      // Parse the likedArticles data
      articles =
          widget.likedArticles
              .map((article) => LikedArticle.fromJson(article))
              .toList();

      // Sort by most recent first
      //articles.sort((a, b) => b.likedAt.compareTo(a.likedAt));

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _refreshLikedArticles() async {
    // Just re-process the existing data
    setState(() {
      isLoading = true;
    });

    await Future.delayed(Duration(milliseconds: 300));

    setState(() {
      isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'To see updated likes, please go back and return to this page',
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
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
          if (articles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  '${articles.length} liked',
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
                onRefresh: _refreshLikedArticles,
                child:
                    articles.isEmpty
                        ? _buildEmptyState(theme)
                        : _buildLikedArticlesList(articles, theme, isDarkMode),
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
    List<LikedArticle> articles,
    ThemeData theme,
    bool isDarkMode,
  ) {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: articles.length,
      itemBuilder: (context, index) {
        final article = articles[index];
        final likedAt = _formatDate(article.likedAt);

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
                  // Show details if needed in the future
                },
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Domain badge
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          article.domain.toUpperCase(),
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),

                      SizedBox(height: 12),

                      // Title
                      Text(
                        article.articleTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 8),

                      // Liked timestamp
                      Row(
                        children: [
                          Icon(Icons.favorite, color: Colors.red, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Liked $likedAt',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),

                      SizedBox(height: 16),

                      // Unlike button
                      OutlinedButton.icon(
                        icon: Icon(Icons.favorite, color: Colors.red, size: 18),
                        label: Text('Unlike'),
                        onPressed:
                            () => _unlikeArticle(
                              article.articleId,
                              article.domain,
                            ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(color: Colors.red),
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} min ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _unlikeArticle(String articleId, String domain) async {
    try {
      final baseUrl = Config.baseUrl;

      // Call the API to unlike the article
      final response = await http.delete(
        Uri.parse('$baseUrl/user/$userId/like'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'articleId': articleId, 'domain': domain}),
      );

      if (response.statusCode == 200) {
        setState(() {
          articles.removeWhere(
            (article) =>
                article.articleId == articleId && article.domain == domain,
          );
        });

        // Show a confirmation message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Article removed from liked items'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception('Failed to unlike article');
      }
    } catch (e) {
      print('Error unliking article: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to unlike article. Please try again.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}