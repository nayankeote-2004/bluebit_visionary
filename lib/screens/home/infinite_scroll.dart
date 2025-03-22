import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tik_tok_wikipidiea/config.dart';
import 'package:tik_tok_wikipidiea/models/comments_of_post.dart';
import 'package:tik_tok_wikipidiea/services/autoscroll.dart';
import 'package:tik_tok_wikipidiea/models/post_content.dart';
import 'dart:math';
import 'dart:async';
import 'package:tik_tok_wikipidiea/screens/home/post_details.dart';
import 'package:tik_tok_wikipidiea/services/bookmark_services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ScrollScreen extends StatefulWidget {
  const ScrollScreen({super.key});

  @override
  _ScrollScreenState createState() => _ScrollScreenState();
}

class _ScrollScreenState extends State<ScrollScreen> {
  List<Post> posts = [];
  bool isLoading = true;
  String? userId;

  PageController _pageController = PageController();
  bool _isSwipingRight = false;

  // Auto-scroll settings
  final AutoScrollService _autoScrollService = AutoScrollService();
  Timer? _autoScrollTimer;

  // Bookmark service
  final BookmarkService _bookmarkService = BookmarkService();

  // Track reading time
  int _currentIndex = 0;
  DateTime? _pageViewStartTime;
  Map<int, Duration> _readingTimes = {};

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _startTrackingTime(0);

    // Listen for auto-scroll setting changes
    _autoScrollService.addListener(_updateAutoScroll);

    // Initialize auto-scroll if enabled
    _updateAutoScroll();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('userId');
    if (userId != null) {
      await _fetchRecommendedArticles();
    }
  }

  Future<void> _fetchRecommendedArticles() async {
    try {
      final baseUrl = Config.baseUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/user/$userId/recommended-articles'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> articlesJson =
            json.decode(response.body)['recommendedArticles'];
        setState(() {
          posts = articlesJson.map((json) => Post.fromJson(json)).toList();
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load articles');
      }
    } catch (error) {
      print('Error fetching articles: $error');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _updateAutoScroll() {
    // Cancel any existing timer
    _autoScrollTimer?.cancel();

    // If auto-scroll is enabled, start the timer
    if (_autoScrollService.enabled) {
      _startAutoScroll();
    }
  }

  void _startAutoScroll() {
    // Create a periodic timer with the configured interval
    _autoScrollTimer = Timer.periodic(
      Duration(seconds: _autoScrollService.intervalSeconds),
      (_) {
        // Only scroll if we have a valid page controller and we're not at the end
        if (_pageController.hasClients && _currentIndex < posts.length - 1) {
          // Record reading time for current page
          _recordReadingTime();

          // Animate to the next page
          _pageController.nextPage(
            duration: Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      },
    );
  }

  void _startTrackingTime(int index) {
    _pageViewStartTime = DateTime.now();
    _currentIndex = index;
  }

  void _recordReadingTime() {
    if (_pageViewStartTime != null) {
      final duration = DateTime.now().difference(_pageViewStartTime!);

      // Add to existing time if already viewed this post
      if (_readingTimes.containsKey(_currentIndex)) {
        _readingTimes[_currentIndex] = _readingTimes[_currentIndex]! + duration;
      } else {
        _readingTimes[_currentIndex] = duration;
      }

      print(
        '============================Post $_currentIndex reading time: ${_readingTimes[_currentIndex]!.inSeconds} seconds',
      );
    }
  }

  // Replace _shufflePosts with refresh method
  Future<void> _refreshPosts() async {
    setState(() {
      isLoading = true;
    });
    await _fetchRecommendedArticles();
  }

  // Show comments bottom sheet
  void _showComments(Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: CommentsSheet(post: post),
          ),
    );
  }

  // Update the build method to handle loading state
  @override
  Widget build(BuildContext context) {
    // Get theme brightness to adapt UI accordingly
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text("TikTok Wikipedia")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
              ),
              SizedBox(height: 16),
              Text(
                "Loading your personalized content...",
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: Theme.of(context).appBarTheme.elevation,
        title: Text(
          "TikTok Wikipedia",
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
        centerTitle: true,
        // Show auto-scroll indicator when enabled
        actions: [
          if (_autoScrollService.enabled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Icon(Icons.av_timer, size: 18),
                  SizedBox(width: 4),
                  Text(
                    "${_autoScrollService.intervalSeconds}s",
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPosts,
        child: PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          physics: const BouncingScrollPhysics(), // Smoother scrolling
          itemCount: posts.length,
          onPageChanged: (index) {
            // Record time for previous page and start timer for new page
            _recordReadingTime();
            _startTrackingTime(index);
          },
          itemBuilder: (context, index) {
            final post = posts[index];
            return _buildEnhancedCard(post, context, isDarkMode, theme);
          },
        ),
      ),
    );
  }

  Widget _buildEnhancedCard(
    Post post,
    BuildContext context,
    bool isDarkMode,
    ThemeData theme,
  ) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
          children: [
            // Image section with overlay gradient
            Stack(
              children: [
                // Image
                Container(
                  height: MediaQuery.of(context).size.height * 0.35,
                  width: double.infinity,
                  child: Image.network(
                    post.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                        child: Center(
                          child: Icon(
                            Icons.broken_image,
                            size: 50,
                            color: theme.iconTheme.color,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Gradient overlay at bottom of image
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 70,
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

                // Reading time and domain
                Positioned(
                  bottom: 12,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Domain badge
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          post.domain.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),

                      
                    ],
                  ),
                ),
              ],
            ),

            // Content section
            Expanded(
              child: GestureDetector(
                onHorizontalDragUpdate: (details) {
                  if (details.primaryDelta! > 10) {
                    _isSwipingRight = true;
                  }
                },
                onHorizontalDragEnd: (details) {
                  if (_isSwipingRight) {
                    // Record reading time before navigation
                    _recordReadingTime();

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailScreen(post: post),
                      ),
                    ).then((_) {
                      // Resume tracking when returning from details page
                      _startTrackingTime(_currentIndex);
                      // Reset swipe state to allow repeated swipes
                      _isSwipingRight = false;
                    });
                  } else {
                    _isSwipingRight = false;
                  }
                },
                child: Container(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title with enhanced styling
                      Text(
                        post.title,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),

                      SizedBox(height: 16),

                      // Summary with limited text and smaller font
                      Expanded(
                        child: Text(
                          post.summary,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 15,
                            height: 1.5,
                            color:
                                isDarkMode
                                    ? Colors.grey[300]
                                    : Colors.grey[800],
                          ),
                          maxLines: 7,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Swipe hint
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          margin: EdgeInsets.only(top: 8, bottom: 4),
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isDarkMode
                                    ? Colors.grey[800]
                                    : Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.swipe_right_alt,
                                size: 14,
                                color: theme.primaryColor,
                              ),
                              SizedBox(width: 4),
                              Text(
                                "Swipe for more",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      Divider(),

                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildActionButton(
                            icon:
                                post.isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                            color: Colors.red,
                            onPressed: () {
                              setState(() {
                                post.isLiked = !post.isLiked;
                              });
                            },
                          ),
                          _buildActionButton(
                            icon: Icons.comment_outlined,
                            onPressed: () {
                              _showComments(post);
                            },
                          ),
                          _buildActionButton(
                            icon:
                                _bookmarkService.isBookmarked(post)
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                            onPressed: () {
                              setState(() {
                                _bookmarkService.toggleBookmark(post);
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _bookmarkService.isBookmarked(post)
                                        ? "Article bookmarked"
                                        : "Bookmark removed",
                                  ),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
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
    Color? color,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: EdgeInsets.all(12),
          child: Icon(icon, size: 24, color: color ?? theme.iconTheme.color),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Record the final reading time when widget is disposed
    _recordReadingTime();

    // Clean up auto-scroll timer and listeners
    _autoScrollTimer?.cancel();
    _autoScrollService.removeListener(_updateAutoScroll);

    super.dispose();
  }
}
