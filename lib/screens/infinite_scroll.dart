import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tik_tok_wikipidiea/models/post_content.dart';
import 'dart:math';
import 'dart:async';

import 'package:tik_tok_wikipidiea/screens/post_details.dart';

class ScrollScreen extends StatefulWidget {
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

  // Track reading time
  int _currentIndex = 0;
  DateTime? _pageViewStartTime;
  Map<int, Duration> _readingTimes = {};

  @override
  void initState() {
    super.initState();
    _startTrackingTime(0);
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
        'Post $_currentIndex reading time: ${_readingTimes[_currentIndex]!.inSeconds} seconds',
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
                                          Icons.bookmark_border,
                                          size: 22,
                                          color:
                                              Theme.of(context).iconTheme.color,
                                        ),
                                        onPressed: () {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text("Article saved"),
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
    super.dispose();
  }
}
