import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:tik_tok_wikipidiea/navigations/bottom_navbar.dart';

import '../../config.dart';

class UserInterestPage extends StatefulWidget {
  const UserInterestPage({Key? key, required Map<String, String> authData}) : authData = authData, super(key: key);
  final Map<String, String> authData;
  @override
  _UserInterestPageState createState() => _UserInterestPageState();
}

class _UserInterestPageState extends State<UserInterestPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // List to store all available interests with their associated network images
  final List<Map<String, dynamic>> _allInterests = [
    {
      'name': 'Nature',
      'image':
          'https://images.unsplash.com/photo-1501854140801-50d01698950b?ixlib=rb-1.2.1&auto=format&fit=crop&w=600&q=80',
      'icon': Icons.terrain,
    },
    {
      'name': 'Education',
      'image':
          'https://images.unsplash.com/photo-1503676260728-1c00da094a0b?ixlib=rb-1.2.1&auto=format&fit=crop&w=600&q=80',
      'icon': Icons.school,
    },
    {
      'name': 'Entertainment',
      'image':
          'https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3?ixlib=rb-1.2.1&auto=format&fit=crop&w=600&q=80',
      'icon': Icons.movie,
    },
    {
      'name': 'Technology',
      'image':
          'https://images.unsplash.com/photo-1518770660439-4636190af475?ixlib=rb-1.2.1&auto=format&fit=crop&w=600&q=80',
      'icon': Icons.computer,
    },
    {
      'name': 'Science',
      'image':
          'https://images.unsplash.com/photo-1507413245164-6160d8298b31?ixlib=rb-1.2.1&auto=format&fit=crop&w=600&q=80',
      'icon': Icons.science,
    },
    {
      'name': 'Political',
      'image':
          'https://images.unsplash.com/photo-1575320181282-9afab399332c?ixlib=rb-1.2.1&auto=format&fit=crop&w=600&q=80',
      'icon': Icons.account_balance,
    },
    {
      'name': 'Lifestyle',
      'image':
          'https://images.unsplash.com/photo-1545205597-3d9d02c29597?ixlib=rb-1.2.1&auto=format&fit=crop&w=600&q=80',
      'icon': Icons.spa,
    },
    {
      'name': 'Social',
      'image':
          'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?ixlib=rb-1.2.1&auto=format&fit=crop&w=600&q=80',
      'icon': Icons.people,
    },
    {
      'name': 'Space',
      'image':
          'https://images.unsplash.com/photo-1462331940025-496dfbfc7564?ixlib=rb-1.2.1&auto=format&fit=crop&w=600&q=80',
      'icon': Icons.rocket,
    },
    {
      'name': 'Food',
      'image':
          'https://images.unsplash.com/photo-1504674900247-0877df9cc836?ixlib=rb-1.2.1&auto=format&fit=crop&w=600&q=80',
      'icon': Icons.restaurant,
    },
  ];

  // List to store selected interests
  List<String> interestList = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Header Section
              Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Spacer(),
                        Text(
                          'Set Up Your Profile',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'What topics interest you?',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select all that apply. We\'ll use these to customize your content feed.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // Interest Grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: _allInterests.length,
                    itemBuilder: (context, index) {
                      final interest = _allInterests[index];
                      final isSelected = interestList.contains(
                        interest['name'],
                      );

                      return _buildInterestCard(
                        interest: interest,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              interestList.remove(interest['name']);
                            } else {
                              interestList.add(interest['name']);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ),

              // Continue Button
              Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  interestList.isNotEmpty
                            ? () async {
                             
        final baseUrl = Config.baseUrl; // Replace with your actual base URL
        final signupEndpoint = '$baseUrl/signup';
        final signupData = {
          'fullname': widget.authData['name'],
          'email': widget.authData['email'],
          'phone': widget.authData['phone'],
          'password': widget.authData['password'],
          'bio': widget.authData['bio'],
          'interestedDomain': interestList,
        };
          
        final response = await http.post(
          Uri.parse(signupEndpoint),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(signupData),
        );

        if (response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Registration successful! Please login.'),
              backgroundColor: Theme.of(context).primaryColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
          // If you need to set a login state, define it in your class
          // setState(() {
          //   isLogin = true;
          // });
          setState(() {
            isLogin = true;
          });
        } else {
          print(json.decode(response.body)['error']);
          throw Exception(json.decode(response.body)['error']);
        }
      
                              print('Selected interests: $interestList');
                              Navigator.of(context).pushReplacement(MaterialPageRoute(builder:(context) => BottomNavBar()));
                            }
                            : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: primaryColor.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'CONTINUE',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
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

  Widget _buildInterestCard({
    required Map<String, dynamic> interest,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: theme.primaryColor.withOpacity(0.3),
          child: Stack(
            children: [
              // Background Image with Loading Placeholder
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  interest['image'],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                      child: Center(
                        child: CircularProgressIndicator(
                          value:
                              loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.primaryColor.withOpacity(0.7),
                          ),
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback for failed image loads
                    return Container(
                      color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                      child: Center(
                        child: Icon(
                          interest['icon'],
                          size: 32,
                          color:
                              isDarkMode ? Colors.grey[600] : Colors.grey[400],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(isSelected ? 0.7 : 0.5),
                      Colors.black.withOpacity(isSelected ? 0.8 : 0.6),
                    ],
                  ),
                  border: Border.all(
                    color: isSelected ? theme.primaryColor : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(interest['icon'], color: Colors.white, size: 20),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: theme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      interest['name'],
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        shadows: [
                          Shadow(
                            offset: const Offset(0, 1),
                            blurRadius: 3.0,
                            color: Colors.black.withOpacity(0.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedOpacity(
                      opacity: isSelected ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        height: 3,
                        width: 36,
                        decoration: BoxDecoration(
                          color: theme.primaryColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
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
}
