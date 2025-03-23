import 'package:flutter/material.dart';
import 'package:tik_tok_wikipidiea/models/post_content.dart';
import 'package:tik_tok_wikipidiea/screens/home/post_details.dart';
import 'package:tik_tok_wikipidiea/config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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
  const LikedArticlesPage({Key? key}) : super(key: key);

  @override
  _LikedArticlesPageState createState() => _LikedArticlesPageState();
}

class _LikedArticlesPageState extends State<LikedArticlesPage> {
  List<Post> likedPosts = [];
  List<LikedArticle> likedArticles = [];
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
        final likedArticlesData = data['likedArticles'] ?? [];

        print("likedArticleData" + likedArticlesData);
        if (likedArticlesData.isEmpty) {
          setState(() {
            likedPosts = [];
            likedArticles = [];
            isLoading = false;
          });
          return;
        }

        // // Parse the liked articles data with error handling
        // try {
        //   likedArticles =
        //       (likedArticlesData as List)
        //           .map((article) => LikedArticle.fromJson(article))
        //           .toList();

        //   // Sort by most recent first
        //   likedArticles.sort((a, b) => b.likedAt.compareTo(a.likedAt));
        // } catch (e) {
        //   print('Error parsing liked articles: $e');
        //   likedArticles = [];
        // }

        // Now fetch details for each liked article
        final List<Post> fetchedPosts = [];

        for (var article in likedArticles) {
          try {
            final articleResponse = await http.get(
              Uri.parse(
                '$baseUrl/domains/${article.domain}/articles/${article.articleId}',
              ),
            );

            if (articleResponse.statusCode == 200) {
              final responseData = json.decode(articleResponse.body);
              final articleData =
                  responseData['article']; // Extract the article data

              // Safely extract fields with null checking
              int articleId = article.articleId;
              if (articleData['id'] != null) {
                // Try to parse the id if it's a string
                if (articleData['id'] is String) {
                  articleId =
                      int.tryParse(articleData['id']) ?? article.articleId;
                } else if (articleData['id'] is int) {
                  articleId = articleData['id'];
                }
              }

              // Create a Post object with much safer type handling
              final post = Post(
                id: articleId,
                title: articleData['title']?.toString() ?? article.articleTitle,
                domain: article.domain,
                summary:
                    articleData['summary']?.toString() ??
                    "No summary available",
                imageUrl:
                    articleData['image_url']?.toString() ??
                    "https://via.placeholder.com/300x200?text=${article.domain}",
                createdAt: _formatCreatedAt(
                  articleData['created_at'],
                  article.likedAt,
                ),
                funFact:
                    articleData['fun_fact']?.toString() ??
                    "No fun fact available",
                readingTime: _safeExtractInt(articleData['reading_time'], 3),
                relatedTopics: _safeExtractRelatedTopics(
                  articleData['related_topics'],
                ),
                sections: _safeConvertToSections(articleData['sections']),
                isLiked: true,
                comments: _safeExtractComments(articleData['comments']),
                isBookmarked: false,
              );
              fetchedPosts.add(post);
            } else {
              // If we can't get the full article data, create a simplified post
              final post = Post(
                id: article.articleId,
                title: article.articleTitle,
                domain: article.domain,
                summary: "Summary not available",
                imageUrl:
                    "https://via.placeholder.com/300x200?text=${article.domain}",
                createdAt: article.likedAt.toString(),
                funFact: "No fun fact available",
                readingTime: 2,
                relatedTopics: [],
                sections: [],
                isLiked: true,
                comments: [],
                isBookmarked: false,
              );
              fetchedPosts.add(post);
            }
          } catch (e) {
            print(
              'Error fetching article details for ${article.articleTitle}: $e',
            );
            // Create a fallback post even if there's an error
            try {
              final post = Post(
                id: article.articleId,
                title: article.articleTitle,
                domain: article.domain,
                summary: "Error loading article details",
                imageUrl: "https://via.placeholder.com/300x200?text=Error",
                createdAt: article.likedAt.toString(),
                funFact: "No fun fact available",
                readingTime: 1,
                relatedTopics: [],
                sections: [],
                isLiked: true,
                comments: [],
                isBookmarked: false,
              );
              fetchedPosts.add(post);
            } catch (fallbackError) {
              print('Error creating fallback post: $fallbackError');
            }
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
            (p) =>
                p.id == int.tryParse(post.id.toString()) &&
                p.domain == post.domain,
          );
          likedArticles.removeWhere(
            (a) =>
                a.articleId == int.tryParse(post.id.toString()) &&
                a.domain == post.domain,
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
        final likedAt =
            index < likedArticles.length
                ? _formatDate(likedArticles[index].likedAt)
                : "";

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

                        // Overlay for source and liked date
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
                                  post.domain.toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.favorite,
                                      color: Colors.red,
                                      size: 14,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Liked $likedAt',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
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

                          // Reading time, topics, and likes count
                          Row(
                            children: [
                              Icon(Icons.timer, size: 16, color: Colors.grey),
                              SizedBox(width: 4),
                              Text(
                                "${post.readingTime} min read",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(width: 16),
                              // Show like count if available
                              Icon(
                                Icons.favorite,
                                size: 16,
                                color: Colors.grey,
                              ),
                              SizedBox(width: 4),
                              // Text(
                              //   post is Map && post.containsKey('likes')
                              //       ? "${post['likes']} likes"
                              //       : "0 likes",
                              //   style: TextStyle(
                              //     color: Colors.grey,
                              //     fontSize: 12,
                              //   ),
                              // ),
                              SizedBox(width: 16),
                              if (post.relatedTopics.isNotEmpty) ...[
                                Icon(Icons.tag, size: 16, color: Colors.grey),
                                SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    post.relatedTopics.take(2).join(', '),
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),

                          // Add a fun fact if available and non-empty
                          if (post.funFact != null &&
                              post.funFact.isNotEmpty &&
                              post.funFact != "No fun fact available") ...[
                            SizedBox(height: 16),
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(
                                  0.1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.lightbulb_outline,
                                    color: theme.colorScheme.primary,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Fun fact: ${post.funFact}",
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic,
                                        color:
                                            isDarkMode
                                                ? Colors.white70
                                                : Colors.black87,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

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

  // Add these helper methods to the _LikedArticlesPageState class

  // Helper method to convert section maps to Section objects
  List<Section> _convertToSections(dynamic sectionsData) {
    if (sectionsData == null) return [];

    try {
      return (sectionsData as List)
          .map(
            (section) => Section(
              title: section['title'] ?? '',
              content: section['content'] ?? '',
            ),
          )
          .toList();
    } catch (e) {
      print('Error converting sections: $e');
      return [];
    }
  }

  // Helper method to extract minutes from reading time string or use default
  int _extractReadingTimeMinutes(dynamic readingTime) {
    if (readingTime == null) return 3; // Default to 3 minutes

    // If it's already an int, return it
    if (readingTime is int) return readingTime;

    // If it's a string like "3 min read", extract the number
    if (readingTime is String) {
      final regex = RegExp(r'(\d+)');
      final match = regex.firstMatch(readingTime);
      if (match != null) {
        return int.tryParse(match.group(1) ?? '3') ?? 3;
      }
    }

    return 3; // Default fallback
  }

  // Add this helper method for extracting related topics
  List<String> _extractRelatedTopics(dynamic topicsData) {
    if (topicsData == null) return [];

    try {
      if (topicsData is List) {
        return List<String>.from(topicsData.map((topic) => topic.toString()));
      }
    } catch (e) {
      print('Error extracting related topics: $e');
    }

    return [];
  }

  // Add this helper method for extracting comments
  List<String> _extractComments(dynamic commentsData) {
    if (commentsData == null) return [];

    try {
      if (commentsData is List) {
        if (commentsData.isEmpty) return [];

        // If comments are objects with a text field, extract that
        if (commentsData.first is Map) {
          return List<String>.from(
            commentsData.map((comment) => comment['text']?.toString() ?? ''),
          );
        }

        // If comments are strings
        return List<String>.from(
          commentsData.map((comment) => comment.toString()),
        );
      }
    } catch (e) {
      print('Error extracting comments: $e');
    }

    return [];
  }

  // Add this helper method to your _LikedArticlesPageState class
  int? _parseIdToInt(dynamic id) {
    if (id == null) return null;
    if (id is int) return id;
    if (id is String) {
      return int.tryParse(id);
    }
    return null;
  }
}

// Safer helper methods
String _formatCreatedAt(dynamic createdAt, DateTime fallbackDate) {
  try {
    if (createdAt != null && createdAt['\$date'] != null) {
      return DateTime.parse(createdAt['\$date']).toString();
    }
  } catch (e) {
    print('Error parsing date: $e');
  }
  return fallbackDate.toString();
}

int _safeExtractInt(dynamic value, int defaultValue) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is String) {
    return int.tryParse(value) ?? defaultValue;
  }
  return defaultValue;
}

List<String> _safeExtractRelatedTopics(dynamic topicsData) {
  if (topicsData == null) return [];

  try {
    if (topicsData is List) {
      return List<String>.from(
        topicsData.map((topic) => topic?.toString() ?? ""),
      ).where((topic) => topic.isNotEmpty).toList();
    }
  } catch (e) {
    print('Error extracting related topics: $e');
  }

  return [];
}

List<Section> _safeConvertToSections(dynamic sectionsData) {
  if (sectionsData == null) return [];

  try {
    if (sectionsData is List) {
      return sectionsData.map((section) {
        if (section is Map) {
          return Section(
            title: section['title']?.toString() ?? '',
            content: section['content']?.toString() ?? '',
          );
        }
        return Section(title: '', content: '');
      }).toList();
    }
  } catch (e) {
    print('Error converting sections: $e');
  }

  return [];
}

List<String> _safeExtractComments(dynamic commentsData) {
  if (commentsData == null) return [];

  try {
    if (commentsData is List) {
      return commentsData
          .map((comment) {
            if (comment is Map && comment['text'] != null) {
              return comment['text'].toString();
            } else if (comment != null) {
              return comment.toString();
            }
            return "";
          })
          .where((comment) => comment.isNotEmpty)
          .toList();
    }
  } catch (e) {
    print('Error extracting comments: $e');
  }

  return [];
}
