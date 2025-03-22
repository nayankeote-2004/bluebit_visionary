import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tik_tok_wikipidiea/models/post_content.dart';

class DetailScreen extends StatelessWidget {
  final Post post;

  DetailScreen({required this.post});

  @override
  Widget build(BuildContext context) {
    // Get theme brightness to adapt UI accordingly
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App Bar with Image
            SliverAppBar(
              expandedHeight: 250.0,
              floating: false,
              pinned: true,
              backgroundColor:
                  isDarkMode
                      ? Colors.black.withOpacity(0.7)
                      : Colors.white.withOpacity(0.7),
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  "SOURCE: ${post.source}",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                background: Hero(
                  tag: post.image,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        post.image,
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
                                color: Theme.of(context).iconTheme.color,
                              ),
                            ),
                          );
                        },
                      ),
                      // Gradient overlay for better text visibility
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              isDarkMode
                                  ? Colors.black.withOpacity(0.7)
                                  : Colors.black.withOpacity(0.4),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              leading: IconButton(
                icon: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        isDarkMode
                            ? Colors.black38
                            : Colors.white.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_back,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  icon: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          isDarkMode
                              ? Colors.black38
                              : Colors.white.withOpacity(0.7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.share,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: post.description));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Content copied to clipboard")),
                    );
                  },
                ),
                SizedBox(width: 8),
              ],
            ),

            // Content Section
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title / First line as heading
                    Text(
                      post.description.split('.').first + ".",
                      style: Theme.of(context).textTheme.displayMedium
                          ?.copyWith(fontSize: 24, height: 1.3),
                    ),
                    SizedBox(height: 16),

                    // Main content
                    Text(
                      post.description,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.5,
                        fontSize: 18,
                      ),
                    ),

                    // Extended content for detail view
                    SizedBox(height: 20),
                    Text(
                      "Additional information about this topic would appear here in a real implementation. "
                      "This expanded view provides more context and details than the preview card. "
                      "Users can read the full article after swiping right from the main feed.",
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),

                    SizedBox(height: 30),

                    // Source information
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Theme.of(context).dividerColor,
                            width: 1,
                          ),
                          bottom: BorderSide(
                            color: Theme.of(context).dividerColor,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              color:
                                  isDarkMode
                                      ? Colors.grey[700]
                                      : Colors.grey[300],
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                post.source.substring(0, 1),
                                style: TextStyle(
                                  color:
                                      isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.source,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Published on ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      isDarkMode
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 30),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildActionButton(
                          context: context,
                          icon: Icons.favorite_border,
                          label: "Like",
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Article liked")),
                            );
                          },
                        ),
                        _buildActionButton(
                          context: context,
                          icon: Icons.bookmark_border,
                          label: "Save",
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Article saved")),
                            );
                          },
                        ),
                        _buildActionButton(
                          context: context,
                          icon: Icons.share,
                          label: "Share",
                          onTap: () {
                            Clipboard.setData(
                              ClipboardData(text: post.description),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Content copied to clipboard"),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).iconTheme.color),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).iconTheme.color,
            ),
          ),
        ],
      ),
    );
  }
}
