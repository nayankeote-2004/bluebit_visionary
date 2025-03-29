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
import 'package:google_mobile_ads/google_mobile_ads.dart'; // Added Google Mobile Ads
import 'package:connectivity_plus/connectivity_plus.dart'; // Add this import for connectivity check
import 'package:tik_tok_wikipidiea/services/connectivity_service.dart';
import 'package:tik_tok_wikipidiea/services/gemini_explanation_service.dart'; // Added Gemini Explanation Service

class ScrollScreen extends StatefulWidget {
  const ScrollScreen({super.key});

  @override
  _ScrollScreenState createState() => _ScrollScreenState();
}

class _ScrollScreenState extends State<ScrollScreen>
    with WidgetsBindingObserver {
  List<Post> posts = [];
  bool isLoading = true;
  String? userId;

  // Add pagination variables
  int _currentPage = 1;
  final int _postsPerPage = 10;
  bool _hasMorePosts = true;
  bool _isLoadingMore = false;

  // Ad-related variables
  final Map<int, BannerAd?> _bannerAds = {};
  final Map<int, bool> _isAdReady = {};

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

  // Add these variables to _ScrollScreenState class
  bool _loadMoreError = false;
  String _errorMessage = '';

  // Add these variables for offline support
  final String _cachedPostsKey = 'cached_posts';
  final int _maxCachedPosts = 100; // Maximum posts to cache

  // Add this variable to _ScrollScreenState class
  OverlayEntry? _overlayEntry;
  Timer? _overlayTimer;

  // Add connectivity service
  final ConnectivityService _connectivityService = ConnectivityService();
  StreamSubscription<bool>? _connectivitySubscription;
  bool _isOffline = false;

  // Add this to the _ScrollScreenState class
  // Previous offline status to detect changes
  bool _previousOfflineStatus = false;

  @override
  void initState() {
    super.initState();

    // Initialize previous status
    _previousOfflineStatus = _connectivityService.isOffline;

    // Listen to connectivity changes with improved logic
    _connectivitySubscription = _connectivityService.connectivityStream.listen((
      isOffline,
    ) {
      print('Connectivity changed: ${isOffline ? "Offline" : "Online"}');

      if (mounted) {
        // Check if state actually changed
        if (_previousOfflineStatus != isOffline) {
          print(
            'Status changed from ${_previousOfflineStatus ? "Offline" : "Online"} to ${isOffline ? "Offline" : "Online"}',
          );

          // Update UI state immediately
          setState(() {
            _isOffline = isOffline;
          });

          // Show notification based on new status
          _showConnectivityNotification(
            !isOffline,
          ); // true = online, false = offline

          // Handle additional actions based on new connectivity state
          if (!isOffline) {
            // We just went online
            Future.microtask(() => _refreshPosts());
          } else {
            // We just went offline
            if (posts.isEmpty) {
              Future.microtask(() => _loadCachedPosts());
            }
          }

          // Update previous status
          _previousOfflineStatus = isOffline;
        }
      }
    });

    _initTts();
    _checkConnectivityAndLoadData();
    _startTrackingTime(0);
    _loadReadArticlesData();

    // Initialize Mobile Ads SDK
    MobileAds.instance.initialize();

    // Listen for auto-scroll setting changes
    _autoScrollService.addListener(_updateAutoScroll);

    // Initialize auto-scroll if enabled
    _updateAutoScroll();

    // Add lifecycle observer
    WidgetsBinding.instance.addObserver(this);
  }

  // Add this lifecycle method to ensure connectivity status is checked when returning to the page
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check connectivity status whenever the page is shown (including when returning from another screen)
    _refreshConnectivityStatus();
  }

  // Add this to the _ScrollScreenState class
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Check connectivity when the app comes back to the foreground
    if (state == AppLifecycleState.resumed) {
      _refreshConnectivityStatus();
    }
  }

  // Update the dispose method
  @override
  void dispose() {
    // Cancel connectivity subscription
    _connectivitySubscription?.cancel();

    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    // Record the final reading time when widget is disposed
    _recordReadingTime();

    // Stop any ongoing TTS and dispose resources
    flutterTts.stop();

    // Clean up auto-scroll timer and listeners
    _autoScrollTimer?.cancel();
    _autoScrollService.removeListener(_updateAutoScroll);

    // Dispose all banner ads
    _bannerAds.forEach((key, ad) => ad?.dispose());

    // Make sure to cancel any active overlay when disposing
    _removeOverlay();

    super.dispose();
  }

  // New method to refresh connectivity status at any time
  Future<void> _refreshConnectivityStatus() async {
    await _connectivityService.checkConnectivity();
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
      // Reset pagination when initially loading
      _currentPage = 1;
      _hasMorePosts = true;
      await _fetchPosts();
    }
  }

  // Future<void> _fetchRecommendedArticles() async {
  //   if (!_hasMorePosts) return;

  //   try {
  //     setState(() {
  //       if (_currentPage == 1) {
  //         isLoading = true;
  //       } else {
  //         _isLoadingMore = true;
  //       }
  //       _loadMoreError = false;
  //     });

  //     final baseUrl = Config.baseUrl;
  //     final response = await http.get(
  //       Uri.parse('$baseUrl/user/$userId/standard-recommendations'),
  //     );

  //     if (response.statusCode == 200) {
  //       final List<dynamic> articlesJson =
  //           json.decode(response.body)['standardRecommendedArticles'];

  //       // First, parse all posts from the API response
  //       final List<Post> fetchedPosts =
  //           articlesJson.map((json) => Post.fromJson(json)).toList();

  //       // Then sort them to avoid consecutive posts from same domain
  //       final sortedPosts = _sortPostsByDomain(fetchedPosts);

  //       setState(() {
  //         if (_currentPage == 1) {
  //           // For the first page, replace the list
  //           posts = sortedPosts;
  //         } else {
  //           // For subsequent pages, append to the list
  //           posts.addAll(sortedPosts);
  //         }

  //         // Check if we've reached the end
  //         _hasMorePosts = sortedPosts.length >= _postsPerPage;
  //         _currentPage++;
  //         isLoading = false;
  //         _isLoadingMore = false;
  //       });
  //     } else {
  //       throw Exception('Server returned status code ${response.statusCode}');
  //     }
  //   } catch (error) {
  //     print('===========================Error fetching articles: $error');
  //     setState(() {
  //       isLoading = false;
  //       _isLoadingMore = false;
  //       _loadMoreError = true;

  //       // Set appropriate error message based on error type
  //       if (error.toString().contains('SocketException') ||
  //           error.toString().contains('Connection refused')) {
  //         _errorMessage = 'Network error. Please check your connection.';
  //       } else if (error.toString().contains('timed out')) {
  //         _errorMessage = 'Request timed out. Please try again.';
  //       } else if (error.toString().contains('status code')) {
  //         _errorMessage = 'Server error. Please try again later.';
  //       } else {
  //         _errorMessage = 'Failed to load articles. Please try again.';
  //       }
  //     });
  //   }
  // }

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

  // Updated to check connectivity before toggling like
  Future<void> _toggleLike(Post post) async {
    // Force a connectivity check before proceeding
    await _refreshConnectivityStatus();

    // Now check if we're offline
    if (_connectivityService.isOffline) {
      // Show a subtle tooltip instead of a full notification
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.signal_wifi_off, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Liking is available when online'),
            ],
          ),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: EdgeInsets.all(8),
        ),
      );
      return;
    }

    // Rest of your existing implementation...
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
    // Check connectivity before refreshing
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      // Update local state instead of trying to modify the service directly
      setState(() {
        _isOffline = true;
      });

      // Show offline notification
      _showConnectivityNotification(false);

      // Try to load from cache
      await _loadCachedPosts();
      return;
    }

    _currentPage = 1;
    _hasMorePosts = true;
    _bertRecommendedPosts = []; // Reset BERT recommendations
    _bertFailed = false; // Reset any BERT failures

    // Dispose existing ads
    _bannerAds.forEach((key, ad) => ad?.dispose());
    _bannerAds.clear();
    _isAdReady.clear();

    setState(() {
      isLoading = true;
      posts = []; // Explicitly clear posts array
      _isOffline = false; // We're online if we're refreshing
    });

    // Clear image cache and memory
    imageCache.clear();
    imageCache.clearLiveImages();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    // Add logging for debugging
    print('Refreshing posts - cleared data');

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
    // Force a connectivity check before proceeding
    _refreshConnectivityStatus().then((_) {
      // Now check if we're offline
      if (_connectivityService.isOffline) {
        // Show a subtle tooltip
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.signal_wifi_off, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('Comments are available when online'),
              ],
            ),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.black87,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: EdgeInsets.all(8),
          ),
        );
        return;
      }

      // Existing implementation...
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
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
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
    });
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

  // Method to load a banner ad
  void _loadAd(int adIndex) {
    _isAdReady[adIndex] = false;

    final BannerAd bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // Test ad unit ID
      request: const AdRequest(),
      size: AdSize.mediumRectangle, // 300x250 - matches card dimensions
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _bannerAds[adIndex] = ad as BannerAd;
            _isAdReady[adIndex] = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          print('Ad failed to load: $error');
          ad.dispose();
        },
      ),
    );

    bannerAd.load();
  }

  // Method to build ad widget
  Widget _buildAdCard(int adIndex) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final skeletonBaseColor =
        isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;
    final skeletonHighlightColor =
        isDarkMode ? Colors.grey[700]! : Colors.grey[200]!;

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
        child:
            _isAdReady[adIndex] == true && _bannerAds[adIndex] != null
                ? Center(
                  child: SizedBox(
                    width: _bannerAds[adIndex]!.size.width.toDouble(),
                    height: _bannerAds[adIndex]!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAds[adIndex]!),
                  ),
                )
                : Column(
                  children: [
                    // Image placeholder
                    Container(
                      height: MediaQuery.of(context).size.height * 0.35,
                      width: double.infinity,
                      color: skeletonBaseColor,
                    ),

                    // Content skeleton
                    Container(
                      padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title placeholder
                          Container(
                            height: 24,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: skeletonBaseColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),

                          SizedBox(height: 8),

                          // Shorter title line placeholder
                          Container(
                            height: 24,
                            width: MediaQuery.of(context).size.width * 0.7,
                            decoration: BoxDecoration(
                              color: skeletonBaseColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),

                          SizedBox(height: 16),

                          // Summary placeholder lines
                          for (int i = 0; i < 3; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Container(
                                height: 16,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color:
                                      i % 2 == 0
                                          ? skeletonBaseColor
                                          : skeletonHighlightColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  // Update the build method to handle loading state
  @override
  Widget build(BuildContext context) {
    // Check connectivity status at the start of each build
    // Use Future.microtask to avoid setState during build
    // Future.microtask(() => _refreshConnectivityStatus());

    // Get theme brightness to adapt UI accordingly
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    if (isLoading && _currentPage == 1) {
      return Scaffold(
        appBar: AppBar(title: Text("TikTok Wikipedia")),
        body: ListView.builder(
          padding: EdgeInsets.symmetric(vertical: 8),
          itemCount: 5, // Show multiple skeleton cards
          itemBuilder: (context, index) {
            return _buildSkeletonCard(context);
          },
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
        // Show auto-scroll indicator when enabled and offline indicator if offline
        actions: [
          // Offline indicator
          if (_connectivityService.isOffline)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Icon(Icons.signal_wifi_off, color: Colors.orange),
            ),
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
        child: NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scrollInfo) {
            // Check if we're near the end of the list to load more posts
            if (scrollInfo is ScrollEndNotification) {
              if (_pageController.page != null &&
                  _pageController.page! >= posts.length - 3 &&
                  !_isLoadingMore &&
                  _hasMorePosts) {
                _loadMorePosts();
              }
            }
            return false;
          },
          child: PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            physics: const BouncingScrollPhysics(),
            itemCount:
                _hasMorePosts
                    ? posts.length +
                        (_loadMoreError ? 1 : (_isLoadingMore ? 3 : 1))
                    : posts.length,
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

              // Check if we need to load more posts
              if (index >= posts.length - 3 &&
                  !_isLoadingMore &&
                  _hasMorePosts &&
                  !_loadMoreError) {
                _loadMorePosts();
              }

              // Only track time for valid indices
              if (index < posts.length) {
                _startTrackingTime(index);
              }
            },
            itemBuilder: (context, index) {
              // Determine total items count including ads
              int totalItemsCount = posts.length + (posts.length ~/ 5);

              // Skip showing anything beyond our data
              if (index >= totalItemsCount) {
                // Show error message or loading indicator
                if (_loadMoreError) {
                  return _buildErrorCard(context);
                }
                return _buildSkeletonCard(context);
              }

              // Check if this is an ad position (after every 5 posts)
              // Ad positions are 5, 11, 17, etc.
              if ((index + 1) % 6 == 0) {
                final adIndex = (index + 1) ~/ 6 - 1;
                // Load ad if not already loaded
                if (!_isAdReady.containsKey(adIndex)) {
                  _loadAd(adIndex);
                }
                return _buildAdCard(adIndex);
              }

              // This is a regular post position
              // Calculate the actual post index by subtracting the number of ads before this position
              final postIndex = index - (index ~/ 6);
              if (postIndex < posts.length) {
                return _buildEnhancedCard(
                  posts[postIndex],
                  context,
                  isDarkMode,
                  theme,
                );
              }

              // Safety fallback - should not reach here
              return _buildSkeletonCard(context);
            },
          ),
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

            // Content section - Add SelectableText for the article content
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

                      // Summary with selectable text
                      Expanded(
                        child: SelectableText(
                          post.summary,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                            fontSize: 16,
                          ),
                          onSelectionChanged: (selection, cause) {
                            if (selection.isCollapsed)
                              return; // No text selected

                            // When user lifts finger after selecting text
                            if (cause == SelectionChangedCause.longPress) {
                              final selectedText = post.summary.substring(
                                selection.start,
                                selection.end,
                              );

                              if (selectedText.length > 3) {
                                // Only for selections with meaningful length
                                GeminiExplanationService.showExplanation(
                                  context,
                                  selectedText,
                                );
                              }
                            }
                          },
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
                                    : Colors.red[300], // Red when liked
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

  // Update the _buildActionButton method to improve disabled state visual feedback
  Widget _buildActionButton({
    required IconData icon,
    Color? color,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // If offline, use a very muted color to better indicate disabled state
    final effectiveColor =
        _connectivityService.isOffline
            ? (isDarkMode ? Colors.grey[700] : Colors.grey[400])
            : (color ?? theme.iconTheme.color);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: EdgeInsets.all(12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 24, color: effectiveColor),
              // Show a small indicator when offline
              if (_connectivityService.isOffline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                      border: Border.all(
                        color: isDarkMode ? Colors.grey[800]! : Colors.white,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
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

  // Update the fetchPosts method to handle lazy loading
  Future<void> _fetchPosts() async {
    // Check connectivity before fetching
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      // Update local offline state
      setState(() {
        _isOffline = true;
        isLoading = false;
        _isLoadingMore = false;

        // If we already have posts (from cache), don't show error
        if (posts.isEmpty) {
          _loadMoreError = true;
          _errorMessage = 'You are offline. Please check your connection.';
        }
      });

      // Try to load from cache if we don't have posts yet
      if (posts.isEmpty) {
        await _loadCachedPosts();
      }
      return;
    }

    setState(() {
      if (_currentPage == 1) {
        isLoading = true;
      } else {
        _isLoadingMore = true;
      }
      _isBertLoading = true;
    });

    try {
      // Get user ID from shared preferences
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getString('userId');

      if (userId == null) {
        setState(() {
          isLoading = false;
          _isLoadingMore = false;
          _isBertLoading = false;
        });
        return;
      }

      print('Fetching standard recommendations for page: $_currentPage');
      final standardResponse = await http.get(
        Uri.parse('${Config.baseUrl}/user/$userId/standard-recommendations'),
        headers: {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
      );

      if (standardResponse.statusCode == 200) {
        final data = json.decode(standardResponse.body);
        final standardArticles = data['standardRecommendedArticles'] as List;
        print('!@#%^&*()${standardArticles}');
        print('Received ${standardArticles.length} standard articles');

        // Parse the fetched posts
        final fetchedPosts =
            standardArticles.map<Post>((article) {
              return Post.fromJson(
                article is Map
                    ? article as Map<String, dynamic>
                    : json.decode(article.toString()),
              );
            }).toList();

        setState(() {
          if (_currentPage == 1) {
            // For first page, replace the list completely
            posts = _sortPostsByDomain(fetchedPosts);
            print('Reset posts list with ${posts.length} new items');
          } else {
            // For subsequent pages, append to the list
            posts.addAll(fetchedPosts);
            print('Added ${fetchedPosts.length} more items to posts list');
          }

          // Check if we've reached the end
          _hasMorePosts = fetchedPosts.length >= _postsPerPage;
          _currentPage++;
          isLoading = false;
          _isLoadingMore = false;
          _isOffline = false; // We're online if we successfully fetched
        });

        // Cache the posts after fetching
        _saveCachedPosts();

        // Only fetch BERT recommendations for the first page and if we haven't failed before
        if (_currentPage == 2 && !_bertFailed) {
          await _fetchPosts();
        }
      } else {
        print(
          'Standard recommendations API returned status: ${standardResponse.statusCode}',
        );
        setState(() {
          isLoading = false;
          _isLoadingMore = false;
          _isBertLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching posts: $e');
      setState(() {
        isLoading = false;
        _isLoadingMore = false;
        _isBertLoading = false;

        // If we can't fetch and have no posts, try to load from cache
        if (posts.isEmpty) {
          _loadCachedPosts();
        }
      });
    }
  }

  // New method to fetch BERT recommendations separately
  Future<void> _fetchBertRecommendations() async {
    if (userId == null) return;

    try {
      print('Fetching BERT recommendations');
      final bertResponse = await http.get(
        Uri.parse('${Config.baseUrl}/user/$userId/bert-recommendations'),
        headers: {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
      );

      if (bertResponse.statusCode == 200) {
        final data = json.decode(bertResponse.body);
        final bertArticles = data['bertRecommendedArticles'] as List;
        print('Received ${bertArticles.length} BERT articles');

        final bertPosts =
            bertArticles.map<Post>((article) {
              return Post.fromJson(
                article is Map
                    ? article as Map<String, dynamic>
                    : json.decode(article.toString()),
              );
            }).toList();

        // Create a set of existing post IDs for faster lookup
        final existingIds = posts.map((p) => p.id).toSet();

        // Filter out any BERT posts that are already in the standard list
        final uniqueBertPosts =
            bertPosts.where((p) => !existingIds.contains(p.id)).toList();

        print('Found ${uniqueBertPosts.length} unique BERT posts');

        setState(() {
          _bertRecommendedPosts = uniqueBertPosts;
          _isBertLoading = false;

          if (_bertRecommendedPosts.isNotEmpty) {
            // Create a new merged list
            List<Post> allPosts = [];

            // Interleave BERT posts with standard posts for better variety
            // Add 1 BERT post for every 2 standard posts if available
            int bertIndex = 0;
            final List<Post> standardPosts = List.from(posts);

            while (standardPosts.isNotEmpty ||
                bertIndex < _bertRecommendedPosts.length) {
              // Add up to 2 standard posts
              if (standardPosts.isNotEmpty) {
                allPosts.add(standardPosts.removeAt(0));
              }
              if (standardPosts.isNotEmpty) {
                allPosts.add(standardPosts.removeAt(0));
              }

              // Add 1 BERT post if available
              if (bertIndex < _bertRecommendedPosts.length) {
                allPosts.add(_bertRecommendedPosts[bertIndex++]);
              }
            }

            print(
              'Created new merged list with ${allPosts.length} total posts',
            );
            posts = allPosts;
          }
        });
      } else {
        print('BERT API returned status: ${bertResponse.statusCode}');
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

  // Method to load more posts as the user scrolls
  Future<void> _loadMorePosts() async {
    if (!_isLoadingMore && _hasMorePosts) {
      await _fetchPosts();
    }
  }

  Widget _buildSkeletonCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final skeletonBaseColor =
        isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;
    final skeletonHighlightColor =
        isDarkMode ? Colors.grey[700]! : Colors.grey[200]!;

    return Container(
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
            // Image skeleton
            Container(
              height: MediaQuery.of(context).size.height * 0.35,
              width: double.infinity,
              color: skeletonBaseColor,
            ),

            // Content skeleton
            Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title skeleton
                  Container(
                    height: 28,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: skeletonBaseColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    height: 28,
                    width: MediaQuery.of(context).size.width * 0.6,
                    decoration: BoxDecoration(
                      color: skeletonBaseColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),

                  SizedBox(height: 16),

                  // Summary skeleton - multiple lines
                  for (var i = 0; i < 5; i++) ...[
                    Container(
                      height: 16,
                      width: double.infinity,
                      margin: EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color:
                            i % 2 == 0
                                ? skeletonBaseColor
                                : skeletonHighlightColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],

                  SizedBox(height: 24),

                  // Actions skeleton
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (var i = 0; i < 3; i++)
                        Container(
                          height: 32,
                          width: 32,
                          decoration: BoxDecoration(
                            color: skeletonBaseColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add this method to _ScrollScreenState class
  Widget _buildErrorCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_off,
                    size: 64,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                  SizedBox(height: 16),
                  Text(
                    _errorMessage,
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _refreshPosts,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('Try Again'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Check connectivity and load appropriate data
  Future<void> _checkConnectivityAndLoadData() async {
    await _connectivityService.checkConnectivity();

    if (!_connectivityService.isOffline) {
      _isOffline = false;
      await _loadUserData();
    } else {
      _isOffline = true;
      await _loadCachedPosts();
    }
  }

  // Update connection status when it changes
  Future<void> _updateConnectionStatus(List<ConnectivityResult> results) async {
    final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
    final bool isConnected = result != ConnectivityResult.none;

    // If we're going from offline to online, refresh data
    if (_isOffline && isConnected) {
      setState(() {
        _isOffline = false;
      });

      // Show online notification
      _showConnectivityNotification(true);

      await _refreshPosts();
    }
    // If we're going from online to offline, ensure we have cached posts
    else if (!_isOffline && !isConnected) {
      setState(() {
        _isOffline = true;
      });

      // If we don't have posts loaded, try to load from cache
      if (posts.isEmpty) {
        await _loadCachedPosts();
      }

      // Show offline notification
      _showConnectivityNotification(false);
    }
  }

  // Save posts to cache
  Future<void> _saveCachedPosts() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Limit the number of posts to cache
      final postsToCache =
          posts.length > _maxCachedPosts
              ? posts.sublist(0, _maxCachedPosts)
              : posts;

      // Convert posts to JSON
      final List<String> postsJsonList =
          postsToCache.map((post) => json.encode(post.toJson())).toList();

      // Save to SharedPreferences
      await prefs.setStringList(_cachedPostsKey, postsJsonList);
      print('Saved ${postsToCache.length} posts to cache');
    } catch (e) {
      print('Error saving posts to cache: $e');
    }
  }

  // Load posts from cache
  Future<void> _loadCachedPosts() async {
    try {
      setState(() {
        isLoading = true;
      });

      final prefs = await SharedPreferences.getInstance();
      final cachedPostsJson = prefs.getStringList(_cachedPostsKey);

      if (cachedPostsJson != null && cachedPostsJson.isNotEmpty) {
        // Parse JSON strings back to Post objects
        final List<Post> cachedPosts = [];

        for (String postJson in cachedPostsJson) {
          try {
            final postMap = json.decode(postJson) as Map<String, dynamic>;
            final post = Post.fromJson(postMap);
            cachedPosts.add(post);
          } catch (e) {
            print('Error parsing cached post: $e');
            // Continue with the next post if one fails
          }
        }

        setState(() {
          posts = cachedPosts;
          isLoading = false;
        });
        print('Loaded ${posts.length} posts from cache');
      } else {
        setState(() {
          isLoading = false;
          _loadMoreError = true;
          _errorMessage =
              'No cached content available. Please connect to the internet.';
        });
      }
    } catch (e) {
      print('Error loading posts from cache: $e');
      setState(() {
        isLoading = false;
        _loadMoreError = true;
        _errorMessage = 'Error loading cached content: ${e.toString()}';
      });
    }
  }

  // New method for showing sweet action-specific notifications
  void _showActionNotification({
    required String emoji,
    required String message,
    required String actionName,
  }) {
    // Remove any existing notification first
    _removeOverlay();

    // Create the new overlay with a sweet message
    _overlayEntry = OverlayEntry(
      builder: (context) {
        final theme = Theme.of(context);
        final isDarkMode = theme.brightness == Brightness.dark;

        // Sweet purple/pink colors for offline action notifications
        final Color backgroundColor =
            isDarkMode
                ? Color(0xFF2D2438) // Dark mode: deep purple
                : Color(0xFFF9F0FF); // Light mode: light lavender

        final Color textColor =
            isDarkMode
                ? Color(0xFFF4E3FF) // Light lavender text for dark mode
                : Color(0xFF6A3EA1); // Purple text for light mode

        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: -100.0, end: 0.0),
                curve: Curves.elasticOut,
                duration: Duration(milliseconds: 800),
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, value),
                    child: child,
                  );
                },
                child: GestureDetector(
                  onTap: _removeOverlay,
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color:
                            isDarkMode
                                ? Color(0xFF8454D8).withOpacity(0.5)
                                : Color(0xFFD6B9FF),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Bouncing emoji with heart effect for likes
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.5, end: 1.0),
                          curve: Curves.elasticOut,
                          duration: Duration(milliseconds: 1200),
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Small sparkle effect
                                  if (actionName == 'like')
                                    ...List.generate(3, (i) {
                                      return Positioned(
                                        top: -4 + (i * 3),
                                        right: -4 + (i * 2),
                                        child: Icon(
                                          Icons.star,
                                          color: Color(0xFFFFD700),
                                          size: 10,
                                        ),
                                      );
                                    }),
                                  Text(emoji, style: TextStyle(fontSize: 28)),
                                ],
                              ),
                            );
                          },
                        ),
                        SizedBox(width: 12),

                        // Message with fade in animation
                        Expanded(
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.0, end: 1.0),
                            curve: Curves.easeIn,
                            duration: Duration(milliseconds: 500),
                            builder: (context, value, child) {
                              return Opacity(opacity: value, child: child);
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message,
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "Connect to continue ${actionName == 'like' ? 'liking' : 'commenting'} 💫",
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Close icon
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                          icon: Icon(
                            Icons.close,
                            color: textColor.withOpacity(0.7),
                            size: 20,
                          ),
                          onPressed: _removeOverlay,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    // Add to the overlay
    Overlay.of(context).insert(_overlayEntry!);

    // Auto-hide after a few seconds
    _overlayTimer = Timer(Duration(seconds: 4), _removeOverlay);

    // Add haptic feedback for a more engaging experience
    HapticFeedback.mediumImpact();
  }

  // Fix the _showConnectivityNotification method to ensure it's correctly implemented
  void _showConnectivityNotification(bool isOnline) {
    // Remove any existing notification first
    _removeOverlay();

    // Add debug log
    print(
      'Showing connectivity notification: ${isOnline ? "Online" : "Offline"}',
    );

    // Use post-frame callback to ensure we're in a safe rendering cycle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Create the new overlay
      _overlayEntry = OverlayEntry(
        builder: (context) {
          final screenWidth = MediaQuery.of(context).size.width;
          final theme = Theme.of(context);
          final isDarkMode = theme.brightness == Brightness.dark;

          // Define colors and styles based on connection status
          final Color backgroundColor =
              isOnline
                  ? (isDarkMode
                      ? Color(0xFF1E422C)
                      : Color(0xFFE3F5E9)) // Green shade
                  : (isDarkMode
                      ? Color(0xFF42271E)
                      : Color(0xFFFFF3E0)); // Orange/amber shade

          final Color textColor =
              isDarkMode
                  ? Colors.white
                  : (isOnline ? Color(0xFF0E6245) : Color(0xFFC75B39));

          final String emoji = isOnline ? '🌐' : '📶';
          final String message =
              isOnline
                  ? "Yay! You're back online! Ready to explore more articles..."
                  : "Oops! You're offline now. Don't worry, we've saved some articles for you ✨";

          return Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Material(
                color: Colors.transparent,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: -100.0, end: 0.0),
                  curve: Curves.elasticOut,
                  duration: Duration(milliseconds: 800),
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, value),
                      child: child,
                    );
                  },
                  child: GestureDetector(
                    onTap: _removeOverlay,
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color:
                              isOnline
                                  ? Colors.green.withOpacity(0.5)
                                  : Colors.orange.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Bouncing emoji
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.5, end: 1.0),
                            curve: Curves.elasticOut,
                            duration: Duration(milliseconds: 1200),
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: Text(
                                  emoji,
                                  style: TextStyle(fontSize: 24),
                                ),
                              );
                            },
                          ),
                          SizedBox(width: 12),

                          // Message with fade in animation
                          Expanded(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.0, end: 1.0),
                              curve: Curves.easeIn,
                              duration: Duration(milliseconds: 500),
                              builder: (context, value, child) {
                                return Opacity(opacity: value, child: child);
                              },
                              child: Text(
                                message,
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),

                          // Close icon
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                            icon: Icon(
                              Icons.close,
                              color: textColor.withOpacity(0.7),
                              size: 20,
                            ),
                            onPressed: _removeOverlay,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );

      // Add to the overlay
      try {
        Overlay.of(context).insert(_overlayEntry!);

        // Auto-hide after a few seconds
        _overlayTimer = Timer(Duration(seconds: 4), _removeOverlay);
      } catch (e) {
        print('Error showing connectivity notification: $e');
        _overlayEntry = null;
      }
    });
  }

  // Make sure _removeOverlay is properly defined
  void _removeOverlay() {
    _overlayTimer?.cancel();
    _overlayTimer = null;

    if (_overlayEntry != null) {
      try {
        _overlayEntry!.remove();
      } catch (e) {
        print('Error removing overlay: $e');
      }
      _overlayEntry = null;
    }
  }
}
