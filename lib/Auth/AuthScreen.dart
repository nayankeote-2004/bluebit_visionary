import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:tik_tok_wikipidiea/navigations/bottom_navbar.dart';
import 'package:tik_tok_wikipidiea/screens/UserInterest/userInterest.dart';
import 'package:tik_tok_wikipidiea/services/theme_render.dart';

import '../config.dart';
import '../screens/UserInterest/userInterest.dart';

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool isLogin = true;
  bool _obscurePassword = true;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Add ThemeService instance
  final ThemeService _themeService = ThemeService();

  final Map<String, String> _authData = {
    'name': '',
    'email': '',
    'phone': '',
    'password': '',
    'bio': '', // Add bio to auth data
  };

  @override
  void initState() {
    super.initState();
    // Add observer to detect system theme changes
    WidgetsBinding.instance.addObserver(this);

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();

    // Listen for theme changes from ThemeService
    _themeService.addListener((themeMode) => _themeListener(themeMode));
  }

  void _themeListener(ThemeMode themeMode) {
    // Force rebuild when theme changes
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangePlatformBrightness() {
    // This is called whenever the system brightness changes
    if (mounted) {
      setState(() {});
    }
    super.didChangePlatformBrightness();
  }

  @override
  void dispose() {
    // Remove observer and listener
    WidgetsBinding.instance.removeObserver(this);
    _themeService.removeListener(_themeListener);
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
    });

    final baseUrl = Config.baseUrl;
    try {
      if (isLogin) {
        final response = await http.post(
          Uri.parse('$baseUrl/login'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'email': _authData['email'],
            'password': _authData['password'],
          }),
        );

        print("_authData is ${_authData}");

        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          print("responseData is   ${responseData}");

          final prefs = await SharedPreferences.getInstance();

          await prefs.setString('username', responseData['user']['fullName']);
          await prefs.setString('email', responseData['user']['email']);
          await prefs.setString('mobno', responseData['user']['phone']);
          await prefs.setString('bio', responseData['user']['bio']);

          await prefs.setString('userId', responseData['user']['userId']);

          // Store interested domains as a JSON string
          await prefs.setString(
            'interestedDomains',
            json.encode(responseData['user']['interestedDomains']),
          );

          // In UserInterestPage after saving to SharedPreferences:
          print('Saved interests to SharedPreferences: ${prefs.getString('interestedDomains')}');

          // Store interactions as a JSON string
          await prefs.setString(
            'userInteractions',
            json.encode(responseData['user']['interactions']),
          );
          
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => BottomNavBar()),
          );
        } else {
          throw json.decode(response.body)['message'];
        }
      }
    } catch (error) {
      showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: Text('Error'),
              content: Text(error.toString()),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              actions: [
                TextButton(
                  child: Text('Okay'),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _switchAuthMode() {
    setState(() {
      isLogin = !isLogin;
    });
    _animationController.reset();
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    // Get the system brightness
    final systemBrightness =
        View.of(context).platformDispatcher.platformBrightness;

    // Get theme mode from ThemeService (will follow system if not explicitly set)
    final themeMode = _themeService.themeMode;

    // Get theme details from the ThemeData in main.dart
    final theme = Theme.of(context);

    // Determine if we're in dark mode based on theme
    final isDarkMode =
        themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && systemBrightness == Brightness.dark);

    // Continue with your existing code
    final primaryColor = theme.primaryColor;
    final cardColor = theme.cardColor;
    final textTheme = theme.textTheme;
    final iconTheme = theme.iconTheme;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      // Use scaffold background color from theme
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors:
                isDarkMode
                    ? [
                      Color(
                        0xFF101010,
                      ), // Darker version of dark scaffold background
                      Color(0xFF1A1A1A), // Slightly lighter dark background
                    ]
                    : [
                      primaryColor.withOpacity(0.05),
                      primaryColor.withOpacity(0.15),
                    ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth < 360 ? 12.0 : 16.0,
                  vertical: 12.0,
                ),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Card(
                    elevation: 8,
                    color: cardColor,
                    shadowColor:
                        isDarkMode
                            ? Colors.black.withOpacity(0.6)
                            : Colors.grey.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color:
                            isDarkMode
                                ? theme
                                    .dividerColor // Use dividerColor from theme
                                : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Container(
                      width: double.infinity,
                      constraints: BoxConstraints(maxWidth: 400),
                      padding: EdgeInsets.all(screenWidth < 360 ? 16.0 : 20.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Hero(
                              tag: 'app_icon',
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isLogin
                                      ? Icons.emoji_emotions_outlined
                                      : Icons.app_registration,
                                  size: 40,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              isLogin ? 'Welcome Back' : 'Create Account',
                              style: textTheme.displayMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              isLogin
                                  ? 'Sign in to continue'
                                  : 'Register to start',
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium?.copyWith(
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 20),
                            AnimatedContainer(
                              duration: Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              child: Column(
                                children: [
                                  if (!isLogin)
                                    _buildTextField(
                                      label: 'Full Name',
                                      icon: Icons.person_outline,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter your name';
                                        }
                                        return null;
                                      },
                                      onSaved: (value) {
                                        _authData['name'] = value!;
                                        print(_authData['name']);
                                      },
                                      theme: theme,
                                    ),
                                  if (!isLogin) SizedBox(height: 12),
                                  _buildTextField(
                                    label: 'Email Address',
                                    icon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (value) {
                                      if (value == null ||
                                          !value.contains('@')) {
                                        return 'Invalid email';
                                      }
                                      return null;
                                    },
                                    onSaved:
                                        (value) => _authData['email'] = value!,
                                    theme: theme,
                                  ),
                                  SizedBox(height: 12),
                                  if (!isLogin)
                                    _buildTextField(
                                      label: 'Phone Number',
                                      icon: Icons.phone_outlined,
                                      keyboardType: TextInputType.phone,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(10),
                                      ],
                                      validator: (value) {
                                        if (value == null ||
                                            value.length < 10) {
                                          return 'Invalid phone number';
                                        }
                                        return null;
                                      },
                                      onSaved:
                                          (value) =>
                                              _authData['phone'] = value!,
                                      theme: theme,
                                    ),
                                  if (!isLogin) SizedBox(height: 12),
                                  // Add Bio Field when signing up
                                  if (!isLogin)
                                    _buildTextField(
                                      label: 'Bio',
                                      icon: Icons.description_outlined,
                                      keyboardType: TextInputType.multiline,
                                      maxLines: 2,
                                      hint: 'Tell us a bit about yourself',
                                      validator: (value) {
                                        // Bio is optional
                                        return null;
                                      },
                                      onSaved:
                                          (value) =>
                                              _authData['bio'] = value ?? '',
                                      theme: theme,
                                    ),
                                  if (!isLogin) SizedBox(height: 12),
                                  _buildPasswordField(theme: theme),
                                ],
                              ),
                            ),
                            SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: ElevatedButton(
                                // onPressed: _isLoading ? null : _submit,
                                onPressed: () async {
                                  if (_isLoading) return;

                                  if (_formKey.currentState!.validate()) {
                                    _formKey.currentState!
                                        .save(); // This saves the form data to _authData

                                    if (isLogin) {
                                      await _submit();
                                    } else {
                                      Navigator.of(context).pushReplacement(
                                        MaterialPageRoute(
                                          builder:
                                              (context) => UserInterestPage(
                                                authData: Map<
                                                  String,
                                                  String
                                                >.from(
                                                  _authData,
                                                ), // Create a new map from _authData
                                              ),
                                        ),
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                  shadowColor: primaryColor.withOpacity(0.4),
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                ),
                                child:
                                    _isLoading
                                        ? SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : Text(
                                          isLogin ? 'LOGIN' : 'SIGN UP',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                              ),
                            ),
                            SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  isLogin
                                      ? 'Don\'t have an account?'
                                      : 'Already have an account?',
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontSize: 13,
                                  ),
                                ),
                                TextButton(
                                  onPressed: _switchAuthMode,
                                  style: TextButton.styleFrom(
                                    foregroundColor: primaryColor,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  child: Text(
                                    isLogin ? 'Sign Up' : 'Login',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
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
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    required ThemeData theme,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    void Function(String?)? onSaved,
    String? hint,
    int? maxLines = 1,
  }) {
    final isDarkMode = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;

    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: primaryColor, size: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            width: 1,
            color: theme.dividerColor, // Use dividerColor from theme
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            width: 1,
            color: theme.dividerColor, // Use dividerColor from theme
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(width: 1.5, color: primaryColor),
        ),
        filled: true,
        fillColor:
            isDarkMode
                ? Color(
                  0xFF1E1E1E,
                ) // Slightly lighter than card color in dark mode
                : Colors.grey[50],
        labelStyle: TextStyle(
          color: theme.textTheme.bodyMedium?.color, // Use text color from theme
          fontSize: 13,
        ),
        hintStyle: TextStyle(color: theme.hintColor, fontSize: 13),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
      style: TextStyle(
        color: theme.textTheme.bodyLarge?.color, // Use text color from theme
        fontSize: 14,
      ),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      onSaved: onSaved,
      maxLines: maxLines,
    );
  }

  Widget _buildPasswordField({required ThemeData theme}) {
    final isDarkMode = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;

    return TextFormField(
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: Icon(Icons.lock_outline, color: primaryColor, size: 18),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: theme.iconTheme.color, // Use icon color from theme
            size: 18,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(),
          visualDensity: VisualDensity.compact,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            width: 1,
            color: theme.dividerColor, // Use dividerColor from theme
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            width: 1,
            color: theme.dividerColor, // Use dividerColor from theme
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(width: 1.5, color: primaryColor),
        ),
        filled: true,
        fillColor:
            isDarkMode
                ? Color(
                  0xFF1E1E1E,
                ) // Slightly lighter than card color in dark mode
                : Colors.grey[50],
        labelStyle: TextStyle(
          color: theme.textTheme.bodyMedium?.color, // Use text color from theme
          fontSize: 13,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
      style: TextStyle(
        color: theme.textTheme.bodyLarge?.color, // Use text color from theme
        fontSize: 14,
      ),
      obscureText: _obscurePassword,
      validator: (value) {
        if (value == null || value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
      onSaved: (value) => _authData['password'] = value!,
    );
  }
}
