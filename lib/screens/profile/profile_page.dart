import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tik_tok_wikipidiea/Auth/AuthScreen.dart';
import 'dart:convert';
import 'package:tik_tok_wikipidiea/screens/profile/book_mark.dart';
import 'package:tik_tok_wikipidiea/screens/profile/domain_articles_page.dart';
import 'package:tik_tok_wikipidiea/services/autoscroll.dart';
import 'package:tik_tok_wikipidiea/services/bookmark_services.dart';
import 'package:tik_tok_wikipidiea/services/theme_render.dart';
import 'dart:async';
import 'package:tik_tok_wikipidiea/config.dart'; // Make sure this is imported to use the baseUrl
import 'package:http/http.dart' as http;
// Add these imports at the top of the file
import 'package:tik_tok_wikipidiea/screens/profile/liked_articles.dart';
import 'package:tik_tok_wikipidiea/screens/profile/your_comments.dart';
import 'package:tik_tok_wikipidiea/screens/profile/milestones.dart';
import 'package:tik_tok_wikipidiea/widgets/streak_bottom_sheet.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // User data that will be loaded from SharedPreferences
  String userName = "Loading...";
  String userBio = "Loading...";
  String avatarUrl = "https://via.placeholder.com/150";
  String userId = "";
  String userEmail = "";

  // Add list of interested domains
  List<dynamic> interestedDomains = [];

  // Add user interactions tracking
  Map<String, dynamic> userInteractions = {
    'likedArticles': [],
    'commentedArticles': [],
    'sharedArticles': [],
  };

  bool isLoading = true;

  // Theme toggle
  bool _isDarkMode = false;
  final ThemeService _themeService = ThemeService();

  // Auto scroll settings
  final AutoScrollService _autoScrollService = AutoScrollService();
  bool _autoScrollEnabled = false;
  int _scrollInterval = 5; // seconds
  final List<int> _scrollIntervals = [3, 5, 10, 15, 30];
  Timer? _scrollTimer;
  final ScrollController _scrollController = ScrollController();

  // Avatar customization options - 2 male, 2 female
  List<Map<String, dynamic>> avatarOptions = [
    {"asset": "assets/boy1.png", "gender": "Male", "isDefault": true},
    {"asset": "assets/boy2.png", "gender": "Male", "isDefault": false},
    {"asset": "assets/girl1.png", "gender": "Female", "isDefault": false},
    {"asset": "assets/girl2.png", "gender": "Female", "isDefault": false},
  ];

  // Default avatar (first male avatar)
  String selectedAvatarAsset = "assets/default.jpg";

  // Key for storing avatar selection in SharedPreferences
  final String _avatarKey = 'user_avatar';

  // Add loading state for interactions
  bool isLoadingInteractions = false;

  // Add to the top of the _ProfilePageState class
  final BookmarkService _bookmarkService = BookmarkService();

  // Add these new variables to _ProfilePageState class
  int _todayReadCount = 0;
  final String _readCountKey = 'read_articles_count';
  final String _readDateKey = 'read_articles_date';

  // Add streak tracking variables
  int _streakCount = 0;
  Map<String, int> _domainReadCounts = {};
  final String _streakCountKey = 'streak_count';
  final String _lastStreakDateKey = 'last_streak_date';
  final String _domainReadCountsKey = 'domain_read_counts';
  final int _articlesPerDomainGoal = 10;

  // Method to increment domain read count
  Future<void> _incrementDomainReadCount(String domain) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Increment the count for the specified domain
      _domainReadCounts[domain] = (_domainReadCounts[domain] ?? 0) + 1;

      // Save the updated counts
      await prefs.setString(
        _domainReadCountsKey,
        json.encode(_domainReadCounts),
      );

      // Update the UI
      setState(() {});
    } catch (e) {
      print('Error incrementing domain read count: $e');
    }
  }

  // Method to show streak info dialog
  void _showStreakInfoDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Streak Information'),
            content: Text(
              'Reading articles in your interested domains helps build your streak. '
              'Try to read at least one article per day to maintain your streak!',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Initialize from services
    _autoScrollEnabled = _autoScrollService.enabled;
    _scrollInterval = _autoScrollService.intervalSeconds;

    // Ensure we get the current theme status from the service
    _isDarkMode = _themeService.isDarkMode;

    // Listen for theme changes from other parts of the app
    _themeService.addListener(_onThemeChanged);

    // Load user data from SharedPreferences
    _loadUserData();

    // Load today's read count
    _loadReadCount();

    // Load saved avatar
    _loadSavedAvatar();

    // Load streak data
    _loadStreakData();
  }

  // Load user data from SharedPreferences
  Future<void> _loadUserData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      // Get basic user info
      final name = prefs.getString('username');
      final email = prefs.getString('email');
      final bio = prefs.getString('bio');
      final id = prefs.getString('userId');

      // Get interested domains
      final domainsString = prefs.getString('interestedDomains');
      List<dynamic> domains = [];

      if (domainsString != null && domainsString.isNotEmpty) {
        // Parse the JSON string into a List
        domains = json.decode(domainsString);
        print("domains are ${domains}");
      }

      // Update the state with loaded data
      if (mounted) {
        setState(() {
          userName = name ?? "No Name";
          userEmail = email ?? "No Email";
          userBio = bio ?? "No Bio";
          userId = id ?? "";
          interestedDomains = domains;
          isLoading = false;
        });

        // Now fetch interactions from backend
        if (userId.isNotEmpty) {
          _fetchUserInteractions();
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Add this method to fetch interactions from backend
  Future<void> _fetchUserInteractions() async {
    if (userId.isEmpty) return;

    setState(() {
      isLoadingInteractions = true;
    });

    try {
      final baseUrl = Config.baseUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/user/$userId/interactions'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (mounted) {
          setState(() {
            userInteractions = {
              'likedArticles': data['likedArticles'] ?? [],
              'commentedArticles': data['commentedArticles'] ?? [],
              'sharedArticles': data['sharedArticles'] ?? [],
            };
            isLoadingInteractions = false;
          });
        }
      } else {
        throw Exception('Failed to load user interactions');
      }
    } catch (e) {
      print('Error fetching user interactions: $e');
      if (mounted) {
        setState(() {
          isLoadingInteractions = false;
        });
      }
    }
  }

  // Add this method to load the current read count
  Future<void> _loadReadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get current date
      final now = DateTime.now();
      final today =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      // Check if the stored date matches today
      final storedDate = prefs.getString(_readDateKey) ?? '';

      if (storedDate == today) {
        setState(() {
          _todayReadCount = prefs.getInt(_readCountKey) ?? 0;
        });
      } else {
        // If date doesn't match, it means we haven't read anything today yet
        setState(() {
          _todayReadCount = 0;
        });

        // Update the stored date
        await prefs.setString(_readDateKey, today);
        await prefs.setInt(_readCountKey, 0);
      }
    } catch (e) {
      print('Error loading read count: $e');
    }
  }

  // Add this method to load the saved avatar
  Future<void> _loadSavedAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedAvatar = prefs.getString(_avatarKey);

      if (savedAvatar != null && savedAvatar.isNotEmpty) {
        setState(() {
          selectedAvatarAsset = savedAvatar;
        });
      } else {
        // If no avatar is saved, set the default one
        _saveAvatarSelection(
          avatarOptions.firstWhere((avatar) => avatar["isDefault"])["asset"],
        );
      }
    } catch (e) {
      print('Error loading avatar: $e');
    }
  }

  // Add this method to save the avatar selection
  Future<void> _saveAvatarSelection(String avatarAsset) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_avatarKey, avatarAsset);

      setState(() {
        selectedAvatarAsset = avatarAsset;
      });
    } catch (e) {
      print('Error saving avatar: $e');
    }
  }

  // Add this method to load streak data
  Future<void> _loadStreakData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get streak count
      final streakCount = prefs.getInt(_streakCountKey) ?? 0;

      // Check if streak is still valid (should be updated daily)
      final lastStreakDate = prefs.getString(_lastStreakDateKey) ?? '';
      final now = DateTime.now();
      final today =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      // Get domain read counts
      final domainReadCountsJson =
          prefs.getString(_domainReadCountsKey) ?? '{}';
      Map<String, dynamic> rawCounts = json.decode(domainReadCountsJson);
      Map<String, int> domainReadCounts = {};

      // Convert string keys to proper type
      rawCounts.forEach((key, value) {
        domainReadCounts[key] = value as int;
      });

      // Reset counts if it's a new day
      if (lastStreakDate != today) {
        domainReadCounts = Map.fromIterable(
          interestedDomains,
          key: (domain) => domain as String,
          value: (_) => 0,
        );

        // Save the reset counts
        await prefs.setString(
          _domainReadCountsKey,
          json.encode(domainReadCounts),
        );
        await prefs.setString(_lastStreakDateKey, today);
      }

      setState(() {
        _streakCount = streakCount;
        _domainReadCounts = domainReadCounts;
      });
    } catch (e) {
      print('Error loading streak data: $e');
    }
  }

  // Update the refresh to also refresh interactions
  Future<void> _refreshUserData() async {
    await _loadUserData();
    await _loadReadCount();
  }

  // Add this method to update UI when theme changes from elsewhere
  void _onThemeChanged(ThemeMode mode) {
    if (mounted) {
      setState(() {
        _isDarkMode = mode == ThemeMode.dark;
      });
    }
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _toggleTheme() {
    // Update theme service (which persists the setting)
    _themeService.toggleTheme().then((_) {
      // Update local state
      setState(() {
        _isDarkMode = _themeService.isDarkMode;
      });
    });
  }

  void _toggleAutoScroll(bool value) {
    setState(() {
      _autoScrollEnabled = value;
    });

    // Update service and notify listeners
    _autoScrollService.updateSettings(enabled: value);

    if (_autoScrollEnabled) {
      _startAutoScroll();
    } else {
      _scrollTimer?.cancel();
    }
  }

  void _startAutoScroll() {
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(Duration(seconds: _scrollInterval), (_) {
      if (_scrollController.hasClients) {
        final currentPosition = _scrollController.offset;
        final maxPosition = _scrollController.position.maxScrollExtent;

        if (currentPosition < maxPosition) {
          _scrollController.animateTo(
            currentPosition + 100,
            duration: Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        } else {
          _scrollController.animateTo(
            0,
            duration: Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  void _changeScrollInterval(int? interval) {
    if (interval != null) {
      setState(() {
        _scrollInterval = interval;
      });

      // Update service and notify listeners
      _autoScrollService.updateSettings(intervalSeconds: interval);

      if (_autoScrollEnabled) {
        _startAutoScroll(); // Restart with new interval
      }
    }
  }

  // Update the avatar customization dialog
  void _openAvatarCustomizationDialog() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
            backgroundColor: theme.cardColor,
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Text(
                    'Choose Your Avatar',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 8),

                  // Divider
                  Container(
                    width: 50,
                    height: 3,
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),

                  SizedBox(height: 24),

                  // Avatar Grid
                  GridView.builder(
                    shrinkWrap: true,
                    itemCount: avatarOptions.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.85,
                    ),
                    itemBuilder: (context, index) {
                      final avatar = avatarOptions[index];
                      final isSelected = selectedAvatarAsset == avatar["asset"];

                      return GestureDetector(
                        onTap: () => _saveAvatarSelection(avatar["asset"]),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Avatar with selection indicator
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                // Background circle with highlight for selected avatar
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          isSelected
                                              ? theme.primaryColor
                                              : Colors.transparent,
                                      width: 3,
                                    ),
                                    boxShadow:
                                        isSelected
                                            ? [
                                              BoxShadow(
                                                color: theme.primaryColor
                                                    .withOpacity(0.3),
                                                blurRadius: 10,
                                                spreadRadius: 2,
                                              ),
                                            ]
                                            : null,
                                  ),
                                ),

                                // Avatar image
                                CircleAvatar(
                                  radius: 35,
                                  backgroundColor:
                                      isDarkMode
                                          ? Colors.black12
                                          : Colors.grey.shade100,
                                  child: ClipOval(
                                    child: Image.asset(
                                      avatar["asset"],
                                      width: 70,
                                      height: 70,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),

                                // Selection check icon
                                if (isSelected)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: theme.primaryColor,
                                        border: Border.all(
                                          color: theme.cardColor,
                                          width: 2,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            SizedBox(height: 8),

                            // Gender label
                            Text(
                              avatar["gender"],
                              style: TextStyle(
                                color:
                                    isSelected
                                        ? theme.primaryColor
                                        : theme.textTheme.bodyMedium?.color,
                                fontWeight:
                                    isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  SizedBox(height: 20),

                  // Close button
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      'Done',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _handleLogout() {
    // Add haptic feedback
    HapticFeedback.mediumImpact();

    // Define the red theme colors
    final Color redPrimary = Color(0xFFE53935);
    final Color redDark = Color(0xFFC62828);
    final Color redLight = Color(0xFFEF5350);

    // Show enhanced confirmation dialog with animation
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black87.withOpacity(0.6),
      transitionDuration: Duration(milliseconds: 250),
      pageBuilder: (context, animation1, animation2) => Container(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          child: FadeTransition(
            opacity: animation,
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 12,
              shadowColor: redDark.withOpacity(0.3),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).cardColor,
                      Theme.of(context).brightness == Brightness.dark
                          ? Color(0xFF2A1A1A) // Dark mode red tint
                          : Color(0xFFFFF5F5), // Light mode red tint
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated icon with shield and power symbol
                    TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: Duration(milliseconds: 600),
                      curve: Curves.elasticOut,
                      builder: (context, double value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer glow
                              Container(
                                width: 80 * value,
                                height: 80 * value,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: redPrimary.withOpacity(0.15),
                                      blurRadius: 20 * value,
                                      spreadRadius: 5 * value,
                                    ),
                                  ],
                                ),
                              ),
                              // Inner circle
                              Container(
                                padding: EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: redPrimary.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: redPrimary.withOpacity(0.5),
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.power_settings_new_rounded,
                                  color: redPrimary,
                                  size: 36,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 28),

                    // Title with warning icon
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: redPrimary,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback:
                              (bounds) => LinearGradient(
                                colors: [redPrimary, redDark],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds),
                          child: Text(
                            'Logout Account',
                            style: Theme.of(
                              context,
                            ).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    // Divider with gradient
                    Container(
                      width: 50,
                      height: 3,
                      margin: EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [redLight.withOpacity(0.7), redDark],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),

                    // Personalized message with username and current date
                    Column(
                      children: [
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(height: 1.5),
                            children: [
                              TextSpan(
                                text:
                                    'Are you sure you want to log out from this device',
                              ),
                              TextSpan(text: '?'),
                            ],
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          DateTime.now().toUtc().toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 32),

                    // Buttons with enhanced styling
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).pop();
                            },
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(
                                color: Theme.of(context).dividerColor,
                              ),
                              foregroundColor:
                                  Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              HapticFeedback.mediumImpact();

                              // Show loading indicator
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (BuildContext context) {
                                  return Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        redPrimary,
                                      ),
                                    ),
                                  );
                                },
                              );

                              // Process logout
                              Future.delayed(Duration(milliseconds: 800), () async {
                                try {
                                  // Clear user data from SharedPreferences
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs
                                      .clear(); // Ensure all user data is cleared

                                  // Close loading dialog
                                  Navigator.of(context).pop();

                                  // Close logout dialog
                                  Navigator.of(context).pop();

                                  // Show success snackbar
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          Icon(
                                            Icons.check_circle_outline,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 12),
                                          Text('Successfully logged out'),
                                        ],
                                      ),
                                      backgroundColor: redPrimary,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );

                                  // Navigate to auth screen directly (instead of potentially going through the splash)
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                      builder: (context) => AuthScreen(),
                                    ),
                                    (route) =>
                                        false, // This will remove all previous routes
                                  );
                                } catch (e) {
                                  // Close loading dialog on error
                                  Navigator.of(context).pop();

                                  // Show error message
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Error logging out: ${e.toString()}',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  print('Logout error: $e');
                                }
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: redPrimary,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shadowColor: redPrimary.withOpacity(0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Logout',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Get interaction counts
    final likedCount = userInteractions['likedArticles']?.length ?? 0;
    final commentedCount = userInteractions['commentedArticles']?.length ?? 0;
    final sharedCount = userInteractions['sharedArticles']?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        actions: [
          // Replace the simple IconButton with a Row containing icon and streak count
          GestureDetector(
            onTap: () {
              StreakBottomSheet.show(
                todayReadCount: _todayReadCount,
                context: context,
                streakCount: _streakCount,
                interestedDomains: interestedDomains,
                domainReadCounts: _domainReadCounts,
                articlesPerDomainGoal: _articlesPerDomainGoal,
                incrementDomainReadCount: _incrementDomainReadCount,
                showStreakInfoDialog: _showStreakInfoDialog,
              );
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              margin: EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color:
                    theme.brightness == Brightness.dark
                        ? Colors.amber.withOpacity(0.2)
                        : Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.emoji_events, color: Colors.amber, size: 22),
                  SizedBox(width: 4),
                  Text(
                    '$_streakCount',
                    style: TextStyle(
                      color:
                          theme.brightness == Brightness.dark
                              ? Colors.amber
                              : Colors.amber.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body:
          isLoading
              ? Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _refreshUserData, // Use the renamed method
                child: ListView(
                  controller: _scrollController,
                  padding: EdgeInsets.all(16),
                  children: [
                    // Profile Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: 60,
                                  backgroundColor: theme.cardColor,
                                  child: ClipOval(
                                    child: Image.asset(
                                      selectedAvatarAsset,
                                      width: 120,
                                      height: 120,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: theme.primaryColor,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 8,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: IconButton(
                                    icon: Icon(Icons.edit, color: Colors.white),
                                    onPressed: _openAvatarCustomizationDialog,
                                    tooltip: 'Change avatar',
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            Text(
                              userName,
                              style: theme.textTheme.displayMedium?.copyWith(
                                fontSize: 24,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              userEmail,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.textTheme.bodySmall?.color,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              userBio,
                              style: theme.textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 24),

                    // Interaction Stats Card - Add this new card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.analytics_outlined,
                                      color: theme.primaryColor,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Your Activity',
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                                // Add refresh button
                                if (!isLoadingInteractions)
                                  IconButton(
                                    icon: Icon(Icons.refresh, size: 18),
                                    onPressed: _fetchUserInteractions,
                                    tooltip: 'Refresh interactions',
                                    visualDensity: VisualDensity.compact,
                                  ),
                                if (isLoadingInteractions)
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: 16),
                            isLoadingInteractions
                                ? Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24),
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                                : Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildStatColumn(
                                      context,
                                      Icons.favorite,
                                      likedCount.toString(),
                                      'Liked',
                                      theme.primaryColor,
                                    ),
                                    _buildStatColumn(
                                      context,
                                      Icons.comment,
                                      commentedCount.toString(),
                                      'Comments',
                                      Colors.amber,
                                    ),
                                    _buildStatColumn(
                                      context,
                                      Icons.share,
                                      sharedCount.toString(),
                                      'Shared',
                                      Colors.green,
                                    ),
                                    // Add new bookmark column
                                    _buildStatColumn(
                                      context,
                                      Icons.bookmark,
                                      _bookmarkService.bookmarkedPosts.length
                                          .toString(),
                                      'Bookmarks',
                                      Colors.blue,
                                    ),
                                  ],
                                ),
                            SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 24),

                    // Interested Domains Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.interests,
                                      color: theme.primaryColor,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Interested Domains',
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                                // IconButton(
                                //   icon: Icon(Icons.edit, size: 18),
                                //   onPressed: () {
                                //     // TODO: Implement edit interests functionality
                                //     ScaffoldMessenger.of(context).showSnackBar(
                                //       SnackBar(
                                //         content: Text(
                                //           'Edit interests (to be implemented)',
                                //         ),
                                //       ),
                                //     );
                                //   },
                                //   tooltip: 'Edit interests',
                                //   visualDensity: VisualDensity.compact,
                                // ),
                              ],
                            ),
                            SizedBox(height: 16),
                            interestedDomains.isEmpty
                                ? Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Text(
                                      'No interests selected yet',
                                      style: TextStyle(
                                        color: theme.textTheme.bodySmall?.color,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                )
                                : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children:
                                      interestedDomains.map((domain) {
                                        return _buildInterestChip(
                                          domain,
                                          theme,
                                        );
                                      }).toList(),
                                ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 24),

                    // Settings Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Settings',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 16),

                            // Auto Scroll Switch
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Auto Scroll',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                Switch(
                                  value: _autoScrollEnabled,
                                  onChanged: _toggleAutoScroll,
                                  activeColor: theme.primaryColor,
                                ),
                              ],
                            ),

                            // Auto Scroll Interval Dropdown (visible only when auto scroll is enabled)
                            if (_autoScrollEnabled) ...[
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Scroll Interval',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  DropdownButton<int>(
                                    value: _scrollInterval,
                                    items:
                                        _scrollIntervals.map((int interval) {
                                          return DropdownMenuItem<int>(
                                            value: interval,
                                            child: Text('$interval seconds'),
                                          );
                                        }).toList(),
                                    onChanged: _changeScrollInterval,
                                    dropdownColor: theme.cardColor,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ],

                            Divider(height: 32),

                            // Theme Toggle
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Dark Mode',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                Switch(
                                  value: _isDarkMode,
                                  onChanged: (value) => _toggleTheme(),
                                  activeColor: theme.primaryColor,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 24),

                    // Stats Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Activity Stats',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                // Add refresh button for stats
                                IconButton(
                                  icon: Icon(Icons.refresh, size: 18),
                                  onPressed: _loadReadCount,
                                  tooltip: 'Refresh stats',
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            SizedBox(height: 16),

                            // Articles Read Today
                            _buildStatRow(
                              'Articles Read Today',
                              '$_todayReadCount',
                              theme,
                            ),
                            SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),

                    // Add logout button card at the bottom
                    SizedBox(height: 24),

                    // Logout Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: InkWell(
                        onTap: _handleLogout,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.logout_rounded,
                                color: Colors.red,
                                size: 24,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Logout',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Add padding at the bottom for better scroll experience
                    SizedBox(height: 32),
                  ],
                ),
              ),
    );
  }

  Widget _buildInterestChip(String domain, ThemeData theme) {
    // Map domain names to appropriate icons
    final Map<String, IconData> domainIcons = {
      'Nature': Icons.terrain,
      'Education': Icons.school,
      'Entertainment': Icons.movie,
      'Technology': Icons.computer,
      'Science': Icons.science,
      'Political': Icons.account_balance,
      'Lifestyle': Icons.spa,
      'Social': Icons.people,
      'Space': Icons.rocket,
      'Food': Icons.restaurant,
    };

    final icon = domainIcons[domain] ?? Icons.interests;

    return Chip(
      avatar: Icon(icon, size: 16, color: theme.primaryColor),
      label: Text(domain),
      backgroundColor: theme.primaryColor.withOpacity(0.1),
      side: BorderSide(color: theme.primaryColor.withOpacity(0.5), width: 1),
      labelStyle: TextStyle(
        color: theme.primaryColor,
        fontWeight: FontWeight.w500,
      ),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildStatRow(String label, String value, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.primaryColor,
          ),
        ),
      ],
    );
  }

  // Helper method to build a stat column
  Widget _buildStatColumn(
    BuildContext context,
    IconData icon,
    String count,
    String label,
    Color iconColor,
  ) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        // Navigate based on which stat was clicked
        if (label == 'Liked') {
          print(userInteractions);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => LikedArticlesPage(
                    likedArticles: userInteractions['likedArticles'] ?? [],
                  ),
            ),
          );
        } else if (label == 'Comments') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => YourCommentsPage()),
          );
        } else if (label == 'Bookmarks') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => BookmarksPage()),
          );
        } else if (label == 'Shared') {
          // Add milestone for shares
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => MilestonesPage(
                    currentCount: int.parse(count),
                    type: 'shares',
                  ),
            ),
          );
        }
      },
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          SizedBox(height: 8),
          Text(
            count,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
