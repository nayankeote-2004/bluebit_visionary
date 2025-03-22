import 'package:flutter/material.dart';

class Search_screen extends StatefulWidget {
  const Search_screen({Key? key}) : super(key: key);

  @override
  State<Search_screen> createState() => _Search_screenState();
}

class _Search_screenState extends State<Search_screen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showClearButton = false;
  
  // Mock data for suggestions and trending topics
  final List<String> _recentSearches = [
    'Flutter tips',
    'Animation tutorials',
    'State management',
  ];
  
  final List<Map<String, dynamic>> _trendingTopics = [
    {'tag': 'Flutter', 'count': '2.5M', 'change': 1},
    {'tag': 'SwiftUI', 'count': '1.2M', 'change': 2},
    {'tag': 'ReactNative', 'count': '980K', 'change': -1},
    {'tag': 'Kotlin', 'count': '850K', 'change': 3},
    {'tag': 'DartProgramming', 'count': '720K', 'change': 5},
    {'tag': 'MobileApps', 'count': '650K', 'change': -2},
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _showClearButton = _searchController.text.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor = isDarkMode ? Colors.grey[700] : Colors.grey[300];
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Discover', style: Theme.of(context).textTheme.headlineMedium),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search topics, tags, or keywords',
                hintStyle: TextStyle(color: Colors.grey),
                prefixIcon: Icon(Icons.search, color: Theme.of(context).iconTheme.color),
                suffixIcon: _showClearButton
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Theme.of(context).iconTheme.color),
                        onPressed: () {
                          _searchController.clear();
                        },
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
                // Handle search submission
                if (value.isNotEmpty && !_recentSearches.contains(value)) {
                  setState(() {
                    _recentSearches.insert(0, value);
                    if (_recentSearches.length > 5) {
                      _recentSearches.removeLast();
                    }
                  });
                }
              },
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_recentSearches.isNotEmpty) _buildRecentSearches(),
                  _buildTrendingSection(),
                ],
              ),
            ),
          ),
        ],
      ),
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
        ListView.builder(
          physics: NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: _recentSearches.length,
          itemBuilder: (context, index) {
            return ListTile(
              leading: Icon(Icons.history),
              title: Text(_recentSearches[index]),
              trailing: IconButton(
                icon: Icon(Icons.close, size: 18),
                onPressed: () {
                  setState(() {
                    _recentSearches.removeAt(index);
                  });
                },
              ),
              onTap: () {
                _searchController.text = _recentSearches[index];
                // Perform search
              },
            );
          },
        ),
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
          child: Text(
            'Trending Topics',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ListView.builder(
          physics: NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: _trendingTopics.length,
          itemBuilder: (context, index) {
            final topic = _trendingTopics[index];
            final isPositiveChange = topic['change'] > 0;
            
            return Container(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  '#${topic['tag']}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${topic['count']} posts'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositiveChange ? Icons.trending_up : Icons.trending_down,
                      color: isPositiveChange ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '${topic['change'].abs()}',
                      style: TextStyle(
                        color: isPositiveChange ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  _searchController.text = topic['tag'];
                  // Perform search
                },
              ),
            );
          },
        ),
      ],
    );
  }
}