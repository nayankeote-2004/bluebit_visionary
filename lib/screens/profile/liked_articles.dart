import 'package:flutter/material.dart';
import 'package:tik_tok_wikipidiea/config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tik_tok_wikipidiea/models/comment.dart';
import 'package:tik_tok_wikipidiea/screens/home/post_details.dart';
import 'package:tik_tok_wikipidiea/models/post_content.dart';

class LikedArticle {
  final int articleId;
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
    DateTime parsedDate;
    try {
      if (json['likedAt'] != null) {
        var likedAt = json['likedAt'];

        // Case 1: Integer timestamp (milliseconds)
        if (likedAt is int) {
          parsedDate = DateTime.fromMillisecondsSinceEpoch(likedAt);
        }
        // Case 2: String representation
        else if (likedAt is String) {
          // Case 2a: Numeric string - could be seconds or milliseconds
          if (RegExp(r'^\d+$').hasMatch(likedAt)) {
            int timestamp = int.parse(likedAt);
            // If it's likely seconds (Unix timestamp), convert to milliseconds
            if (timestamp < 2000000000) {
              parsedDate = DateTime.fromMillisecondsSinceEpoch(
                timestamp * 1000,
              );
            } else {
              parsedDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
            }
          }
          // Case 2b: Try parsing as ISO format
          else {
            try {
              parsedDate = DateTime.parse(likedAt);
            } catch (e) {
              // Case 2c: Try HTTP date format (e.g., "Sun, 23 Mar 2025 12:15:40 GMT")
              try {
                // Example: "Sun, 23 Mar 2025 12:15:40 GMT"
                final RegExp httpDatePattern = RegExp(
                  r'^[A-Za-z]{3}, (\d{1,2}) ([A-Za-z]{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$',
                );
                final match = httpDatePattern.firstMatch(likedAt);

                if (match != null) {
                  final day = int.parse(match.group(1)!);
                  final monthStr = match.group(2)!;
                  final year = int.parse(match.group(3)!);
                  final hour = int.parse(match.group(4)!);
                  final minute = int.parse(match.group(5)!);
                  final second = int.parse(match.group(6)!);

                  // Convert month string to number
                  final months = {
                    'Jan': 1,
                    'Feb': 2,
                    'Mar': 3,
                    'Apr': 4,
                    'May': 5,
                    'Jun': 6,
                    'Jul': 7,
                    'Aug': 8,
                    'Sep': 9,
                    'Oct': 10,
                    'Nov': 11,
                    'Dec': 12,
                  };
                  final month = months[monthStr] ?? 1;

                  parsedDate = DateTime.utc(
                    year,
                    month,
                    day,
                    hour,
                    minute,
                    second,
                  );
                } else {
                  throw FormatException('Not an HTTP date format');
                }
              } catch (httpError) {
                print('HTTP date parsing failed for: $likedAt');

                // Try MM/dd/yyyy format as before
                try {
                  var parts = likedAt.split('/');
                  if (parts.length == 3) {
                    parsedDate = DateTime(
                      int.parse(parts[2]), // year
                      int.parse(parts[0]), // month
                      int.parse(parts[1]), // day
                    );
                  } else {
                    throw FormatException('Unrecognized date format');
                  }
                } catch (e) {
                  print('All date parsing attempts failed for: $likedAt');
                  parsedDate = DateTime.now();
                }
              }
            }
          }
        } else {
          print('Unexpected likedAt type: ${likedAt.runtimeType}');
          parsedDate = DateTime.now();
        }
      } else {
        print('likedAt field is null');
        parsedDate = DateTime.now();
      }
    } catch (e) {
      print('Error parsing date: $e for value: ${json['likedAt']}');
      parsedDate = DateTime.now();
    }

    return LikedArticle(
      articleId: json['articleId'],
      domain: json['domain'],
      articleTitle: json['articleTitle'],
      likedAt: parsedDate,
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
                  _fetchAndNavigateToArticleDetails(article);
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

    // For very recent likes (less than a minute)
    if (difference.inMinutes < 1) {
      return 'just now';
    }
    // Within the last hour
    else if (difference.inHours < 1) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    }
    // Within the last day
    else if (difference.inDays < 1) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    }
    // Within the last week
    else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    }
    // Within the current year
    else if (date.year == now.year) {
      // Format as "Jan 15" or "Oct 2"
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}';
    }
    // Older dates
    else {
      // Format as "Jan 15, 2024"
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }

  Future<void> _unlikeArticle(int articleId, String domain) async {
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

  Future<void> _fetchAndNavigateToArticleDetails(
    LikedArticle likedArticle,
  ) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(child: CircularProgressIndicator());
        },
      );

      final baseUrl = Config.baseUrl;
      final response = await http.get(
        Uri.parse(
          '$baseUrl/domains/${likedArticle.domain}/articles/${likedArticle.articleId}',
        ),
      );

      // Dismiss loading indicator
      Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final articleData = data['article'];

        // Create Post object from the API response
        final post = Post(
          id: articleData['id'] ?? likedArticle.articleId,
          title: articleData['title'] ?? likedArticle.articleTitle,
          imageUrl: articleData['image_url'] ?? '',
          summary: articleData['summary'] ?? '',
          domain: articleData['domain'] ?? likedArticle.domain,
          createdAt: articleData['created_at'] ?? '',
          funFact: articleData['fun_fact'] ?? '',
          readingTime: articleData['reading_time'] ?? 0,
          relatedTopics: List<String>.from(articleData['related_topics'] ?? []),
          sections:
              (articleData['sections'] as List<dynamic>? ?? [])
                  .map((section) => Section.fromJson(section))
                  .toList(),
          comments: List<Comment>.from(articleData['comments'] ?? []),
          isLiked: true, // Since this is coming from liked articles
        );

        // Navigate to the detail screen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => DetailScreen(post: post)),
        );
      } else {
        throw Exception('Failed to load article details');
      }
    } catch (e) {
      print('Error fetching article details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load article details'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
