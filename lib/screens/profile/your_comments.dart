import 'package:flutter/material.dart';
import 'package:tik_tok_wikipidiea/models/post_content.dart';
import 'package:tik_tok_wikipidiea/screens/home/post_details.dart';
import 'package:tik_tok_wikipidiea/config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// First, update the CommentItem class to use DateTime instead of String for timestamp
class CommentItem {
  final Post post;
  final String comment;
  final DateTime timestamp;

  CommentItem({
    required this.post,
    required this.comment,
    required this.timestamp,
  });
}

class YourCommentsPage extends StatefulWidget {
  const YourCommentsPage({Key? key}) : super(key: key);

  @override
  _YourCommentsPageState createState() => _YourCommentsPageState();
}

class _YourCommentsPageState extends State<YourCommentsPage> {
  List<CommentItem> userComments = [];
  bool isLoading = true;
  String userId = "";

  @override
  void initState() {
    super.initState();
    _loadUserIdAndFetchComments();
  }

  Future<void> _loadUserIdAndFetchComments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getString('userId') ?? "";

      if (userId.isNotEmpty) {
        await _fetchUserComments();
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

  Future<void> _fetchUserComments() async {
    if (userId.isEmpty) return;

    setState(() {
      isLoading = true;
    });

    try {
      final baseUrl = Config.baseUrl;
      // Get the user's commented article IDs
      final interactionsResponse = await http.get(
        Uri.parse('$baseUrl/user/$userId/interactions'),
      );

      if (interactionsResponse.statusCode == 200) {
        final data = json.decode(interactionsResponse.body);
        final commentedArticles = data['commentedArticles'] ?? [];
        print('Commented articles: $commentedArticles');
        if (commentedArticles.isEmpty) {
          setState(() {
            userComments = [];
            isLoading = false;
          });
          return;
        }

        // Now fetch details for each commented article
        final List<CommentItem> fetchedComments = [];

        for (var commentData in commentedArticles) {
          try {
            final int articleId = commentData['articleId'];
            final String domain = commentData['domain'];
            final String commentText = commentData['commentText'];

            // Parse the timestamp
            DateTime commentTimestamp;
            try {
              if (commentData['commentedAt'] is int) {
                commentTimestamp = DateTime.fromMillisecondsSinceEpoch(
                  commentData['commentedAt'],
                );
              } else if (commentData['commentedAt'] is String) {
                String commentedAt = commentData['commentedAt'];
                try {
                  // First try ISO format
                  commentTimestamp = DateTime.parse(commentedAt);
                } catch (parseError) {
                  // Try HTTP date format (e.g., "Sun, 23 Mar 2025 05:34:21 GMT")
                  try {
                    final RegExp httpDatePattern = RegExp(
                      r'^[A-Za-z]{3}, (\d{1,2}) ([A-Za-z]{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$',
                    );
                    final match = httpDatePattern.firstMatch(commentedAt);

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

                      commentTimestamp = DateTime.utc(
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
                    print('HTTP date parsing failed for: $commentedAt');
                    commentTimestamp = DateTime.now();
                  }
                }
              } else {
                commentTimestamp = DateTime.now();
              }
            } catch (e) {
              print(
                'Error parsing timestamp: $e for value: ${commentData['commentedAt']}',
              );
              commentTimestamp = DateTime.now();
            }

            final articleResponse = await http.get(
              Uri.parse('$baseUrl/domains/$domain/articles/$articleId'),
            );

            if (articleResponse.statusCode == 200) {
              final articleData = json.decode(articleResponse.body);

              // Print the actual structure for debugging
              print('Article data structure: ${articleData.runtimeType}');
              print(
                'Article comments type: ${articleData['article']['comments'].runtimeType}',
              );

              // Create a copy of the article data to modify
              final modifiedArticleData = Map<String, dynamic>.from(
                articleData['article'],
              );

              // Convert comments to the expected format if needed
              if (modifiedArticleData.containsKey('comments')) {
                if (modifiedArticleData['comments'] is List) {
                  // Ensure comments are strings
                  List<dynamic> rawComments = modifiedArticleData['comments'];
                  modifiedArticleData['comments'] =
                      rawComments.map((comment) {
                        // If it's a map, extract the text or convert to string
                        if (comment is Map) {
                          return comment['text'] ?? comment.toString();
                        }
                        return comment.toString();
                      }).toList();
                }
              }

              try {
                final post = Post.fromJson(modifiedArticleData);

                fetchedComments.add(
                  CommentItem(
                    post: post,
                    comment: commentText,
                    timestamp: commentTimestamp,
                  ),
                );
              } catch (e) {
                print('Error creating Post from JSON: $e');
                print('Modified article data: $modifiedArticleData');
              }
            }
          } catch (e) {
            print('Error fetching comment details: $e');
          }
        }

        // Sort comments by timestamp, newest first
        fetchedComments.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        setState(() {
          userComments = fetchedComments;
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load user interactions');
      }
    } catch (e) {
      print('Error fetching user comments: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Your Comments'),
        elevation: theme.appBarTheme.elevation,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (userComments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  '${userComments.length} comments',
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
                onRefresh: _fetchUserComments,
                child:
                    userComments.isEmpty
                        ? _buildEmptyState(theme)
                        : _buildCommentsList(userComments, theme, isDarkMode),
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
              color: Colors.amber.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.comment_outlined, size: 60, color: Colors.amber),
          ),
          SizedBox(height: 24),
          Text('No comments yet', style: theme.textTheme.titleLarge),
          SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'Join the conversation by commenting on articles',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton.icon(
            icon: Icon(Icons.home),
            label: Text('Find articles to comment on'),
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

  Widget _buildCommentsList(
    List<CommentItem> comments,
    ThemeData theme,
    bool isDarkMode,
  ) {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: comments.length,
      itemBuilder: (context, index) {
        final commentItem = comments[index];
        final post = commentItem.post;

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Article info section
                  ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(post.imageUrl),
                      onBackgroundImageError: (_, __) {},
                      backgroundColor:
                          isDarkMode ? Colors.grey[800] : Colors.grey[300],
                    ),
                    title: Text(
                      post.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      post.domain,
                      style: TextStyle(
                        color: theme.colorScheme.secondary,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Text(
                      _formatDate(commentItem.timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
              
                  // Divider
                  Divider(height: 1),
              
                  // Comment content
                  Container(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Comment label
                        Row(
                          children: [
                            Icon(
                              Icons.comment,
                              size: 16,
                              color: Colors.amber,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Your comment:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
              
                        SizedBox(height: 12),
              
                        // Comment text
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                isDarkMode
                                    ? Colors.grey[850]
                                    : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  isDarkMode
                                      ? Colors.grey[700]!
                                      : Colors.grey[300]!,
                            ),
                          ),
                          child: Text(
                            commentItem.comment,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
              
                        SizedBox(height: 16),
              
                        // Read article button
                      ],
                    ),
                  ),
                ],
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
}
