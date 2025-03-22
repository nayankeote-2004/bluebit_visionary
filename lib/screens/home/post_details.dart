import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tik_tok_wikipidiea/models/post_content.dart';

class DetailScreen extends StatefulWidget {
  final Post post;

  DetailScreen({required this.post});

  @override
  _DetailScreenState createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  // List of article sections
  List<ArticleSection> sections = [];
  bool _isLoading = true;
  // Controller to track scroll position
  final ScrollController _scrollController = ScrollController();
  bool _showTitleInAppBar = false;
  final double _appBarTitleThreshold = 250.0;

  @override
  void initState() {
    super.initState();
    // Load article sections from API
    _loadArticleSections();

    // Add scroll listener to show/hide title in app bar
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final showTitle = _scrollController.offset > _appBarTitleThreshold;
    if (showTitle != _showTitleInAppBar) {
      setState(() {
        _showTitleInAppBar = showTitle;
      });
    }
  }

  // This method would fetch data from your API
  // For now, we're simulating an API call with a Future.delayed
  Future<void> _loadArticleSections() async {
    // Simulate API loading delay
    await Future.delayed(Duration(milliseconds: 500));

    // In a real app, you'd fetch data from your API
    // final response = await apiService.getArticleSections(widget.post.id);
    // final List<dynamic> sectionsData = response.data;

    // For demonstration, we'll use dummy data
    // This would be replaced with actual API data parsing
    List<Map<String, dynamic>> apiSectionsData = [
      {'title': 'Introduction', 'content': widget.post.description},
      {
        'title': 'Overview',
        'content':
            "This section provides an overview of the topic. ${widget.post.description} "
            "The information here gives readers context about the subject matter and its importance.",
      },
      {
        'title': 'History',
        'content':
            "The historical background of this topic dates back many years. "
            "The evolution of ${widget.post.source} publications on this subject shows how understanding has developed over time.",
      },
      {
        'title': 'Applications',
        'content':
            "There are numerous practical applications for this knowledge. "
            "Industries ranging from technology to healthcare have implemented these concepts in various ways.",
      },
      {
        'title': 'Scientific Analysis',
        'content':
            "Scientific studies have examined this topic from multiple angles. "
            "Research published in ${widget.post.source} demonstrated significant findings related to this subject.",
      },
      {
        'title': 'References',
        'content':
            "1. ${widget.post.source} (${DateTime.now().year}). Primary research on the topic.\n"
            "2. International Journal of ${widget.post.source.split(' ')[0]} (${DateTime.now().year - 2}). Comparative analysis.",
      },
    ];

    // Parse API data into ArticleSection objects
    final parsedSections =
        apiSectionsData.map((sectionData) {
          return ArticleSection(
            title: sectionData['title'] ?? 'Untitled Section',
            content: sectionData['content'] ?? 'No content available',
            // First two sections expanded by default
            isExpanded: apiSectionsData.indexOf(sectionData) < 2,
          );
        }).toList();

    if (mounted) {
      setState(() {
        sections = parsedSections;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get theme brightness to adapt UI accordingly
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    // Get article title for app bar
    final articleTitle = widget.post.description.split('.').first + ".";

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            // App Bar with Image (modified to show/hide title while scrolling)
            SliverAppBar(
              expandedHeight: 250.0,
              floating: false,
              pinned: true,
              backgroundColor:
                  isDarkMode
                      ? Colors.black.withOpacity(0.7)
                      : Colors.white.withOpacity(0.7),
              title:
                  _showTitleInAppBar
                      ? Text(
                        articleTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                      : null,
              flexibleSpace: FlexibleSpaceBar(
                // Removed source text from here
                background: Hero(
                  tag: widget.post.image,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        widget.post.image,
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
                    Icons.arrow_back_ios,
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
                    Clipboard.setData(
                      ClipboardData(text: widget.post.description),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Content copied to clipboard")),
                    );
                  },
                ),
                SizedBox(width: 8),
              ],
            ),

            // Content Section with expandable sections
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title / First line as heading
                    Text(
                      articleTitle,
                      style: Theme.of(context).textTheme.displayMedium
                          ?.copyWith(fontSize: 24, height: 1.3),
                    ),
                    SizedBox(height: 24),

                    // Loading indicator or sections
                    _isLoading
                        ? _buildLoadingIndicator(theme)
                        : Column(
                          children:
                              sections
                                  .map(
                                    (section) => _buildExpandableSection(
                                      section,
                                      context,
                                      isDarkMode,
                                    ),
                                  )
                                  .toList(),
                        ),

                    SizedBox(height: 30),

                    // Source information (keeping existing code)
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
                                widget.post.source.substring(0, 1),
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
                                widget.post.source,
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

                    SizedBox(height: 50), // Extra space at the bottom
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Loading indicator widget
  Widget _buildLoadingIndicator(ThemeData theme) {
    return Center(
      child: Column(
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
          ),
          SizedBox(height: 16),
          Text(
            "Loading article sections...",
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  // Expandable section widget
  Widget _buildExpandableSection(
    ArticleSection section,
    BuildContext context,
    bool isDarkMode,
  ) {
    final theme = Theme.of(context);

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header/title with expand/collapse button
          InkWell(
            onTap: () {
              setState(() {
                section.isExpanded = !section.isExpanded;
              });
            },
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      section.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    section.isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: theme.iconTheme.color,
                  ),
                ],
              ),
            ),
          ),

          // Section content (only visible when expanded)
          AnimatedCrossFade(
            firstChild: Container(height: 0),
            secondChild: Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                section.content,
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.6,
                  fontSize: 16,
                ),
              ),
            ),
            crossFadeState:
                section.isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
            duration: Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }
}

// Model for article sections
class ArticleSection {
  final String title;
  final String content;
  bool isExpanded;

  ArticleSection({
    required this.title,
    required this.content,
    this.isExpanded = false,
  });

  // Factory constructor to create from API JSON
  factory ArticleSection.fromJson(Map<String, dynamic> json) {
    return ArticleSection(
      title: json['title'] ?? 'Untitled',
      content: json['content'] ?? '',
      isExpanded: json['isExpanded'] ?? false,
    );
  }
}
