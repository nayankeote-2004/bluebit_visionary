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
import 'package:flutter_tts/flutter_tts.dart';

class ScrollScreen extends StatefulWidget {
  const ScrollScreen({super.key});

  @override
  _ScrollScreenState createState() => _ScrollScreenState();
}

class _ScrollScreenState extends State<ScrollScreen> {
  List<Post> posts = [];
  bool isLoading = true;
  String? userId;

  // Add TTS engine
  late FlutterTts flutterTts;
  bool isSpeaking = false;
  String? currentSpeakingPostId;

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

  // Fallback images for different domains
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
    _initTts();
    _loadUserId();
    _startTrackingTime(0);

    // Listen for auto-scroll setting changes
    _autoScrollService.addListener(_updateAutoScroll);

    // Initialize auto-scroll if enabled
    _updateAutoScroll();
  }

  // Initialize text-to-speech
  Future<void> _initTts() async {
    flutterTts = FlutterTts();

    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);

    // Add completion listener
    flutterTts.setCompletionHandler(() {
      setState(() {
        isSpeaking = false;
        currentSpeakingPostId = null;
      });
    });

    // Add error listener
    flutterTts.setErrorHandler((msg) {
      setState(() {
        isSpeaking = false;
        currentSpeakingPostId = null;
      });
      print("TTS Error: $msg");
    });
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

        // First, parse all posts from the API response
        final List<Post> fetchedPosts =
            articlesJson.map((json) => Post.fromJson(json)).toList();

        // Then sort them to avoid consecutive posts from same domain
        final sortedPosts = _sortPostsByDomain(fetchedPosts);

        setState(() {
          posts = sortedPosts;
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load articles');
      }
    } catch (error) {
      print('Error fetching articles: $error');
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

  // This method sorts posts to avoid consecutive posts from the same domain
  List<Post> _sortPostsByDomain(List<Post> unsortedPosts) {
    if (unsortedPosts.isEmpty) return [];

    // First shuffle the posts for initial randomization
    final shuffledPosts = List<Post>.from(unsortedPosts)..shuffle(Random());

    // Group posts by domain
    final Map<String, List<Post>> postsByDomain = {};
    for (var post in shuffledPosts) {
      if (!postsByDomain.containsKey(post.domain)) {
        postsByDomain[post.domain] = [];
      }
      postsByDomain[post.domain]!.add(post);
    }

    // Create result list by taking one post from each domain in round-robin fashion
    final List<Post> result = [];
    bool added = true;

    while (added) {
      added = false;
      postsByDomain.forEach((domain, domainPosts) {
        if (domainPosts.isNotEmpty) {
          final lastDomain = result.isNotEmpty ? result.last.domain : '';

          // Only add if this domain is different from the last added post
          if (domain != lastDomain) {
            result.add(domainPosts.removeAt(0));
            added = true;
          }
        }
      });

      // If we couldn't add anything in the last pass but still have posts,
      // we need to handle the case where only one domain is left
      if (!added) {
        for (var domain in postsByDomain.keys) {
          if (postsByDomain[domain]!.isNotEmpty) {
            result.add(postsByDomain[domain]!.removeAt(0));
            added = true;
            break;
          }
        }
      }
    }

    return result;
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

  // Updated to change UI first, then send request
  Future<void> _toggleLike(Post post) async {
    // Update UI immediately
    setState(() {
      post.isLiked = !post.isLiked;
    });

    // Then send request to backend
    try {
      final baseUrl = Config.baseUrl;
      final response = await http.post(
        Uri.parse(
          '$baseUrl/domains/${post.domain}/articles/${post.id}/like/$userId',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        // Revert if the request fails
        setState(() {
          post.isLiked = !post.isLiked;
        });
        throw Exception('Failed to toggle like');
      }
    } catch (error) {
      print('Error toggling like: $error');
      // Already reverted the state above if needed
    }
  }

  // Replace _shufflePosts with refresh method
  Future<void> _refreshPosts() async {
    setState(() {
      isLoading = true;
    });
    await _fetchRecommendedArticles();
  }

  // Add this function to the _ScrollScreenState class
  Future<void> _addComment(Post post, String commentText) async {
    try {
      final baseUrl = Config.baseUrl;
      final response = await http.post(
        Uri.parse(
          '$baseUrl/domains/${post.domain}/articles/${post.id}/comment',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId, 'comment': commentText}),
      );

      if (response.statusCode == 200) {
        setState(() {
          post.comments.add(commentText);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Comment added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to add comment');
      }
    } catch (error) {
      print('Error adding comment: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add comment'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Update the _showComments method to fix the overflow issue
  void _showComments(Post post) {
    final TextEditingController commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Flexible wrapper for the comments list to allow it to resize
                  Expanded(child: CommentsSheet(post: post)),

                  // Fixed-height comment input area
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      border: Border(
                        top: BorderSide(
                          color: Theme.of(context).dividerColor,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentController,
                            decoration: InputDecoration(
                              hintText: 'Add a comment...',
                              isDense: true, // Reduces the overall height
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            maxLines: 1, // Restrict to single line
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.send),
                          onPressed: () async {
                            if (commentController.text.isNotEmpty) {
                              await _addComment(post, commentController.text);
                              commentController.clear();
                              Navigator.pop(context);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // Updated method to handle text-to-speech functionality without snackbar
  Future<void> _readArticle(Post post) async {
    HapticFeedback.mediumImpact(); // Add haptic feedback

    // If already speaking the same post, stop it
    if (isSpeaking && currentSpeakingPostId == post.id.toString()) {
      await flutterTts.stop();
      setState(() {
        isSpeaking = false;
        currentSpeakingPostId = null;
      });
      return;
    }

    // If speaking a different post, stop that first
    if (isSpeaking) {
      await flutterTts.stop();
      setState(() {
        isSpeaking = false;
        currentSpeakingPostId = null;
      });
    }

    // Prepare text to speak
    String textToSpeak = "Title: ${post.title}. ${post.summary}";

    // Start speaking without showing a snackbar
    await flutterTts.speak(textToSpeak);
    setState(() {
      isSpeaking = true;
      currentSpeakingPostId = post.id.toString();
    });
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
            // Stop any ongoing TTS when changing pages
            if (isSpeaking) {
              flutterTts.stop();
              setState(() {
                isSpeaking = false;
                currentSpeakingPostId = null;
              });
            }

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
    // Check if this is the post currently being read aloud
    bool isCurrentlyReading =
        isSpeaking && currentSpeakingPostId == post.id.toString();

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
                // Image with domain-specific fallback
                Container(
                  height: MediaQuery.of(context).size.height * 0.35,
                  width: double.infinity,
                  child: Hero(
                    tag: 'post_image_${post.id}',
                    child: Image.network(
                      post.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        // Use domain-specific fallback image
                        return Image.network(
                          _getDomainImage(post.domain),
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
                                  post.domain.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 24,
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

                // Domain badge and reading time
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

                      // Reading time indicator
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
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

                    // Enhanced navigation with custom transition
                    Navigator.of(context)
                        .push(
                          PageRouteBuilder(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    DetailScreen(post: post),
                            transitionDuration: Duration(milliseconds: 400),
                            transitionsBuilder: (
                              context,
                              animation,
                              secondaryAnimation,
                              child,
                            ) {
                              var begin = Offset(1.0, 0.0);
                              var end = Offset.zero;
                              var curve = Curves.easeOutCubic;
                              var tween = Tween(
                                begin: begin,
                                end: end,
                              ).chain(CurveTween(curve: curve));
                              var offsetAnimation = animation.drive(tween);

                              return SlideTransition(
                                position: offsetAnimation,
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              );
                            },
                          ),
                        )
                        .then((_) {
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

                      // Interactive tips row
                      Container(
                        margin: EdgeInsets.only(top: 8, bottom: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Updated listen button showing active state
                            InkWell(
                              onTap: () => _readArticle(post),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isCurrentlyReading
                                          ? Colors.red.withOpacity(0.3)
                                          : theme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        isCurrentlyReading
                                            ? Colors.red
                                            : theme.primaryColor.withOpacity(
                                              0.3,
                                            ),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Show different icon based on playing state
                                    Icon(
                                      isCurrentlyReading
                                          ? Icons.volume_up
                                          : Icons.headphones,
                                      size: 14,
                                      color:
                                          isCurrentlyReading
                                              ? Colors.red
                                              : theme.primaryColor,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      isCurrentlyReading ? "Stop" : "Listen",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            isCurrentlyReading
                                                ? Colors.red
                                                : theme.primaryColor,
                                        fontWeight:
                                            isCurrentlyReading
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Swipe hint
                            Container(
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
                                    "Read more",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      Divider(),

                      // Action buttons - removed share button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Fixed like button
                          _buildActionButton(
                            icon:
                                post.isLiked
                                    ? Icons
                                        .favorite // Filled heart when liked
                                    : Icons
                                        .favorite_border, // Outline heart when not liked
                            color:
                                post.isLiked
                                    ? Colors.red
                                    : null, // Red when liked
                            onPressed: () => _toggleLike(post),
                          ),
                          _buildActionButton(
                            icon: Icons.comment_outlined,
                            onPressed: () => _showComments(post),
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

    // Stop any ongoing TTS and dispose resources
    flutterTts.stop();

    // Clean up auto-scroll timer and listeners
    _autoScrollTimer?.cancel();
    _autoScrollService.removeListener(_updateAutoScroll);

    super.dispose();
  }
}
