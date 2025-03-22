import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tik_tok_wikipidiea/models/post_content.dart';

class DetailScreen extends StatelessWidget {
  final Post post;

  DetailScreen({required this.post});

  @override
  Widget build(BuildContext context) {
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
              backgroundColor: Colors.black.withValues(alpha: 10),
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  "SOURCE: ${post.source}",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
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
                            color: Colors.grey[800],
                            child: Center(
                              child: Icon(
                                Icons.broken_image,
                                size: 50,
                                color: Colors.white70,
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
                              Colors.black.withOpacity(0.7),
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
                    color: Colors.black38,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_back_ios, color: Colors.white),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  icon: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.share, color: Colors.white),
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
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.3,
                      ),
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
                          top: BorderSide(color: Colors.grey[800]!, width: 1),
                          bottom: BorderSide(
                            color: Colors.grey[800]!,
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
                              color: Colors.grey[700],
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                post.source.substring(0, 1),
                                style: TextStyle(
                                  color: Colors.white,
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
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Published on ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[400],
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
                          icon: Icons.favorite_border,
                          label: "Like",
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Article liked")),
                            );
                          },
                        ),
                        _buildActionButton(
                          icon: Icons.bookmark_border,
                          label: "Save",
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Article saved")),
                            );
                          },
                        ),
                        _buildActionButton(
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
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: Colors.white70),
          SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }
}
