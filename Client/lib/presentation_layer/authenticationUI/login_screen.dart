// Converts between Dart objects and JSON text.
import 'dart:convert';

// Flutter interface components.
import 'package:flutter/material.dart';

// Sends HTTP requests to the FastAPI backend.
import 'package:http/http.dart' as http;

// Existing service that stores the access token securely.
import '../../data_and_integration_layer/services/auth_storage.dart';

// Existing screens used by the Login screen.
import '../profileUI/profile_screen.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Used to validate all form fields together.
  final _formKey = GlobalKey<FormState>();

  // These controllers read the text entered by the user.
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Controls the loading indicator and password visibility.
  bool _isLoading = false;
  bool _hidePassword = true;

  // Reusable colors matching the Welcome and Signup screens.
  static const Color _teal = Color(0xFF1F5F5A);
  static const Color _background = Color(0xFFFFFBF6);

  @override
  void dispose() {
    // Releases the controllers when this screen is removed.
    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  Future<void> _login() async {
    // Runs the validator belonging to each TextFormField.
    final formIsValid = _formKey.currentState?.validate() ?? false;

    // Stop if email or password is invalid.
    if (!formIsValid) {
      return;
    }

    // Disable the button and display the loading circle.
    setState(() {
      _isLoading = true;
    });

    // Normalize the email exactly like Signup so capitalization does not
    // affect login. For example, Test@gmail.com becomes test@gmail.com.
    final normalizedEmail = _emailController.text.trim().toLowerCase();

    try {
      // Send the entered email and password to FastAPI.
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8000/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': normalizedEmail,
          'password': _passwordController.text,
        }),
      );

      // Stop if the user closed this screen while awaiting the server.
      if (!mounted) {
        return;
      }

      if (response.statusCode == 200) {
        // Convert the server's JSON response into a Dart map.
        final responseData = jsonDecode(response.body);

        // Read the access token returned by FastAPI.
        final String? token = responseData['access_token']?.toString();

        if (token == null || token.isEmpty) {
          _showMessage('لم يُرجع الخادم رمز تسجيل الدخول');
          return;
        }

        // Save the token securely on the device.
        await AuthStorage.saveToken(token);

        if (!mounted) {
          return;
        }

        // Open Profile and remove the authentication screens
        // from the navigation history.
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
          (route) => false,
        );
      } else {
        // Default message if FastAPI rejects the login.
        String message = 'تعذر تسجيل الدخول';

        try {
          final responseData = jsonDecode(response.body);

          // FastAPI normally returns its message inside "detail".
          if (responseData is Map && responseData['detail'] != null) {
            message = responseData['detail'].toString();
          }
        } catch (_) {
          // Keep the default message if the response is not JSON.
        }

        _showMessage(message);
      }
    } catch (_) {
      // Runs if the application cannot reach FastAPI at all.
      _showMessage('تعذر الاتصال بالخادم. تأكدي من تشغيل الـ Backend.');
    } finally {
      // Re-enable the Login button after the request finishes.
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    // Shows a temporary message at the bottom of the screen.
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message), backgroundColor: _teal));
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    // This function gives both fields the same design.
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _teal),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE1EEEC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _teal, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,

      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _teal),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),

          child: Form(
            key: _formKey,

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset('assets/images/taleeq_logo.png', height: 145),

                const SizedBox(height: 20),

                const Text(
                  'تسجيل الدخول',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF263936),
                    fontSize: 29,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'مرحبًا بعودتك إلى طليق',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF86A7A2), fontSize: 16),
                ),

                const SizedBox(height: 32),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _fieldDecoration(
                    label: 'البريد الإلكتروني',
                    icon: Icons.email_outlined,
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';

                    if (email.isEmpty) {
                      return 'يرجى إدخال البريد الإلكتروني';
                    }

                    if (!email.contains('@')) {
                      return 'يرجى إدخال بريد إلكتروني صحيح';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordController,
                  obscureText: _hidePassword,
                  decoration: _fieldDecoration(
                    label: 'كلمة المرور',
                    icon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _hidePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: _teal,
                      ),
                      onPressed: () {
                        setState(() {
                          _hidePassword = !_hidePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'يرجى إدخال كلمة المرور';
                    }

                    return null;
                  },
                ),

                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'نسيت كلمة المرور؟',
                      style: TextStyle(color: _teal),
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                SizedBox(
                  height: 58,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'تسجيل الدخول',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('ليس لديك حساب؟'),

                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignupScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'إنشاء حساب',
                        style: TextStyle(
                          color: _teal,
                          fontWeight: FontWeight.bold,
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
  }
}
