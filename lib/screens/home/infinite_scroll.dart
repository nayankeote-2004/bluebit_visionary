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

  // Keys for SharedPreferences storage
  final String _readArticlesKey = 'read_articles_today';
  final String _readDateKey = 'read_articles_date';
  final String _readCountKey = 'read_articles_count';

  // Set to store IDs of articles read today (to avoid counting the same one twice)
  Set<String> _readArticleIds = {};
  int _todayReadCount = 0;
  String _currentDate = '';

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

  // Add this to the class variables
  bool _isBertLoading = false;
  List<Post> _bertRecommendedPosts = [];
  bool _bertFailed = false;

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadUserData();
    _startTrackingTime(0);
    _loadReadArticlesData();

    // Listen for auto-scroll setting changes
    _autoScrollService.addListener(_updateAutoScroll);

    // Initialize auto-scroll if enabled
    _updateAutoScroll();
  }

  // Initialize article read tracking data
  Future<void> _loadReadArticlesData() async {
    final prefs = await SharedPreferences.getInstance();

    // Get the current date in yyyy-MM-dd format
    final now = DateTime.now();
    final today =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    _currentDate = today;

    // Check if we need to reset the count (new day)
    final storedDate = prefs.getString(_readDateKey) ?? '';

    if (storedDate != today) {
      // New day, reset everything
      await prefs.setString(_readDateKey, today);
      await prefs.setInt(_readCountKey, 0);
      await prefs.setStringList(_readArticlesKey, []);

      _todayReadCount = 0;
      _readArticleIds = {};
    } else {
      // Same day, load existing data
      _todayReadCount = prefs.getInt(_readCountKey) ?? 0;
      _readArticleIds = (prefs.getStringList(_readArticlesKey) ?? []).toSet();
    }
  }

  // Save read article data to SharedPreferences
  Future<void> _saveReadArticlesData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_readCountKey, _todayReadCount);
    await prefs.setStringList(_readArticlesKey, _readArticleIds.toList());

    // Also check if date needs updating
    final now = DateTime.now();
    final today =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    if (_currentDate != today) {
      _currentDate = today;
      await prefs.setString(_readDateKey, today);

      // Reset counters for the new day
      _todayReadCount = 0;
      _readArticleIds = {};
      await prefs.setInt(_readCountKey, 0);
      await prefs.setStringList(_readArticlesKey, []);
    }
  }

  // Mark an article as read and increment today's count
  Future<void> _markArticleAsRead(Post post) async {
    if (!_readArticleIds.contains(post.id.toString())) {
      setState(() {
        _readArticleIds.add(post.id.toString());
        _todayReadCount++;
      });
      await _saveReadArticlesData();
    }
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

  Future<void> _loadUserData() async {
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
        Uri.parse('$baseUrl/user/$userId/standard-recommendations'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> articlesJson =
            json.decode(response.body)['standardRecommendedArticles'];

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

  // Updated method to check for articles read more than 7 seconds
  void _recordReadingTime() async {
    if (_pageViewStartTime != null && _currentIndex < posts.length) {
      final duration = DateTime.now().difference(_pageViewStartTime!);

      // Add to existing time if already viewed this post
      if (_readingTimes.containsKey(_currentIndex)) {
        _readingTimes[_currentIndex] = _readingTimes[_currentIndex]! + duration;
      } else {
        _readingTimes[_currentIndex] = duration;
      }

      // Check if the post has been read for more than 7 seconds
      if (_readingTimes[_currentIndex]!.inSeconds > 7) {
        final post = posts[_currentIndex];
        await _markArticleAsRead(post);
      }

      print(
        '====================Post $_currentIndex reading time: ${_readingTimes[_currentIndex]!.inSeconds} seconds',
      );
    }

    // Check if we need to reset counters (day changed)
    final now = DateTime.now();
    final today =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    if (_currentDate != today) {
      await _loadReadArticlesData(); // This will reset counters if needed
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
    await _fetchPosts();
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
        body: json.encode({
          'userId':
              userId, // Make sure this matches the API expectation (user_id not userId)
          'comment': commentText, // Use text instead of comment
        }),
      );

      if (response.statusCode == 200) {
        // Close the current comments sheet
        Navigator.pop(context);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Comment added successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Reopen comments to refresh the list
        Future.delayed(Duration(milliseconds: 300), () {
          _showComments(post);
        });
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

  // Replace your existing _showComments method with this updated version:

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
                  // Drag handle
                  Container(
                    margin: EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Dynamic comments widget
                  Expanded(child: CommentsSheet(post: post)),

                  // Comment input area
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
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            maxLines: 1,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.send),
                          color: Theme.of(context).primaryColor,
                          onPressed: () async {
                            if (commentController.text.isNotEmpty) {
                              await _addComment(post, commentController.text);
                              commentController.clear();
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
                // Add double tap detector with key to separate from other gestures
                onDoubleTap: () {
                  HapticFeedback.mediumImpact();
                  _showFunFactDialog(post, context);
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

  // Method to show fun fact dialog with enhanced design
  void _showFunFactDialog(Post post, BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Generate a fun fact based on post content
    String funFact = _generateFunFact(post);

    // Play a subtle sound effect for the "boom"
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.mediumImpact();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Fun Fact",
      pageBuilder: (context, animation1, animation2) => Container(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        // Create boom animation with a bounce effect
        var curve = CurvedAnimation(
          parent: animation,
          curve: Curves.elasticOut,
        );

        return ScaleTransition(
          scale: Tween<double>(begin: 0.3, end: 1.0).animate(curve),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(animation),
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors:
                        isDarkMode
                            ? [Color(0xFF1E2A3A), Color(0xFF152238)]
                            : [Color(0xFFF0F8FF), Color(0xFFE1EBEE)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: isDarkMode ? Colors.black38 : Colors.black12,
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: Offset(0, 5),
                    ),
                  ],
                  border: Border.all(
                    color: theme.primaryColor.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with icon
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.lightbulb,
                            color: theme.primaryColor,
                            size: 30,
                          ),
                        ),
                        SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Did You Know?',
                                style: TextStyle(
                                  color:
                                      isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                'Fun Fact from ${post.domain.toUpperCase()}',
                                style: TextStyle(
                                  color:
                                      isDarkMode
                                          ? Colors.white70
                                          : Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 20),

                    // Divider with decorative elements
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.primaryColor.withOpacity(0.1),
                                  theme.primaryColor,
                                  theme.primaryColor.withOpacity(0.1),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: theme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.primaryColor,
                                  theme.primaryColor.withOpacity(0.1),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 20),

                    // Fact content
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color:
                            isDarkMode
                                ? Colors.black.withOpacity(0.2)
                                : Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDarkMode ? Colors.white24 : Colors.black12,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        funFact,
                        style: TextStyle(
                          fontSize: 16,
                          color: isDarkMode ? Colors.white : Colors.black87,
                          height: 1.4,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),

                    SizedBox(height: 24),

                    // Action button
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 12,
                        ),
                        elevation: 5,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Awesome!',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionDuration: Duration(milliseconds: 600),
    );
  }

  // Helper to generate a fun fact from post content
  String _generateFunFact(Post post) {
    // Try to extract an interesting fact from the article
    if (post.summary.length > 50) {
      // Look for interesting sentences in the summary
      List<String> sentences = post.summary.split('. ');

      // Try to find a sentence with interesting keywords
      for (String sentence in sentences) {
        if (sentence.contains("interesting") ||
            sentence.contains("fact") ||
            sentence.contains("discovered") ||
            sentence.contains("surprising") ||
            sentence.contains("research") ||
            sentence.contains("scientist")) {
          return sentence + ".";
        }
      }

      // If we have sections, try the first section
      if (post.sections.isNotEmpty && post.sections.first.content.length > 50) {
        sentences = post.sections.first.content.split('. ');
        for (String sentence in sentences) {
          if (sentence.length > 40 && sentence.length < 200) {
            return sentence + ".";
          }
        }
      }

      // If no interesting sentence found, return a random sentence from the summary
      if (sentences.length > 1) {
        return sentences[Random().nextInt(sentences.length - 1)] + ".";
      }
      return sentences.first + ".";
    }

    // Fallback to a generic fun fact based on the title
    return "Did you know? The topic \"${post.title}\" has been researched extensively and continues to fascinate experts in the field of ${post.domain}.";
  }

  // Update the fetchPosts method to handle sequential API calls
  Future<void> _fetchPosts() async {
    setState(() {
      isLoading = true;
      _isBertLoading = true;
    });

    try {
      // Get user ID from shared preferences
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getString('userId');

      if (userId == null) {
        setState(() {
          isLoading = false;
          _isBertLoading = false;
        });
        return;
      }

      // First fetch standard recommendations
      final standardResponse = await http.get(
        Uri.parse('${Config.baseUrl}/user/$userId/standard-recommendations'),
      );

      if (standardResponse.statusCode == 200) {
        final data = json.decode(standardResponse.body);
        final standardArticles = data['standardRecommendedArticles'] as List;

        setState(() {
          posts =
              standardArticles
                  .map<Post>((article) => Post.fromJson(article))
                  .toList();
          isLoading = false;
        });
        print("Before bert : ${posts.length}");
        // After standard recommendations load, fetch BERT recommendations in background
        await _fetchBertRecommendations();

        print("after bert : ${posts.length}");
      } else {
        setState(() {
          isLoading = false;
          _isBertLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching posts: $e');
      setState(() {
        isLoading = false;
        _isBertLoading = false;
      });
    }
  }

  // New method to fetch BERT recommendations separately
  Future<void> _fetchBertRecommendations() async {
    if (userId == null) return;

    try {
      final bertResponse = await http.get(
        Uri.parse('${Config.baseUrl}/user/$userId/bert-recommendations'),
      );

      if (bertResponse.statusCode == 200) {
        final data = json.decode(bertResponse.body);
        final bertArticles = data['bertRecommendedArticles'] as List;

        setState(() {
          _bertRecommendedPosts =
              bertArticles
                  .map<Post>((article) => Post.fromJson(article))
                  .toList();
          _isBertLoading = false;

          // Now merge BERT recommendations with standard posts
          // Add BERT posts at the beginning or intersperse them
          if (_bertRecommendedPosts.isNotEmpty) {
            // Create a new list with BERT recommendations first
            List<Post> allPosts = [..._bertRecommendedPosts];

            // Add standard posts that aren't duplicates of BERT posts
            for (Post post in posts) {
              if (!_bertRecommendedPosts.any(
                (bertPost) => bertPost.id == post.id,
              )) {
                allPosts.add(post);
              }
            }

            posts = allPosts;
          }
        });
      } else {
        setState(() {
          _isBertLoading = false;
          _bertFailed = true;
        });
      }
    } catch (e) {
      print('Error fetching BERT recommendations: $e');
      setState(() {
        _isBertLoading = false;
        _bertFailed = true;
      });
    }
  }
}
