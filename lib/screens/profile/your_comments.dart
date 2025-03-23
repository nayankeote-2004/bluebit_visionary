import 'package:flutter/material.dart';
import 'package:tik_tok_wikipidiea/models/post_content.dart';
import 'package:tik_tok_wikipidiea/screens/home/post_details.dart';
import 'package:tik_tok_wikipidiea/config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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
            // Extract domain, article ID and comment from the stored format
            // Assuming format: { articleId: "domain:id", comment: "text", timestamp: date }
            final String articleId = commentData['articleId'];
            final String commentText = commentData['comment'];
            final DateTime timestamp = DateTime.parse(commentData['timestamp']);

            final parts = articleId.split(':');
            if (parts.length == 2) {
              final String domain = parts[0];
              final String id = parts[1];

              final articleResponse = await http.get(
                Uri.parse('$baseUrl/domains/$domain/articles/$id'),
              );

              if (articleResponse.statusCode == 200) {
                final articleData = json.decode(articleResponse.body);
                final post = Post.fromJson(articleData);

                fetchedComments.add(
                  CommentItem(
                    post: post,
                    comment: commentText,
                    timestamp: timestamp,
                  ),
                );
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
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.article_outlined, size: 18),
                              label: Text('View Article'),
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
}
