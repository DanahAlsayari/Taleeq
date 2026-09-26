import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Taleeq Design Colors
  static const Color ivory = Color(0xFFFCFAF6);
  static const Color teal = Color(0xFF1F5F5A);
  static const Color tealLight = Color(0xFF2A7A74);
  static const Color aquaLight = Color(0xFFEAF4F2);
  static const Color dark = Color(0xFF233330);
  static const Color muted = Color(0xFF8FA39F);
  static const Color border = Color(0xFFE3EEEB);
  static const Color errorRed = Color(0xFFD9534F);

  Future<void> _sendResetLink() async {
    final email = _emailController.text.trim().toLowerCase();
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    if (email.isEmpty ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() {
        _errorMessage = 'يرجى إدخال بريد إلكتروني صحيح.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(
          '${kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000'}/auth/forgot-password',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _successMessage =
              'تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني.';
        });
      } else {
        setState(() {
          _errorMessage = 'تعذر إرسال الرابط. يرجى المحاولة مرة أخرى.';
        });
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'تعذر الاتصال بالخادم. يرجى المحاولة مرة أخرى.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: ivory,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: border, width: 2),
                    ),
                    child: IconButton(
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: dark,
                        size: 21,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 80),

                // Email + Lock Illustration
                Center(
                  child: Container(
                    width: 130,
                    height: 110,
                    decoration: BoxDecoration(
                      color: aquaLight,
                      borderRadius: BorderRadius.circular(45),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(
                          Icons.mail_rounded,
                          size: 68,
                          color: tealLight,
                        ),
                        Positioned(
                          bottom: 10,
                          left: 18,
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: const BoxDecoration(
                              color: teal,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                const Text(
                  'نسيت كلمة المرور؟',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: dark,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Cairo',
                  ),
                ),

                const SizedBox(height: 14),

                const Text(
                  'أدخل بريدك الإلكتروني وسنرسل لك رابطًا\n'
                  'لإعادة تعيين كلمة المرور.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: muted,
                    fontSize: 16,
                    height: 1.8,
                    fontFamily: 'Cairo',
                  ),
                ),

                const SizedBox(height: 42),

                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.rtl,
                  onChanged: (_) {
                    if (_errorMessage != null || _successMessage != null) {
                      setState(() {
                        _errorMessage = null;
                        _successMessage = null;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'البريد الإلكتروني',
                    hintStyle: const TextStyle(
                      color: muted,
                      fontFamily: 'Cairo',
                    ),
                    prefixIcon: const Icon(Icons.email_outlined, color: muted),
                    filled: true,
                    fillColor: aquaLight,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 21,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(
                        color: _errorMessage != null
                            ? errorRed
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(
                        color: _errorMessage != null ? errorRed : teal,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 9),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: errorRed,
                      fontSize: 13,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],

                if (_successMessage != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: teal,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: const TextStyle(
                            color: teal,
                            fontSize: 13,
                            height: 1.6,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 32),

                Container(
                  height: 62,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [teal, tealLight],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendResetLink,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'إرسال الرابط',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Cairo',
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 28),

                TextButton(
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text(
                    'العودة إلى تسجيل الدخول',
                    style: TextStyle(
                      color: teal,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
