import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String token;

  const ResetPasswordScreen({super.key, required this.token});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  bool _isLoading = false;
  bool _showValidation = false;
  bool _showPasswordRequirements = false;

  String? _errorMessage;
  String? _successMessage;

  static const Color ivory = Color(0xFFFCFAF6);
  static const Color teal = Color(0xFF1F5F5A);
  static const Color tealLight = Color(0xFF2A7A74);
  static const Color aquaLight = Color(0xFFEAF4F2);
  static const Color dark = Color(0xFF233330);
  static const Color muted = Color(0xFF8FA39F);
  static const Color border = Color(0xFFE3EEEB);
  static const Color errorRed = Color(0xFFD9534F);

  @override
  void initState() {
    super.initState();

    _passwordFocusNode.addListener(() {
      if (!mounted) return;

      setState(() {
        _showPasswordRequirements = _passwordFocusNode.hasFocus;
      });
    });
  }

  bool get _hasEightCharacters => _passwordController.text.length >= 8;

  bool get _hasUppercase => RegExp(r'[A-Z]').hasMatch(_passwordController.text);

  bool get _hasLowercase => RegExp(r'[a-z]').hasMatch(_passwordController.text);

  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_passwordController.text);

  bool get _hasSpecialCharacter =>
      RegExp(r'[!@#$%^&*]').hasMatch(_passwordController.text);

  bool get _passwordIsValid =>
      _hasEightCharacters &&
      _hasUppercase &&
      _hasLowercase &&
      _hasNumber &&
      _hasSpecialCharacter;

  bool get _passwordsMatch =>
      _passwordController.text == _confirmPasswordController.text &&
      _confirmPasswordController.text.isNotEmpty;

  Future<void> _resetPassword() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _showValidation = true;
      _errorMessage = null;
      _successMessage = null;
    });

    if (!_passwordIsValid) {
      setState(() {
        _errorMessage = 'يرجى التأكد من استيفاء جميع شروط كلمة المرور.';
      });
      return;
    }

    if (!_passwordsMatch) {
      _confirmPasswordController.clear();

      setState(() {
        _errorMessage = 'كلمتا المرور غير متطابقتين.';
      });

      _confirmPasswordFocusNode.requestFocus();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8000/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': widget.token,
          'new_password': _passwordController.text,
          'confirm_password': _confirmPasswordController.text,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _successMessage = 'تم تغيير كلمة المرور بنجاح.';
          _errorMessage = null;
        });

        await Future.delayed(const Duration(seconds: 1));

        if (!mounted) return;

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );

        return;
      } else {
        String message = 'تعذر تغيير كلمة المرور. يرجى المحاولة مرة أخرى.';

        try {
          final data = jsonDecode(response.body);
          message = data['detail']?.toString() ?? message;
        } catch (_) {
          // Keep the Arabic fallback if the response is not JSON.
        }

        setState(() {
          _errorMessage = message;
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

  Widget _requirement(String text, bool isValid) {
    final Color color;

    if (isValid) {
      color = teal;
    } else if (_showValidation) {
      color = errorRed;
    } else {
      color = muted;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool confirmError =
        _showValidation &&
        _confirmPasswordController.text.isNotEmpty &&
        !_passwordsMatch;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: ivory,
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                const SizedBox(height: 42),
                Center(
                  child: Container(
                    width: 120,
                    height: 105,
                    decoration: BoxDecoration(
                      color: aquaLight,
                      borderRadius: BorderRadius.circular(42),
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      size: 65,
                      color: teal,
                    ),
                  ),
                ),
                const SizedBox(height: 35),
                const Text(
                  'تعيين كلمة مرور جديدة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: dark,
                    fontSize: 29,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'أدخل كلمة المرور الجديدة لحسابك.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 16),
                ),
                const SizedBox(height: 35),
                TextField(
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  obscureText: _hidePassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                  onChanged: (_) {
                    setState(() {
                      _showValidation = false;
                      _errorMessage = null;
                      _successMessage = null;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'كلمة المرور الجديدة',
                    hintTextDirection: TextDirection.rtl,
                    hintStyle: const TextStyle(color: muted),
                    filled: true,
                    fillColor: aquaLight,
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _hidePassword = !_hidePassword;
                        });
                      },
                      icon: Icon(
                        _hidePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: muted,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(
                        color: _showValidation && !_passwordIsValid
                            ? errorRed
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(
                        color: _showValidation && !_passwordIsValid
                            ? errorRed
                            : teal,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                if (_showPasswordRequirements) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: aquaLight,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'يجب أن تحتوي كلمة المرور على:',
                          style: TextStyle(
                            color: dark,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _requirement('8 أحرف على الأقل', _hasEightCharacters),
                        _requirement(
                          'حرف كبير واحد على الأقل (A-Z)',
                          _hasUppercase,
                        ),
                        _requirement(
                          'حرف صغير واحد على الأقل (a-z)',
                          _hasLowercase,
                        ),
                        _requirement('رقم واحد على الأقل (0-9)', _hasNumber),
                        _requirement(
                          'رمز خاص واحد (! @ # \$ % ^ & *)',
                          _hasSpecialCharacter,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  focusNode: _confirmPasswordFocusNode,
                  obscureText: _hideConfirmPassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                  onChanged: (_) {
                    setState(() {
                      _errorMessage = null;
                      _successMessage = null;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'تأكيد كلمة المرور',
                    hintTextDirection: TextDirection.rtl,
                    hintStyle: const TextStyle(color: muted),
                    filled: true,
                    fillColor: aquaLight,
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _hideConfirmPassword = !_hideConfirmPassword;
                        });
                      },
                      icon: Icon(
                        _hideConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: muted,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(
                        color: confirmError ? errorRed : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(
                        color: confirmError ? errorRed : teal,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                if (confirmError) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'كلمتا المرور غير متطابقتين.',
                    style: TextStyle(color: errorRed, fontSize: 13),
                  ),
                ],
                if (_errorMessage != null) ...[
                  const SizedBox(height: 15),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: errorRed, fontSize: 13),
                  ),
                ],
                if (_successMessage != null) ...[
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: teal,
                        size: 21,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _successMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: teal,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 25),
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
                    onPressed: _isLoading ? null : _resetPassword,
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
                            'تعيين كلمة المرور',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
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
