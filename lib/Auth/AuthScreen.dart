import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool isLogin = true;
  bool _obscurePassword = true;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final Map<String, String> _authData = {
    'name': '',
    'email': '',
    'phone': '',
    'password': '',
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
    });

    final baseUrl = 'replace here url';
    try {
      if (isLogin) {
        final response = await http.post(
          Uri.parse('$baseUrl/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'email': _authData['email'],
            'password': _authData['password'],
          }),
        );

        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          print("responseData is   ${responseData}");
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', responseData['access_token']);
          await prefs.setString('refresh_token', responseData['refresh_token']);
          await prefs.setString(
            'user_id',
            responseData['user']['id'].toString(),
          );
          await prefs.setString('username', responseData['user']['username']);
          await prefs.setString('role', responseData['user']['role']);

          // Print for debugging
          print('User ID: ${responseData['user']['id'].toString()}');

          final userResponse = await http.get(
            Uri.parse('$baseUrl/auth/me'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${responseData['access_token']}',
            },
          );

          if (userResponse.statusCode == 200) {}
        } else {
          throw Exception(json.decode(response.body)['error']);
        }
      } else {
        final signupEndpoint = '$baseUrl/auth/register';

        final signupData = {
          'username': _authData['name'],
          'email': _authData['email'],
          'mobno': _authData['phone'],
          'password': _authData['password'],
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
              ),
            ),
          );
          setState(() {
            isLogin = true;
          });
        } else {
          print(json.decode(response.body)['error']);
          throw Exception(json.decode(response.body)['error']);
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final cardColor = isDarkMode ? Color.fromRGBO(30, 30, 35, 1) : Colors.white;
    final textTheme = Theme.of(context).textTheme;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors:
                isDarkMode
                    ? [
                      Color.fromRGBO(20, 20, 25, 1),
                      Color.fromRGBO(30, 30, 40, 1),
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
                                ? Colors.grey.withOpacity(0.1)
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
                                  isLogin ? Icons.emoji_emotions_outlined : Icons.app_registration,
                                  size: 40,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              isLogin ? 'Welcome Back' : 'Create Account',
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                                fontSize: 22,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              isLogin
                                  ? 'Sign in to continue'
                                  : 'Register to start',
                              textAlign: TextAlign.center,
                              style: textTheme.bodySmall?.copyWith(
                                color:
                                    isDarkMode
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
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
                                      onSaved:
                                          (value) => _authData['name'] = value!,
                                      isDarkMode: isDarkMode,
                                      primaryColor: primaryColor,
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
                                    isDarkMode: isDarkMode,
                                    primaryColor: primaryColor,
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
                                      isDarkMode: isDarkMode,
                                      primaryColor: primaryColor,
                                    ),
                                  if (!isLogin) SizedBox(height: 12),
                                  _buildPasswordField(
                                    isDarkMode: isDarkMode,
                                    primaryColor: primaryColor,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _submit,
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
                                  style: TextStyle(
                                    color:
                                        isDarkMode
                                            ? Colors.grey[400]
                                            : Colors.grey[600],
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
    required bool isDarkMode,
    required Color primaryColor,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    void Function(String?)? onSaved,
  }) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryColor, size: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            width: 1,
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            width: 1,
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(width: 1.5, color: primaryColor),
        ),
        filled: true,
        fillColor:
            isDarkMode ? Colors.grey[800]!.withOpacity(0.5) : Colors.grey[50]!,
        labelStyle: TextStyle(
          color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
          fontSize: 13,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
      style: TextStyle(
        color: isDarkMode ? Colors.white : Colors.black87,
        fontSize: 14,
      ),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      onSaved: onSaved,
    );
  }

  Widget _buildPasswordField({
    required bool isDarkMode,
    required Color primaryColor,
  }) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: Icon(Icons.lock_outline, color: primaryColor, size: 18),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
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
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            width: 1,
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(width: 1.5, color: primaryColor),
        ),
        filled: true,
        fillColor:
            isDarkMode ? Colors.grey[800]!.withOpacity(0.5) : Colors.grey[50]!,
        labelStyle: TextStyle(
          color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
          fontSize: 13,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
      style: TextStyle(
        color: isDarkMode ? Colors.white : Colors.black87,
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