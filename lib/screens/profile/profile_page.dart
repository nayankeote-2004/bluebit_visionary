import 'package:flutter/material.dart';
import 'package:tik_tok_wikipidiea/screens/profile/book_mark.dart';
import 'package:tik_tok_wikipidiea/services/autoscroll.dart';
import 'package:tik_tok_wikipidiea/services/theme_render.dart';
import 'dart:async';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // User data (would typically come from a user service/model)
  String userName = "John Doe";
  String userBio = "Flutter Developer | Tech Enthusiast";
  String avatarUrl = "https://via.placeholder.com/150";

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

  // Avatar customization options
  List<String> avatarOptions = [
    "https://via.placeholder.com/150/FF5722/FFFFFF",
    "https://via.placeholder.com/150/2196F3/FFFFFF",
    "https://via.placeholder.com/150/4CAF50/FFFFFF",
    "https://via.placeholder.com/150/9C27B0/FFFFFF",
    "https://via.placeholder.com/150/FFEB3B/000000",
  ];

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

  void _openAvatarCustomizationDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Customize Avatar'),
            content: Container(
              width: double.maxFinite,
              child: GridView.builder(
                shrinkWrap: true,
                itemCount: avatarOptions.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        avatarUrl = avatarOptions[index];
                      });
                      Navigator.of(context).pop();
                    },
                    child: CircleAvatar(
                      backgroundImage: NetworkImage(avatarOptions[index]),
                      radius: 30,
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              // Show enhanced confirmation dialog
              showDialog(
                context: context,
                builder:
                    (context) => Dialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 8,
                      child: Container(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.logout_rounded,
                                color: theme.primaryColor,
                                size: 32,
                              ),
                            ),
                            SizedBox(height: 24),
                            Text(
                              'Logout',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Are you sure you want to log out of your account?',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium,
                            ),
                            SizedBox(height: 32),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(),
                                    style: OutlinedButton.styleFrom(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      side: BorderSide(
                                        color: theme.primaryColor,
                                      ),
                                    ),
                                    child: Text('Cancel'),
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      // Implement logout functionality here
                                      // For example: AuthService().logout();
                                      Navigator.of(context).pop();
                                      // Navigate to login screen
                                      // Navigator.of(context).pushReplacementNamed('/login');
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      backgroundColor: theme.primaryColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text('Logout'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
              );
            },
          ),
        ],
      ),
      body: ListView(
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
                        backgroundImage: NetworkImage(avatarUrl),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: theme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.edit, color: Colors.white),
                          onPressed: _openAvatarCustomizationDialog,
                          tooltip: 'Customize avatar',
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
                      Text('Auto Scroll', style: theme.textTheme.bodyMedium),
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      Text('Dark Mode', style: theme.textTheme.bodyMedium),
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
                  Text(
                    'Activity Stats',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),

                  // Articles Read - regular stat
                  _buildStatRow('Articles Read', '42', theme),
                  SizedBox(height: 12),

                  // Bookmarks - clickable stat that navigates to bookmarks page
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BookmarksPage(),
                        ),
                      );
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Bookmarks',
                                style: theme.textTheme.bodyMedium,
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 12,
                                color: theme.iconTheme.color,
                              ),
                            ],
                          ),
                          Text(
                            '15', // This would normally come from a real count
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 12),

                  // Comments - regular stat
                  _buildStatRow('Comments', '7', theme),
                ],
              ),
            ),
          ),
        ],
      ),
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
}
