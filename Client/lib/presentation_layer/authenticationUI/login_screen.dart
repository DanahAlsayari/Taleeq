// Converts between Dart objects and JSON text.
import 'dart:convert';

// Flutter interface components.
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// Sends HTTP requests to the FastAPI backend.
import 'package:http/http.dart' as http;

// Existing service that stores the access token securely.
import '../../services/auth_storage.dart';

// Existing screens used by the Login screen.
import '../profileUI/profile_screen.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';
import '../../services/api_config_service.dart';
import '../HomepageUI/home_screen.dart';

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
  bool _clearPasswordOnNextFocus = false;

  // Reusable colors matching the Welcome and Signup screens.
  static const Color _teal = Color(0xFF1F5F5A);
  static const Color _background = Color(0xFFFFFBF6);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final formIsValid =
        _formKey.currentState?.validate() ?? false;

    if (!formIsValid) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final normalizedEmail =
        _emailController.text.trim().toLowerCase();

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': normalizedEmail,
          'password': _passwordController.text,
        }),
      );

      if (!mounted) {
        return;
      }

      if (response.statusCode == 200) {
        final responseData =
            jsonDecode(response.body);

        final String? token =
            responseData['access_token']?.toString();

        if (token == null || token.isEmpty) {
          _showMessage(
            'لم يُرجع الخادم رمز تسجيل الدخول',
          );
          return;
        }

        await AuthStorage.saveToken(token);

        if (!mounted) {
          return;
        }

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) =>
                const HomeScreen(),
          ),
          (route) => false,
        );
      } else {
        String message;

        if (response.statusCode == 401) {
          message =
              'البريد الإلكتروني أو كلمة المرور غير صحيحة';
        } else if (response.statusCode == 422) {
          message =
              'يرجى التحقق من البيانات المدخلة';
        } else {
          message =
              'تعذر تسجيل الدخول. يرجى المحاولة مرة أخرى';
        }

        _clearPasswordOnNextFocus = true;
        _showMessage(message);
      }
    } catch (_) {
      _showMessage(
        'تعذر الاتصال بالخادم. تأكدي من تشغيل الـ Backend.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    const errorColor = Color(0xFFB55252);

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: errorColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      label: _requiredLabel(label),
      prefixIcon: Icon(
        icon,
        color: _teal,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Color(0xFFE1EEEC),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: _teal,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _requiredLabel(
    String text, {
    Color color = Colors.grey,
  }) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$text ',
            style: TextStyle(
              color: color,
            ),
          ),
          const TextSpan(
            text: '*',
            style: TextStyle(
              color: Color(0xFF6FA7A3),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.rtl,
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
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: _teal,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            24,
            10,
            24,
            30,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  'assets/images/taleeq_logo1.png',
                  height: 145,
                ),

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
                  style: TextStyle(
                    color: Color(0xFF86A7A2),
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 32),

                TextFormField(
                  controller: _emailController,
                  keyboardType:
                      TextInputType.emailAddress,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[\x21-\x7E]'),
                    ),
                  ],
                  decoration: _fieldDecoration(
                    label: 'البريد الإلكتروني',
                    icon: Icons.email_outlined,
                  ),
                  validator: (value) {
                    final email =
                        value?.trim() ?? '';

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
                  onTap: () {
                    if (_clearPasswordOnNextFocus) {
                      _passwordController.clear();

                      setState(() {
                        _clearPasswordOnNextFocus =
                            false;
                      });
                    }
                  },
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(
                        r'[A-Za-z0-9!@#$%^&*]',
                      ),
                    ),
                    LengthLimitingTextInputFormatter(
                      20,
                    ),
                  ],
                  decoration: _fieldDecoration(
                    label: 'كلمة المرور',
                    icon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _hidePassword
                            ? Icons
                                .visibility_off_outlined
                            : Icons
                                .visibility_outlined,
                        color: _teal,
                      ),
                      onPressed: () {
                        setState(() {
                          _hidePassword =
                              !_hidePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty) {
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
                          builder: (context) =>
                              const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'نسيت كلمة المرور؟',
                      style: TextStyle(
                        color: _teal,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                SizedBox(
                  height: 58,
                  child: ElevatedButton(
                    onPressed:
                        _isLoading ? null : _login,
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor: _teal,
                      foregroundColor:
                          Colors.white,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          18,
                        ),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child:
                                CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'تسجيل الدخول',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    const Text(
                      'ليس لديك حساب؟',
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator
                            .push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const SignupScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'إنشاء حساب',
                        style: TextStyle(
                          color: _teal,
                          fontWeight:
                              FontWeight.bold,
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