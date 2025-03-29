import 'package:flutter/material.dart';
import 'package:tik_tok_wikipidiea/screens/splash_screen.dart';
import 'package:tik_tok_wikipidiea/services/theme_render.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:tik_tok_wikipidiea/services/connectivity_service.dart';
import 'package:tik_tok_wikipidiea/services/notification_service.dart';
import 'package:tik_tok_wikipidiea/services/permission_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize WebView platform based on operating system
  WebViewPlatform.instance = AndroidWebViewPlatform();

  // Initialize notification service
  await NotificationService.initialize();

  // Initialize theme service
  final themeService = ThemeService();
  await themeService.init();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeService _themeService = ThemeService();
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _themeMode = _themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light;
    _themeService.addListener(_themeListener);
  }

  @override
  void dispose() {
    _themeService.removeListener(_themeListener);
    super.dispose();
  }

  void _themeListener(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use StreamBuilder to rebuild the app when connectivity changes
    return StreamBuilder<bool>(
      stream: ConnectivityService().connectivityStream,
      builder: (context, snapshot) {
        // App will rebuild when connectivity changes
        return MaterialApp(
          title: 'Wiki Tok',
          debugShowCheckedModeBanner: false,
          themeMode: _themeMode, // Use manually selected theme mode
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
            switchTheme: SwitchThemeData(
              thumbColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return Colors.blue;
                }
                return Colors.grey;
              }),
              trackColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return Colors.blue.withOpacity(0.5);
                }
                return Colors.grey.withOpacity(0.5);
              }),
            ),
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
            switchTheme: SwitchThemeData(
              thumbColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return Colors.blue;
                }
                return Colors.grey;
              }),
              trackColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return Colors.blue.withOpacity(0.5);
                }
                return Colors.grey.withOpacity(0.3);
              }),
            ),
          ),

          home: PermissionInitializerWidget(child: SplashScreen()),
        );
      },
    );
  }
}

// Widget to handle permission initialization
class PermissionInitializerWidget extends StatefulWidget {
  final Widget child;

  const PermissionInitializerWidget({Key? key, required this.child})
    : super(key: key);

  @override
  _PermissionInitializerWidgetState createState() =>
      _PermissionInitializerWidgetState();
}

class _PermissionInitializerWidgetState
    extends State<PermissionInitializerWidget> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializePermissions();
  }

  Future<void> _initializePermissions() async {
    // Wait a moment to ensure the app is fully rendered
    await Future.delayed(Duration(milliseconds: 500));
    // Request permissions
    await PermissionService.requestInitialPermissions(context);
    await _requestNotificationPermission();

    if (mounted) {
      setState(() {
        _initialized = true;
      });
    }
  }

  // Request notification permission for Android 13+
  Future<void> _requestNotificationPermission() async {
    if (Platform.isAndroid) {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        // Android 13+
        await Permission.notification.request();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
