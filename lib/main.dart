import 'package:flutter/material.dart';
import 'package:tik_tok_wikipidiea/Auth/AuthScreen.dart';
import 'package:tik_tok_wikipidiea/navigations/bottom_navbar.dart';
import 'package:tik_tok_wikipidiea/screens/infinite_scroll.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system, // Use system settings
      // Dark theme
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.blue,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.black,
        cardColor: Color(0xFF121212),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        textTheme: TextTheme(
          displayLarge: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          displayMedium: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          bodyLarge: TextStyle(color: Colors.white, fontSize: 20),
          bodyMedium: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        iconTheme: IconThemeData(color: Colors.white70),
        dividerColor: Colors.grey[800],
      ),

      // Light theme
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.blue,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        cardColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        textTheme: TextTheme(
          displayLarge: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
          displayMedium: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
          bodyLarge: TextStyle(color: Colors.black87, fontSize: 20),
          bodyMedium: TextStyle(color: Colors.black54, fontSize: 16),
        ),
        iconTheme: IconThemeData(color: Colors.black54),
        dividerColor: Colors.grey[300],
      ),

      home: AuthScreen(),
    );
  }
}
