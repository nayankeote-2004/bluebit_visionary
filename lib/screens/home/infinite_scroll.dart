import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tik_tok_wikipidiea/models/comments_of_post.dart';
import 'package:tik_tok_wikipidiea/services/autoscroll.dart';
import 'package:tik_tok_wikipidiea/models/post_content.dart';
import 'dart:math';
import 'dart:async';
import 'package:tik_tok_wikipidiea/screens/home/post_details.dart';
import 'package:tik_tok_wikipidiea/services/bookmark_services.dart';
import 'package:shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:tik_tok_wikipidiea/config/config.dart';

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
        final List<dynamic> articlesJson = json.decode(response.body);
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

    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text("TikTok Wikipedia")),
        body: Center(child: CircularProgressIndicator()),
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
          itemCount: posts.length,
          onPageChanged: (index) {
            // Record time for previous page and start timer for new page
            _recordReadingTime();
            _startTrackingTime(index);
          },
          itemBuilder: (context, index) {
            final post = posts[index];
            return Card(
              margin: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              elevation: 4,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  // Top part - Image (reduced height like Inshorts app)
                  Container(
                    height: MediaQuery.of(context).size.height * 0.35,
                    width: double.infinity,
                    child: Image.network(
                      post.imageUrl, // Updated to use imageUrl
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color:
                              isDarkMode ? Colors.grey[800] : Colors.grey[300],
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
                  ),

                  // Bottom part - Content with swipe gesture detector
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
                              builder:
                                  (context) => DetailScreen(post: posts[index]),
                            ),
                          ).then((_) {
                            // Resume tracking when returning from details page
                            _startTrackingTime(index);
                            // Reset swipe state to allow repeated swipes
                            _isSwipingRight = false;
                          });
                        } else {
                          _isSwipingRight = false;
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.all(16),
                        color: Theme.of(context).cardColor,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Description text
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      post.title,
                                      style: Theme.of(context).textTheme.titleLarge,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      post.summary,
                                      style: Theme.of(context).textTheme.bodyLarge,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Source and actions row
                            Container(
                              padding: EdgeInsets.only(top: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Source name - styled like Inshorts
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 6,
                                      horizontal: 0,
                                    ),
                                    child: Text(
                                      "Domain: ${post.domain.toUpperCase()}",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            isDarkMode
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                                  Divider(
                                    color: Theme.of(context).dividerColor,
                                  ),
                                  // Action buttons
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          post.isLiked
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color: Colors.red,
                                          size: 22,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            post.isLiked =
                                                !post.isLiked;
                                          
                                          });
                                        },
                                      ),
                                      // CHANGED: Replaced share button with comments button
                                      IconButton(
                                        icon: Icon(
                                          Icons.comment_outlined,
                                          size: 22,
                                          color:
                                              Theme.of(context).iconTheme.color,
                                        ),
                                        onPressed: () {
                                          _showComments(posts[index]);
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          _bookmarkService.isBookmarked(
                                                post,
                                              )
                                              ? Icons.bookmark
                                              : Icons.bookmark_border,
                                          size: 22,
                                          color:
                                              Theme.of(context).iconTheme.color,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            // Toggle bookmark status using the service
                                            _bookmarkService.toggleBookmark(
                                              post,
                                            );
                                          });

                                          // Show appropriate message
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                _bookmarkService.isBookmarked(
                                                      post,
                                                    )
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
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
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
