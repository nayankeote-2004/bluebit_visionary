import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tik_tok_wikipidiea/services/autoscroll.dart';
import 'package:tik_tok_wikipidiea/models/post_content.dart';
import 'dart:math';
import 'dart:async';
import 'package:tik_tok_wikipidiea/screens/home/post_details.dart';
import 'package:tik_tok_wikipidiea/services/bookmark_services.dart';

class ScrollScreen extends StatefulWidget {
  const ScrollScreen({super.key});

  @override
  _ScrollScreenState createState() => _ScrollScreenState();
}

class _ScrollScreenState extends State<ScrollScreen> {
  List<Post> posts = [
    Post(
      image: 'https://source.unsplash.com/800x1200/',
      description: "A beautiful sunset over the hills.",
      source: "Nature Today",
    ),
    Post(
      image: 'https://source.unsplash.com/800x1200/?city',
      description: "Night view of a busy city street.",
      source: "Urban Lens",
    ),
    Post(
      image: 'https://source.unsplash.com/800x1200/?ocean',
      description: "Waves crashing against the rocks.",
      source: "Marine Explorer",
    ),
    Post(
      image: 'https://source.unsplash.com/800x1200/?forest',
      description: "A dense green forest with mist.",
      source: "Wilderness Magazine",
    ),
    Post(
      image: 'https://source.unsplash.com/800x1200/?mountain',
      description: "A majestic snow-capped mountain.",
      source: "Mountain Weekly",
    ),
  ];

  PageController _pageController = PageController();
  bool _isSwipingRight = false;

  // Auto-scroll settings
  final AutoScrollService _autoScrollService = AutoScrollService();
  Timer? _autoScrollTimer;

  // Track reading time
  int _currentIndex = 0;
  DateTime? _pageViewStartTime;
  Map<int, Duration> _readingTimes = {};

  // Bookmark service
  final BookmarkService _bookmarkService = BookmarkService();

  @override
  void initState() {
    super.initState();
    _startTrackingTime(0);

    // Listen for auto-scroll setting changes
    _autoScrollService.addListener(_updateAutoScroll);

    // Initialize auto-scroll if enabled
    _updateAutoScroll();
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

  void _shufflePosts() {
    setState(() {
      posts.shuffle(Random());
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get theme brightness to adapt UI accordingly
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
        onRefresh: () async {
          _shufflePosts();
        },
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
                      posts[index].image,
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
                                child: Text(
                                  posts[index].description,
                                  style: Theme.of(context).textTheme.bodyLarge,
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
                                      "SOURCE: ${posts[index].source}",
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
                                          posts[index].isLiked
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color: Colors.red,
                                          size: 22,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            posts[index].isLiked =
                                                !posts[index].isLiked;
                                          });
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.share,
                                          size: 22,
                                          color:
                                              Theme.of(context).iconTheme.color,
                                        ),
                                        onPressed: () {
                                          Clipboard.setData(
                                            ClipboardData(
                                              text: posts[index].description,
                                            ),
                                          );
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                "Description copied! Share it anywhere.",
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          _bookmarkService.isBookmarked(
                                                posts[index],
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
                                              posts[index],
                                            );
                                          });

                                          // Show appropriate message
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                _bookmarkService.isBookmarked(
                                                      posts[index],
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
