import 'package:flutter/material.dart';
import 'package:tik_tok_wikipidiea/screens/home/infinite_scroll.dart';
import 'package:tik_tok_wikipidiea/screens/profile/profile_page.dart';
import 'package:tik_tok_wikipidiea/screens/search/search_screen.dart';

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({Key? key}) : super(key: key);

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int _selectedIndex = 1; // Default to Home tab (index 1)

  static final List<Widget> _screens = [
    // Search Screen (placeholder)
    Search_screen(),
    // Home Screen
    ScrollScreen(),
    // Profile Screen (placeholder)
    ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get theme brightness to adapt UI accordingly
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Theme(
        // Create a localized theme for the bottom nav that matches the main theme
        data: Theme.of(context).copyWith(
          // This ensures the nav bar background color matches properly
          canvasColor: Theme.of(context).scaffoldBackgroundColor,
        ),
        child: BottomNavigationBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          // Use primary color for selected item (from theme)
          selectedItemColor: Theme.of(context).primaryColor,
          // Use themed color for unselected items
          unselectedItemColor: isDarkMode ? Colors.white60 : Colors.black54,
          // Add elevation for shadow effect
          elevation: 8,
          // Add indicator for selected item
          type: BottomNavigationBarType.fixed,
          // Optional: add background for better visibility with light theme
          selectedLabelStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: TextStyle(fontSize: 12),
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
