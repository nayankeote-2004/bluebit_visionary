import 'package:flutter/material.dart';
import 'package:tik_tok_wikipidiea/models/post_content.dart';

// Model for comment data
class Comment {
  final String username;
  final String avatarUrl;
  final String text;
  final DateTime timestamp;
  bool isLiked;
  int likeCount;

  Comment({
    required this.username,
    required this.avatarUrl,
    required this.text,
    required this.timestamp,
    this.isLiked = false,
    this.likeCount = 0,
  });
}

class CommentsSheet extends StatefulWidget {
  final Post post;

  const CommentsSheet({Key? key, required this.post}) : super(key: key);

  @override
  _CommentsSheetState createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = true;
  List<Comment> _comments = [];

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Simulates fetching comments from a backend
  Future<void> _fetchComments() async {
    // Simulate network delay
    await Future.delayed(Duration(milliseconds: 800));

    // Simulated comments data that would come from backend
    final List<Comment> fetchedComments = [
      Comment(
        username: "AlexReads",
        avatarUrl: "https://i.pravatar.cc/150?img=1",
        text:
            "This article is very insightful. I've been searching for this kind of information for a while.",
        timestamp: DateTime.now().subtract(Duration(hours: 2)),
        likeCount: 15,
      ),
      Comment(
        username: "BookwormSarah",
        avatarUrl: "https://i.pravatar.cc/150?img=5",
        text: "I disagree with some points here. The data seems outdated.",
        timestamp: DateTime.now().subtract(Duration(hours: 5)),
        likeCount: 3,
      ),
      Comment(
        username: "HistoryBuff42",
        avatarUrl: "https://i.pravatar.cc/150?img=11",
        text:
            "Thanks for sharing this! Very well written and easy to understand.",
        timestamp: DateTime.now().subtract(Duration(days: 1)),
        likeCount: 27,
      ),
      Comment(
        username: "CuriousMind",
        avatarUrl: "https://i.pravatar.cc/150?img=9",
        text:
            "I have a question about the second section. Can anyone clarify what the author means by that statement?",
        timestamp: DateTime.now().subtract(Duration(days: 2)),
        likeCount: 8,
      ),
    ];

    if (mounted) {
      setState(() {
        _comments = fetchedComments;
        _isLoading = false;
      });
    }
  }

  // Add a new comment
  void _addComment() {
    if (_commentController.text.trim().isEmpty) return;

    setState(() {
      _comments.insert(
        0,
        Comment(
          username: "You", // In a real app, get from user profile
          avatarUrl:
              "https://i.pravatar.cc/150?img=12", // In a real app, get from user profile
          text: _commentController.text.trim(),
          timestamp: DateTime.now(),
          likeCount: 0,
        ),
      );
      _commentController.clear();
    });

    // Hide keyboard after submitting
    _focusNode.unfocus();
  }

  // Format timestamp to relative time string
  String _formatTimestamp(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);

    if (difference.inDays > 7) {
      return "${timestamp.day}/${timestamp.month}/${timestamp.year}";
    } else if (difference.inDays > 0) {
      return "${difference.inDays}d ago";
    } else if (difference.inHours > 0) {
      return "${difference.inHours}h ago";
    } else if (difference.inMinutes > 0) {
      return "${difference.inMinutes}m ago";
    } else {
      return "Just now";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Comments",
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(),

          // Comments list or loading indicator
          _isLoading
              ? Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(child: CircularProgressIndicator()),
              )
              : Flexible(
                child:
                    _comments.isEmpty
                        ? _buildEmptyCommentsView(theme)
                        : ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.only(bottom: 8),
                          itemCount: _comments.length,
                          itemBuilder: (context, index) {
                            final comment = _comments[index];
                            return _buildCommentItem(
                              comment,
                              theme,
                              isDarkMode,
                            );
                          },
                        ),
              ),

          Divider(),

          // Comment input field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                // User avatar (smaller)
                CircleAvatar(
                  radius: 16,
                  backgroundImage: NetworkImage(
                    "https://i.pravatar.cc/150?img=12",
                  ),
                  backgroundColor:
                      isDarkMode ? Colors.grey[800] : Colors.grey[200],
                ),
                SizedBox(width: 12),

                // Text input
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: "Add a comment...",
                      hintStyle: TextStyle(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor:
                          isDarkMode ? Colors.grey[800] : Colors.grey[200],
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    style: theme.textTheme.bodyMedium,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                SizedBox(width: 8),

                // Send button
                IconButton(
                  icon: Icon(Icons.send),
                  color: theme.primaryColor,
                  onPressed: _addComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCommentsView(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: theme.iconTheme.color?.withOpacity(0.5),
            ),
            SizedBox(height: 16),
            Text("No comments yet", style: theme.textTheme.titleMedium),
            SizedBox(height: 8),
            Text(
              "Be the first to share your thoughts!",
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentItem(Comment comment, ThemeData theme, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User avatar
          CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage(comment.avatarUrl),
            backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
          ),
          SizedBox(width: 12),

          // Comment content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username and timestamp
                Row(
                  children: [
                    Text(
                      comment.username,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      _formatTimestamp(comment.timestamp),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),

                // Comment text
                Text(comment.text, style: theme.textTheme.bodyMedium),

                // Removed like button, count and reply option
              ],
            ),
          ),
        ],
      ),
    );
  }
}
