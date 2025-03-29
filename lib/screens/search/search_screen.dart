import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tik_tok_wikipidiea/config.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../../models/search_models.dart';
import 'dart:async';
import '../../models/trending_models.dart';
import '../../models/google_trending_models.dart';

enum TrendingSource { app, global }

class Search_screen extends StatefulWidget {
  const Search_screen({Key? key}) : super(key: key);

  @override
  State<Search_screen> createState() => _Search_screenState();
}

class _Search_screenState extends State<Search_screen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  bool _showClearButton = false;
  bool _isLoading = false;
  String? _errorMessage;
  List<SearchResult> _searchResults = [];
  Timer? _debounce;
  late AnimationController _animationController;
  late Animation<double> _animation;

  // Mock data for suggestions and trending topics
  final List<String> _recentSearches = [
    'Computer',
    'Animation',
    'State management',
  ];

  List<TrendingArticle> _trendingArticles = [];
  bool _isTrendingLoading = true;

  TrendingSource _selectedTrendingSource = TrendingSource.app;
  List<GoogleTrendingTopic> _globalTrendingTopics = [];
  bool _isGlobalTrendingLoading = true;
  final ScrollController _trendingScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _searchController.addListener(() {
      setState(() {
        _showClearButton = _searchController.text.isNotEmpty;
      });

      // Debounce the search to avoid too many API calls
      if (_searchController.text.isNotEmpty) {
        if (_debounce?.isActive ?? false) _debounce!.cancel();
        _debounce = Timer(const Duration(milliseconds: 500), () {
          _performSearch(_searchController.text);
        });
      } else {
        setState(() {
          _searchResults = [];
          if (_animationController.isCompleted) _animationController.reverse();
        });
      }
    });

    // Fetch trending articles when screen loads
    _fetchTrendingArticles();
    _fetchGlobalTrendingTopics();
    _trendingScrollController.addListener(_onTrendingScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _animationController.dispose();
    _trendingScrollController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/search?query="$query"'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("==================$data");
        final searchResponse = SearchResponse.fromJson(data);

        setState(() {
          _searchResults = searchResponse.results;
          _isLoading = false;
        });

        if (_searchResults.isNotEmpty && !_animationController.isCompleted) {
          _animationController.forward();
        }

        // Add to recent searches if it's not already there
        if (query.isNotEmpty && !_recentSearches.contains(query)) {
          setState(() {
            _recentSearches.insert(0, query);
            if (_recentSearches.length > 5) {
              _recentSearches.removeLast();
            }
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load results. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchTrendingArticles() async {
    setState(() {
      _isTrendingLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/articles/trending'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final trendingResponse = TrendingResponse.fromJson(data);

        setState(() {
          _trendingArticles = trendingResponse.trendingArticles;
          _isTrendingLoading = false;
        });
      } else {
        setState(() {
          _isTrendingLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isTrendingLoading = false;
      });
    }
  }

  Future<void> _fetchGlobalTrendingTopics() async {
    setState(() {
      _isGlobalTrendingLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('http://192.168.55.12:5000/wiki/trending'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final googleTrendingResponse = GoogleTrendingResponse.fromJson(data);

        setState(() {
          _globalTrendingTopics = googleTrendingResponse.trendingTopics;
          _isGlobalTrendingLoading = false;
        });
      } else {
        setState(() {
          _isGlobalTrendingLoading = false;
        });
        print('Error fetching global trending: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isGlobalTrendingLoading = false;
      });
      print('Error fetching global trending: $e');
    }
  }

  void _onTrendingScroll() {
    // Implement lazy loading when user reaches bottom of list
    if (_trendingScrollController.position.pixels >=
        _trendingScrollController.position.maxScrollExtent - 200) {
      // Load more content if needed
      // For now we're using static data, so this is just a placeholder
    }
  }

  void _launchUrl(String url, String title) async {
    final Uri uri = Uri.parse(url);

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      // Try using WebView first
      // try {
      //   Navigator.push(
      //     context,
      //     MaterialPageRoute(
      //       builder: (context) => WebViewScreen(url: url, title: title),
      //     ),
      //   );
      // } catch (webViewError) {
      //   // If WebView fails, open in external browser
      //   await launchUrl(uri, mode: LaunchMode.externalApplication);
      // }
    } catch (e) {
      // Handle any other errors
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: Unable to open article')));
    }
  }

  void _clearSearchAndReturnToTrending() {
    setState(() {
      _searchController.clear();
      _searchResults = [];
      if (_animationController.isCompleted) {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor = isDarkMode ? Colors.grey[700] : Colors.grey[300];

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,

        title: Row(
          children: [
            Icon(Icons.auto_stories, size: 24),
            SizedBox(width: 10),
            Text(
              'WikiDiscover',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        elevation: 1,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search Wikipedia',
                hintStyle: TextStyle(color: Colors.grey),
                prefixIcon: Icon(
                  Icons.search,
                  color: Theme.of(context).iconTheme.color,
                ),
                suffixIcon:
                    _showClearButton
                        ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: Theme.of(context).iconTheme.color,
                          ),
                          onPressed: _clearSearchAndReturnToTrending,
                        )
                        : null,
                filled: true,
                fillColor: secondaryColor,
                contentPadding: EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (value) {
                _performSearch(value);
              },
            ),
          ),

          if (_isLoading)
            Container(
              height: 200,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: 2,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Theme.of(context).cardColor,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image skeleton
                          Container(
                            height: 180,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                          ),

                          // Content skeleton
                          Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 18,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                SizedBox(height: 12),
                                Container(
                                  height: 14,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                SizedBox(height: 6),
                                Container(
                                  height: 14,
                                  width:
                                      MediaQuery.of(context).size.width * 0.7,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          Expanded(
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(0, 0.05),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child:
                  _searchResults.isNotEmpty
                      ? _buildSearchResults()
                      : SingleChildScrollView(
                        key: ValueKey('empty_state'),
                        physics: BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_recentSearches.isNotEmpty)
                              _buildRecentSearches(),
                            _buildTrendingSection(),
                          ],
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return Column(
      children: [
        // Back to Trending button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            children: [
              TextButton.icon(
                icon: Icon(Icons.arrow_back, size: 18),
                label: Text('Back to Trending'),
                onPressed: _clearSearchAndReturnToTrending,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),

        // Results list
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(12),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final result = _searchResults[index];
              return Hero(
                tag: 'search_result_${result.id}',
                child: Container(
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    color: Theme.of(context).cardColor,
                    child: InkWell(
                      onTap: () => _launchUrl(result.url, result.title),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image section with gradient overlay
                          Stack(
                            children: [
                              // Network image
                              Image.network(
                                result.imageUrl,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                loadingBuilder: (
                                  context,
                                  child,
                                  loadingProgress,
                                ) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    height: 180,
                                    color: Colors.grey[300],
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value:
                                            loadingProgress
                                                        .expectedTotalBytes !=
                                                    null
                                                ? loadingProgress
                                                        .cumulativeBytesLoaded /
                                                    loadingProgress
                                                        .expectedTotalBytes!
                                                : null,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 180,
                                    color: Colors.grey[200],
                                    child: Center(
                                      child: Icon(
                                        Icons.image_not_supported,
                                        size: 40,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  );
                                },
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

                              // Relevance score badge
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.star,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        '${(result.relevanceScore * 100).toInt()}%',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Title overlay
                              Positioned(
                                bottom: 8,
                                left: 12,
                                right: 12,
                                child: Text(
                                  result.title,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        offset: Offset(0, 1),
                                        blurRadius: 3,
                                        color: Colors.black.withOpacity(0.5),
                                      ),
                                    ],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                          // Content section
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Summary
                                Text(
                                  result.summary,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                    height: 1.3,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),

                                SizedBox(height: 16),

                                // Action row
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.link,
                                          color: Colors.grey[600],
                                          size: 16,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Wikipedia',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    ElevatedButton.icon(
                                      onPressed:
                                          () => _launchUrl(
                                            result.url,
                                            result.title,
                                          ),
                                      icon: Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 16,
                                      ),
                                      label: Text('Read Article'),
                                      style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        elevation: 0,
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
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentSearches() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _recentSearches.clear();
                  });
                },
                child: Text(
                  'Clear all',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 12),
            itemCount: _recentSearches.length,
            itemBuilder: (context, index) {
              return Container(
                margin: EdgeInsets.only(right: 8, left: 4),
                child: Material(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(25),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(25),
                    onTap: () {
                      _searchController.text = _recentSearches[index];
                      _performSearch(_recentSearches[index]);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.history, size: 16, color: Colors.grey),
                          SizedBox(width: 8),
                          Text(_recentSearches[index]),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 16),
        Divider(),
      ],
    );
  }

  Widget _buildTrendingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Trending Articles',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  Text(
                    'Updated today',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),

              SizedBox(height: 16),


              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTrendingToggleButton(
                      title: 'App Trending',
                      isSelected: _selectedTrendingSource == TrendingSource.app,
                      onTap: () {
                        setState(() {
                          _selectedTrendingSource = TrendingSource.app;
                        });
                      },
                    ),
                    _buildTrendingToggleButton(
                      title: 'Global Trending',
                      isSelected:
                          _selectedTrendingSource == TrendingSource.global,
                      onTap: () {
                        setState(() {
                          _selectedTrendingSource = TrendingSource.global;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        _selectedTrendingSource == TrendingSource.app
            ? _buildAppTrendingContent()
            : _buildGlobalTrendingContent(),
      ],
    );
  }

  Widget _buildTrendingToggleButton({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildAppTrendingContent() {
    if (_isTrendingLoading) {
      return _buildTrendingSkeleton();
    } else if (_trendingArticles.isEmpty) {
      return _buildEmptyTrendingState();
    } else {
      return ListView.builder(
        physics: NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemCount: _trendingArticles.length,
        itemBuilder: (context, index) {
          final article = _trendingArticles[index];
          final Color domainColor = _getDomainColor(article.domain);

          return _buildAppTrendingItem(article, domainColor, index);
        },
      );
    }
  }

  Widget _buildGlobalTrendingContent() {
    if (_isGlobalTrendingLoading) {
      return _buildTrendingSkeleton();
    } else if (_globalTrendingTopics.isEmpty) {
      return _buildEmptyTrendingState();
    } else {

      final indianTrendingTopics = _globalTrendingTopics.take(10).toList();
      final globalTrendingTopics = _globalTrendingTopics.skip(10).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Indian Trending Section
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'INDIA',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Indian Trending Topics',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
          ListView.builder(
            physics: NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: indianTrendingTopics.length,
            itemBuilder: (context, index) {
              final topic = indianTrendingTopics[index];
              return _buildTrendingTopicItem(topic, index, isIndian: true);
            },
          ),

          // Divider between sections
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 16.0,
              horizontal: 16.0,
            ),
            child: Container(height: 1, color: Colors.grey.withOpacity(0.3)),
          ),

          // Global Trending Section
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'WORLD',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Global Trending Topics',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
          ListView.builder(
            physics: NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            controller: _trendingScrollController,
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: globalTrendingTopics.length,
            itemBuilder: (context, index) {
              final topic = globalTrendingTopics[index];
              return _buildTrendingTopicItem(
                topic,
                index + 10,
                isIndian: false,
              );
            },
          ),
        ],
      );
    }
  }

  Widget _buildAppTrendingItem(
    TrendingArticle article,
    Color domainColor,
    int index,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).cardColor,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            _performSearch(article.title);
          },
          child: Container(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Rank and engagement container
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: domainColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: domainColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),

                // Article details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        article.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          _buildDomainBadge(article.domain, domainColor),
                          SizedBox(width: 8),
                          Icon(
                            Icons.comment,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${article.commentCount}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.favorite,
                            size: 14,
                            color: Colors.redAccent,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${article.likes}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Engagement score
                Container(
                  width: 40,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _getEngagementColor(
                      article.engagementScore,
                    ).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${article.engagementScore}',
                        style: TextStyle(
                          color: _getEngagementColor(article.engagementScore),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Score',
                        style: TextStyle(
                          color: _getEngagementColor(article.engagementScore),
                          fontSize: 10,
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
  }

  Widget _buildGlobalTrendingItem(GoogleTrendingTopic topic, int index) {
    // Generate a color based on the rank
    final Color itemColor = _getGlobalTrendingColor(topic.rank);

    // Format view count for better readability
    final String formattedViews = _formatViewCount(topic.views);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).cardColor,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            _performSearch(topic.title);
          },
          child: Container(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Rank container with gradient background
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        itemColor.withOpacity(0.7),
                        itemColor.withOpacity(0.3),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: itemColor.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${topic.rank}',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),

                // Topic details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        topic.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.trending_up, size: 16, color: itemColor),
                          SizedBox(width: 4),
                          Text(
                            'Global Trend',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Views count with animation
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: itemColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: itemColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formattedViews,
                        style: TextStyle(
                          color: itemColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'views',
                        style: TextStyle(
                          color: itemColor.withOpacity(0.7),
                          fontSize: 10,
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
  }

  Widget _buildTrendingTopicItem(
    GoogleTrendingTopic topic,
    int index, {
    required bool isIndian,
  }) {
    // Generate a color based on the region and rank
    final Color itemColor = isIndian 
        ? _getIndianTrendingColor(topic.rank ?? 0)  // Handle null rank
        : _getGlobalTrendingColor(topic.rank ?? 0);

    // Format view count for better readability
    final String formattedViews = _formatViewCount(topic.views ?? 0);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).cardColor,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            if (topic.title != null && topic.title!.isNotEmpty) {
              _performSearch(topic.title!);
            }
          },
          child: Container(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Rank container with gradient background
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        itemColor.withOpacity(0.7),
                        itemColor.withOpacity(0.3),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: itemColor.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${topic.rank ?? "-"}',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),

                // Topic details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        topic.title ?? "Unknown Topic",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            isIndian ? Icons.flag : Icons.public,
                            size: 16,
                            color: itemColor,
                          ),
                          SizedBox(width: 4),
                          Text(
                            isIndian ? 'India Trend' : 'Global Trend',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Views count with animation
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: itemColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: itemColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formattedViews,
                        style: TextStyle(
                          color: itemColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'views',
                        style: TextStyle(
                          color: itemColor.withOpacity(0.7),
                          fontSize: 10,
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
  }

  Widget _buildDomainBadge(String domain, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        domain.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  Color _getDomainColor(String domain) {
    switch (domain.toLowerCase()) {
      case 'food':
        return Colors.orange;
      case 'education':
        return Colors.blue;
      case 'political':
        return Colors.red;
      case 'space':
        return Colors.purple;
      default:
        return Theme.of(context).primaryColor;
    }
  }

  Color _getEngagementColor(int score) {
    if (score > 4) return Colors.green;
    if (score > 2) return Colors.orange;
    return Colors.blue;
  }

  Widget _buildEmptyTrendingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(Icons.trending_up, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No trending articles available',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingSkeleton() {
    return ListView.builder(
      physics: NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: EdgeInsets.symmetric(horizontal: 16),
      itemCount: 5, // Show 5 skeleton items
      itemBuilder: (context, index) {
        return Container(
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context).cardColor,
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Rank skeleton
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 16),

                // Content skeleton
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 18,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        height: 14,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),

                // Score skeleton
                Container(
                  width: 40,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getGlobalTrendingColor(int rank) {
    if (rank < 10) return Colors.deepPurple;
    if (rank < 50) return Colors.blue;
    if (rank < 100) return Colors.teal;
    if (rank < 200) return Colors.green;
    if (rank < 400) return Colors.amber;
    return Colors.orange;
  }

  String _formatViewCount(int views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K';
    }
    return views.toString();
  }

  // Add this new method for Indian trending colors
  Color _getIndianTrendingColor(int rank) {
    if (rank < 3) return Colors.orange;
    if (rank < 6) return Colors.deepOrange;
    return Colors.amber;
  }
}
