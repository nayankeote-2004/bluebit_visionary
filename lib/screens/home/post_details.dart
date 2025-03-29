import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tik_tok_wikipidiea/models/post_content.dart';
import 'package:tik_tok_wikipidiea/config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tik_tok_wikipidiea/services/gemini_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tik_tok_wikipidiea/services/pdf_service.dart';

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
  String? userId;

  // Fallback images for different domains
  final Map<String, String> _domainImages = {
    'nature':
        'https://images.unsplash.com/photo-1501854140801-50d01698950b?ixlib=rb-1.2.1&auto=format&fit=crop&w=600&q=80',
    'education':
        'https://images.unsplash.com/photo-1503676260728-1c00da094a0b?ixlib=rb-1.2.1&auto=format&fit=crop&w=600&q=80',
    'entertainment':
        'https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3?ixlib=rb-1.2.1&auto=format&fit=crop&w=600&q=80',
    'technology':
        'https://images.unsplash.com/photo-1518770660439-4636190af475?ixlib=rb-1.2.1&auto=format&fit=crop&w=600&q=80',
    'science':
        'https://images.unsplash.com/photo-1507413245164-6160d8298b31?ixlib=rb-1.2.1&auto=format&fit=crop&w=600&q=80',
    'political':
        'https://images.unsplash.com/photo-1575320181282-9afab399332c?ixlib=rb-1.2.1&auto=format&fit=crop&w=600&q=80',
    'lifestyle':
        'https://images.unsplash.com/photo-1545205597-3d9d02c29597?ixlib=rb-1.2.1&auto=format&fit=crop&w=600&q=80',
    'social':
        'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?ixlib=rb-1.2.1&auto=format&fit=crop&w=600&q=80',
    'space':
        'https://images.unsplash.com/photo-1462331940025-496dfbfc7564?ixlib=rb-1.2.1&auto=format&fit=crop&w=600&q=80',
    'food':
        'https://images.unsplash.com/photo-1504674900247-0877df9cc836?ixlib=rb-1.2.1&auto=format&fit=crop&w=600&q=80',
  };

  // Default fallback image if domain isn't in the map
  final String _defaultImage =
      'https://images.unsplash.com/photo-1586339949916-3e9457bef6d3?q=80&w=1000';

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _loadArticleSections();
    _scrollController.addListener(_onScroll);

    // Clear old conversations when entering a new article
    GeminiService.clearOldConversations(widget.post.id);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('userId');
  }

  void _onScroll() {
    final showTitle = _scrollController.offset > _appBarTitleThreshold;
    if (showTitle != _showTitleInAppBar) {
      setState(() {
        _showTitleInAppBar = showTitle;
      });
    }
  }

  // Get fallback image for a domain
  String _getDomainImage(String domain) {
    String normalizedDomain = domain.toLowerCase();

    // Check for partial matches (e.g., "tech-news" should match "technology")
    for (var key in _domainImages.keys) {
      if (normalizedDomain.contains(key) || key.contains(normalizedDomain)) {
        return _domainImages[key]!;
      }
    }

    return _domainImages[normalizedDomain] ?? _defaultImage;
  }

  Future<void> _shareArticle() async {
    try {
      HapticFeedback.mediumImpact();

      // Extract a fun fact from the summary or first section content
      String funFact =
          widget.post.funFact.isNotEmpty
              ? widget.post.funFact
              : widget.post.summary.isNotEmpty
              ? widget.post.summary.split('.').first
              : 'No fun fact available.';

      // Construct the Wikipedia URL (assuming it follows standard format)
      final wikiTitle = widget.post.title.replaceAll(' ', '_');
      final wikipediaUrl = 'https://en.wikipedia.org/wiki/$wikiTitle';

      // App download link
      const appLink =
          'https://drive.google.com/drive/folders/19Haq7_FkI4E9L8QZbTTBMY3jIJ9xlQws?usp=drive_link';

      // Build share text
      final shareText = '''
📚 ${widget.post.title}

🤔 Fun Fact: $funFact

🔍 Read more: $wikipediaUrl

📱 Get WikiTok app: $appLink
''';

      await Share.share(shareText);
    } catch (error) {
      print('Error sharing article: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share article'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _downloadArticlePdf() async {
    try {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Generating PDF...'),
          duration: Duration(seconds: 2),
        ),
      );

      String result = await PdfService.generateArticlePdf(
        widget.post,
        sections,
        context: context,
        letUserChooseLocation: true,
      );

      // If PDF was saved successfully, extract the file path
      String? filePath;
      if (result.startsWith("PDF saved successfully to:")) {
        filePath =
            result.substring("PDF saved successfully to: ".length).trim();
      }

      // Show the result message with actions for the saved file
      if (filePath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF generated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 6),
            action: SnackBarAction(
              label: 'SHARE',
              textColor: Colors.white,
              onPressed: () {
                PdfService.shareFile(filePath!, context);
              },
            ),
          ),
        );

        // Also show a dialog with more information about the file location
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text('PDF Downloaded'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your article has been saved as a PDF.'),
                    SizedBox(height: 8),
                    Text('File saved to:'),
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(filePath!, style: TextStyle(fontSize: 12)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'You can find this file in your device\'s File Manager or Downloads folder.',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('CLOSE'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      PdfService.shareFile(filePath!, context);
                    },
                    child: Text('SHARE PDF'),
                  ),
                ],
              ),
        );
      } else {
        // Error case
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (error) {
      print('Error generating PDF: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate PDF'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadArticleSections() async {
    await Future.delayed(Duration(milliseconds: 500)); // Simulate loading

    // Convert post sections to ArticleSection objects
    final parsedSections =
        widget.post.sections.map((section) {
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
      // Add floating action buttons
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Download PDF button
          FloatingActionButton.small(
            heroTag: "downloadPdf",
            onPressed: _downloadArticlePdf,
            backgroundColor: theme.primaryColor.withOpacity(0.85),
            child: Icon(Icons.download_rounded, color: Colors.white),
            tooltip: 'Download PDF',
          ),
          SizedBox(height: 12),
          // Share button
          FloatingActionButton.small(
            heroTag: "shareArticle",
            onPressed: _shareArticle,
            backgroundColor: theme.primaryColor.withOpacity(0.85),
            child: Icon(Icons.share, color: Colors.white),
            tooltip: 'Share Article',
          ),
        ],
      ),
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
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Use the same image with fallback as in scroll screen
                    Hero(
                      tag: 'post_image_${widget.post.id}',
                      child: Image.network(
                        widget.post.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          // Use domain-specific fallback image
                          return Image.network(
                            _getDomainImage(widget.post.domain),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              // Ultimate fallback if even the fallback fails
                              return Container(
                                color:
                                    isDarkMode
                                        ? Colors.grey[800]
                                        : Colors.grey[300],
                                child: Center(
                                  child: Text(
                                    widget.post.domain.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          isDarkMode
                                              ? Colors.white70
                                              : Colors.black54,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
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
                    // Domain badge
                    Positioned(
                      bottom: 12,
                      left: 16,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.post.domain.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
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
              // Keep only the Gemini AI button
              actions: [
                // Gemini AI button
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
                      Icons.smart_toy_outlined,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    GeminiService.showGeminiAssistant(context, widget.post);
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
                      widget.post.title,
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
                              color:
                                  isDarkMode
                                      ? Colors.grey[700]
                                      : Colors.grey[300],
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                widget.post.domain
                                    .substring(0, 1)
                                    .toUpperCase(),
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
                                widget.post.domain.toUpperCase(),
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
                                "Published on ${widget.post.createdAt}",
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
