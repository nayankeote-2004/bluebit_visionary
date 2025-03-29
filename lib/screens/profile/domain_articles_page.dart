import 'package:flutter/material.dart';
import 'package:tik_tok_wikipidiea/config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart'; // For haptic feedback
import 'dart:async'; // For Timer

class DomainArticlesPage extends StatefulWidget {
  final String domain;
  final Function onArticleRead;

  const DomainArticlesPage({
    Key? key,
    required this.domain,
    required this.onArticleRead,
  }) : super(key: key);

  @override
  _DomainArticlesPageState createState() => _DomainArticlesPageState();
}

class _DomainArticlesPageState extends State<DomainArticlesPage> {
  List<dynamic> articles = [];
  bool isLoading = true;
  Set<String> readArticleIds = {};

  // Add pagination variables
  int _currentPage = 1;
  final int _postsPerPage = 5;
  bool _hasMorePosts = true;
  bool _isLoadingMore = false;
  bool _loadMoreError = false;
  String _errorMessage = '';

  // Scroll controller for detecting when to load more
  final ScrollController _scrollController = ScrollController();

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
    _scrollController.addListener(_scrollListener);
    _fetchArticles();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  // Scroll listener for lazy loading
  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      if (!_isLoadingMore && _hasMorePosts && !_loadMoreError) {
        _loadMoreArticles();
      }
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

  Future<void> _fetchArticles() async {
    setState(() {
      if (_currentPage == 1) {
        isLoading = true;
      } else {
        _isLoadingMore = true;
      }
      _loadMoreError = false;
    });

    try {
      final baseUrl = Config.baseUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/domains/${widget.domain}/articles?limit=10'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final fetchedArticles = data ?? [];

        setState(() {
          if (_currentPage == 1) {
            // Replace existing articles for first page
            articles = fetchedArticles;
          } else {
            // Append for subsequent pages
            articles.addAll(fetchedArticles);
          }

          // Check if we've reached the end
          _hasMorePosts = fetchedArticles.length >= _postsPerPage;
          _currentPage++;
          isLoading = false;
          _isLoadingMore = false;
        });
      } else {
        throw Exception('Failed to load articles');
      }
    } catch (e) {
      print('Error fetching articles: $e');
      setState(() {
        isLoading = false;
        _isLoadingMore = false;
        _loadMoreError = true;
        _errorMessage = 'Failed to load articles. Please try again.';
      });
    }
  }

  Future<void> _loadMoreArticles() async {
    if (!_isLoadingMore && _hasMorePosts) {
      await _fetchArticles();
    }
  }

  Future<void> _refreshArticles() async {
    setState(() {
      _currentPage = 1;
      _hasMorePosts = true;
      _loadMoreError = false;
    });
    await _fetchArticles();
  }

  void _markAsRead(String articleId) {
    if (!readArticleIds.contains(articleId)) {
      setState(() {
        readArticleIds.add(articleId);
      });
      widget.onArticleRead();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.domain} Articles'),
        actions: [
          // Progress indicator
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${readArticleIds.length}/${articles.length}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: readArticleIds.length >= 10 ? Colors.green : null,
                ),
              ),
            ),
          ),
          IconButton(icon: Icon(Icons.refresh), onPressed: _refreshArticles),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshArticles,
        child:
            isLoading && _currentPage == 1
                ? _buildLoadingIndicator(theme)
                : articles.isEmpty
                ? _buildEmptyState(theme)
                : ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.all(16),
                  itemCount: articles.length + (_hasMorePosts ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == articles.length) {
                      return _buildLoadMoreIndicator();
                    }
                    return _buildEnhancedArticleCard(
                      articles[index],
                      theme,
                      isDarkMode,
                    );
                  },
                ),
      ),
    );
  }

  Widget _buildEnhancedArticleCard(
    dynamic article,
    ThemeData theme,
    bool isDarkMode,
  ) {
    final bool isRead = readArticleIds.contains(article['_id']);
    final String articleId = article['_id'] ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:
                isDarkMode
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section with overlay gradient
            Stack(
              children: [
                // Article image with hero animation
                Hero(
                  tag: 'article_image_$articleId',
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    child: Image.network(
                      article['imageUrl'] ?? _getDomainImage(widget.domain),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.network(
                          _getDomainImage(widget.domain),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color:
                                  isDarkMode
                                      ? Colors.grey[800]
                                      : Colors.grey[300],
                              child: Center(
                                child: Text(
                                  widget.domain.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 22,
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
                ),

                // Gradient overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 80,
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
                ),

                // Domain badge and read status
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Domain badge
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.domain.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),

                      // Read status indicator
                      if (isRead)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'READ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // Content section
            InkWell(
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => ArticleDetailPage(
                          article: article,
                          onRead: () {
                            _markAsRead(articleId);
                          },
                        ),
                  ),
                );
              },
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      article['title'] ?? 'Untitled Article',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),

                    // Description
                    Text(
                      article['description'] ??
                          article['content']?.substring(
                            0,
                            math.min(100, article['content']?.length ?? 0),
                          ) ??
                          'No description available',
                      style: theme.textTheme.bodyMedium,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 16),

                    // Bottom row with metadata and action button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Date and author info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (article['publishedAt'] != null)
                                Text(
                                  _formatDate(article['publishedAt']),
                                  style: theme.textTheme.bodySmall,
                                ),
                              if (article['author'] != null)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person_outline,
                                      size: 14,
                                      color: theme.textTheme.bodySmall?.color,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      article['author'],
                                      style: theme.textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),

                        // Read button
                        OutlinedButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => ArticleDetailPage(
                                      article: article,
                                      onRead: () {
                                        _markAsRead(articleId);
                                      },
                                    ),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                isRead ? Colors.green : theme.primaryColor,
                            side: BorderSide(
                              color: isRead ? Colors.green : theme.primaryColor,
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            isRead ? 'Read Again' : 'Read Now',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
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
      ),
    );
  }

  Widget _buildLoadingIndicator(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
          ),
          SizedBox(height: 16),
          Text("Loading domain articles...", style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, size: 64, color: theme.dividerColor),
          SizedBox(height: 16),
          Text(
            'No articles found for this domain',
            style: theme.textTheme.titleMedium,
          ),
          SizedBox(height: 16),
          ElevatedButton(onPressed: _refreshArticles, child: Text('Refresh')),
        ],
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    if (_loadMoreError) {
      return Center(
        child: Column(
          children: [
            Text(_errorMessage, style: TextStyle(color: Colors.red)),
            SizedBox(height: 8),
            ElevatedButton(onPressed: _loadMoreArticles, child: Text('Retry')),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }
}

// Article Detail Page implementation
class ArticleDetailPage extends StatefulWidget {
  final dynamic article;
  final Function onRead;

  const ArticleDetailPage({
    Key? key,
    required this.article,
    required this.onRead,
  }) : super(key: key);

  @override
  _ArticleDetailPageState createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> {
  bool hasMarkedAsRead = false;
  Timer? _readTimer;

  @override
  void initState() {
    super.initState();
    // Change from 5 to 15 seconds of viewing before marking as read
    _readTimer = Timer(Duration(seconds: 15), () {
      _markAsRead();
    });
  }

  @override
  void dispose() {
    _readTimer?.cancel();
    super.dispose();
  }

  void _markAsRead() {
    if (!hasMarkedAsRead) {
      setState(() {
        hasMarkedAsRead = true;
      });
      widget.onRead();

      // Show a brief confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Article marked as read'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(label: 'Dismiss', onPressed: () {}),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final article = widget.article;

    return Scaffold(
      appBar: AppBar(
        title: Text('Article Details'),
        actions: [
          IconButton(
            icon: Icon(
              hasMarkedAsRead ? Icons.check_circle : Icons.check_circle_outline,
              color: hasMarkedAsRead ? Colors.green : null,
            ),
            tooltip: 'Mark as read',
            onPressed: _markAsRead,
          ),
          // Add share button
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () {
              HapticFeedback.mediumImpact();
              // Show a simple feedback since we're keeping existing backend logic
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Share feature would open here'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Article image with hero animation
            Hero(
              tag: 'article_image_${article['_id']}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  article['imageUrl'] ??
                      _getDomainImage(article['domain'] ?? ''),
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 220,
                      color: theme.primaryColor.withOpacity(0.1),
                      child: Icon(
                        Icons.image_not_supported,
                        size: 64,
                        color: theme.disabledColor,
                      ),
                    );
                  },
                ),
              ),
            ),

            SizedBox(height: 16),

            // Domain and date row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Domain chip
                Chip(
                  label: Text(
                    article['domain'] ?? 'Unknown',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: theme.primaryColor,
                  visualDensity: VisualDensity.compact,
                ),

                // Date
                if (article['publishedAt'] != null)
                  Text(
                    _formatDate(article['publishedAt']),
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),

            SizedBox(height: 16),

            // Title
            Text(
              article['title'] ?? 'Untitled Article',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),

            SizedBox(height: 8),

            // Author and read status row
            Row(
              children: [
                if (article['author'] != null) ...[
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'By ${article['author']}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  SizedBox(width: 16),
                ],

                // Reading status indicator with timer cue
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        hasMarkedAsRead
                            ? Colors.green.withOpacity(0.1)
                            : theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        hasMarkedAsRead
                            ? Icons.check_circle
                            : Icons.access_time,
                        color:
                            hasMarkedAsRead ? Colors.green : theme.primaryColor,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        hasMarkedAsRead ? 'Read' : '15s to mark as read',
                        style: TextStyle(
                          color:
                              hasMarkedAsRead
                                  ? Colors.green
                                  : theme.primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 24),

            // Content divider
            Container(
              width: 50,
              height: 4,
              decoration: BoxDecoration(
                color: theme.primaryColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            SizedBox(height: 24),

            // Article content
            Text(
              article['content'] ?? 'No content available',
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.6,
                fontSize: 16,
              ),
            ),

            SizedBox(height: 32),

            // Mark as read button - updated design
            if (!hasMarkedAsRead)
              Center(
                child: ElevatedButton.icon(
                  onPressed: _markAsRead,
                  icon: Icon(Icons.check_circle),
                  label: Text('Mark as Read Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 3,
                  ),
                ),
              ),

            // Share and bookmark buttons row
            if (hasMarkedAsRead)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Article bookmarked')),
                        );
                      },
                      icon: Icon(Icons.bookmark_outline),
                      label: Text('Save'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.primaryColor,
                      ),
                    ),
                    SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Share dialog would open here'),
                          ),
                        );
                      },
                      icon: Icon(Icons.share),
                      label: Text('Share'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // Helper method to get domain images
  String _getDomainImage(String domain) {
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

    final String _defaultImage =
        'https://images.unsplash.com/photo-1586339949916-3e9457bef6d3?q=80&w=1000';

    String normalizedDomain = domain.toLowerCase();

    // Check for partial matches
    for (var key in _domainImages.keys) {
      if (normalizedDomain.contains(key) || key.contains(normalizedDomain)) {
        return _domainImages[key]!;
      }
    }

    return _domainImages[normalizedDomain] ?? _defaultImage;
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }
}
