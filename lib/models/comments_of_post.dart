import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';
import '../models/post_content.dart';
import '../models/comment.dart';

class CommentsSheet extends StatefulWidget {
  final Post post;

  const CommentsSheet({Key? key, required this.post}) : super(key: key);

  @override
  _CommentsSheetState createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  bool isLoading = true;
  List<Comment> comments = [];
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final baseUrl = Config.baseUrl;
      final response = await http.get(
        Uri.parse(
          '$baseUrl/domains/${widget.post.domain}/articles/${widget.post.id}/comments',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print(data);
        final fetchedComments =
            (data['comments'] as List)
                .map((comment) => Comment.fromJson(comment))
                .toList();

        setState(() {
          comments = fetchedComments;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load comments';
          isLoading = false;
        });
      }
    } catch (error) {
      setState(() {
        errorMessage = 'Error loading comments: ${error.toString()}';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Comments header
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Comments (${comments.length})',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh),
                onPressed: _loadComments,
                tooltip: 'Refresh comments',
              ),
            ],
          ),
        ),

        Divider(height: 1),

        // Comments list with loading/error states
        Expanded(
          child:
              isLoading
                  ? Center(child: CircularProgressIndicator())
                  : errorMessage != null
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red),
                        SizedBox(height: 16),
                        Text(
                          errorMessage!,
                          style: TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadComments,
                          child: Text('Retry'),
                        ),
                      ],
                    ),
                  )
                  : comments.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No comments yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Be the first to share your thoughts!',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                  : ListView.builder(
                    itemCount: comments.length,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final comment = comments[index];

                      return Container(
                        margin: EdgeInsets.symmetric(vertical: 8),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              isDarkMode ? Colors.grey[850] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 5,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // User info and timestamp
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: theme.primaryColor.withOpacity(
                                          0.2,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          comment.userName.isNotEmpty
                                              ? comment.userName
                                                  .substring(0, 1)
                                                  .toUpperCase()
                                              : 'A',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: theme.primaryColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      comment.userName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                if (comment.timestamp != null)
                                  Text(
                                    comment.timestamp!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),

                            SizedBox(height: 8),

                            // Comment content
                            Text(
                              comment.text,
                              style: TextStyle(fontSize: 14, height: 1.3),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}
