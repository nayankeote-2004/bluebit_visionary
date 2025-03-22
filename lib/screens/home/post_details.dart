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
  List<ArticleSection> sections = [];
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  bool _showTitleInAppBar = false;
  final double _appBarTitleThreshold = 250.0;

  @override
  void initState() {
    super.initState();
    _loadArticleSections();
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

  Future<void> _loadArticleSections() async {
    await Future.delayed(Duration(milliseconds: 500)); // Simulate loading

    // Convert post sections to ArticleSection objects
    final parsedSections = widget.post.sections.map((section) {
      return ArticleSection(
        title: section.title,
        content: section.content,
        isExpanded: false, // First two will be set to true below
      );
    }).toList();

    // Set first two sections as expanded by default
    if (parsedSections.isNotEmpty) {
      parsedSections[0].isExpanded = true;
    }
    if (parsedSections.length > 1) {
      parsedSections[1].isExpanded = true;
    }

    if (mounted) {
      setState(() {
        sections = parsedSections;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    
    // Use post title instead of description
    final articleTitle = widget.post.title;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
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
                background: Hero(
                  tag: widget.post.imageUrl, // Updated to use imageUrl
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        widget.post.imageUrl, // Updated to use imageUrl
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

            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.post.title, // Updated to use title
                      style: Theme.of(context).textTheme.displayMedium
                          ?.copyWith(fontSize: 24, height: 1.3),
                    ),
                    SizedBox(height: 24),

                    // Show summary before sections
                    Text(
                      widget.post.summary,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 24),

                    _isLoading
                        ? _buildLoadingIndicator(theme)
                        : Column(
                            children: sections
                                .map((section) => _buildExpandableSection(
                                    section, context, isDarkMode))
                                .toList(),
                          ),

                    SizedBox(height: 30),

                    // Update source information
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
                              color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                widget.post.domain.substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  color: isDarkMode ? Colors.white : Colors.black87,
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
                                widget.post.domain.toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Published on ${widget.post.createdAt}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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

class ArticleSection {
  final String title;
  final String content;
  bool isExpanded;

  ArticleSection({
    required this.title,
    required this.content,
    this.isExpanded = false,
  });

  factory ArticleSection.fromJson(Map<String, dynamic> json) {
    return ArticleSection(
      title: json['title'] ?? 'Untitled',
      content: json['content'] ?? '',
      isExpanded: json['isExpanded'] ?? false,
    );
  }
}
