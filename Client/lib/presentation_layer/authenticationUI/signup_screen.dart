import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../services/auth_storage.dart';
import '../profileUI/widgets/assesmentWidgets/pre_assessment_intro_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
    String get baseUrl {
      if (kIsWeb) {
        return 'http://127.0.0.1:8000';
      }

      return 'http://10.0.2.2:8000';
    }
  static const Color darkGreen = Color(0xFF1F5F5A);
  static const Color lightGreen = Color(0xFF6FA7A3);
  static const Color background = Color(0xFFFFFBF6);
  static const Color darkText = Color(0xFF2E3A38);
  static const Color borderColor = Color(0xFFDDE8E6);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  bool _clearConfirmPasswordOnNextFocus = false;

  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  bool _showPasswordRequirements = false;
  bool _isLoading = false;

  String? _selectedGender;

  @override
  void initState() {
    super.initState();

    _passwordFocusNode.addListener(() {
      if (!mounted) {
        return;
      }

      setState(() {
        _showPasswordRequirements = _passwordFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();

    super.dispose();
  }

  bool get _hasEightCharacters {
    return _passwordController.text.length >= 8;
  }

  bool get _hasUppercase {
    return RegExp(r'[A-Z]').hasMatch(_passwordController.text);
  }

  bool get _hasLowercase {
    return RegExp(r'[a-z]').hasMatch(_passwordController.text);
  }

  bool get _hasNumber {
    return RegExp(r'[0-9]').hasMatch(_passwordController.text);
  }

  bool get _hasSpecialCharacter {
    return RegExp(r'[!@#$%^&*]').hasMatch(_passwordController.text);
  }

  bool get _passwordIsValid {
    return _hasEightCharacters &&
        _hasUppercase &&
        _hasLowercase &&
        _hasNumber &&
        _hasSpecialCharacter;
  }

  bool get _passwordsMatch {
    return _passwordController.text == _confirmPasswordController.text;
  }

  Future<void> _createAccount() async {
    FocusScope.of(context).unfocus();

    final formIsValid = _formKey.currentState?.validate() ?? false;

    if (!formIsValid) {
      return;
    }

    if (_selectedGender == null) {
      _showMessage('يرجى اختيار الجنس');

      return;
    }

    setState(() {
      _isLoading = true;
    });

    final normalizedEmail = _emailController.text.trim().toLowerCase();

    try {
      final signupResponse = await http.post(
        Uri.parse('$baseUrl/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': _nameController.text.trim(),
          'email': normalizedEmail,
          'password': _passwordController.text,
          'confirm_password': _confirmPasswordController.text,
          'phone_number': _phoneController.text.trim(),
          'age': int.parse(_ageController.text.trim()),
          'gender': _selectedGender,
        }),
      );

      if (signupResponse.statusCode < 200 || signupResponse.statusCode >= 300) {
        _showMessage(
          _readErrorMessage(signupResponse, fallback: 'تعذر إنشاء الحساب'),
        );

        return;
      }

      // Log the new user in automatically.
      final loginResponse = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': normalizedEmail,
          'password': _passwordController.text,
        }),
      );

      if (loginResponse.statusCode < 200 || loginResponse.statusCode >= 300) {
        _showMessage(
          _readErrorMessage(
            loginResponse,
            fallback: 'تم إنشاء الحساب، ولكن تعذر تسجيل الدخول',
          ),
        );

        return;
      }

      final loginData = jsonDecode(loginResponse.body) as Map<String, dynamic>;

      final token = loginData['access_token'] as String?;

      if (token == null || token.isEmpty) {
        _showMessage('لم يرسل الخادم رمز تسجيل الدخول');

        return;
      }

      await AuthStorage.saveToken(token);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const PreAssessmentIntroScreen(),
        ),
        (route) => false,
      );
    } catch (error) {
      _showMessage('تعذر الاتصال بالخادم. تأكد من تشغيل الخادم .');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _readErrorMessage(http.Response response, {required String fallback}) {
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      final detail = decoded['detail'];

      if (detail is String) {
        return _translateBackendError(detail);
      }

      if (detail is List && detail.isNotEmpty) {
        final firstError = detail.first;

        if (firstError is Map<String, dynamic>) {
          return firstError['msg']?.toString() ?? fallback;
        }
      }
    } catch (_) {
      // Use the fallback message if the server response is not JSON.
    }

    return fallback;
  }

  String _translateBackendError(String message) {
    switch (message) {
      case 'Email already registered':
        return 'البريد الإلكتروني مسجل مسبقًا';

      case 'Passwords do not match.':
      case 'Passwords do not match':
        return 'كلمتا المرور غير متطابقتين';

      case 'Password must be at least 8 characters long.':
        return 'يجب أن تتكون كلمة المرور من 8 أحرف على الأقل';

      case 'Password must contain at least one uppercase letter.':
        return 'يجب أن تحتوي كلمة المرور على حرف كبير';

      case 'Password must contain at least one lowercase letter.':
        return 'يجب أن تحتوي كلمة المرور على حرف صغير';

      case 'Password must contain at least one number.':
        return 'يجب أن تحتوي كلمة المرور على رقم';

      case 'Password must contain at least one special character.':
        return 'يجب أن تحتوي كلمة المرور على رمز خاص';

      default:
        return message;
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, textDirection: TextDirection.rtl),
          backgroundColor: Colors.red.shade700,
        ),
      );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: lightGreen),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: darkGreen, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  Widget _requirement(String text, bool isSatisfied) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            isSatisfied ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isSatisfied ? darkGreen : Colors.grey,
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isSatisfied ? darkGreen : Colors.grey.shade700,
                fontSize: 14,
                fontWeight: isSatisfied ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _genderChoice({required String label, required String value}) {
    final isSelected = _selectedGender == value;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedGender = value;
          });
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 55,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? darkGreen : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? darkGreen : borderColor,
              width: 1.3,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : darkText,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          elevation: 0,
          foregroundColor: darkText,
          title: const Text(
            'إنشاء حساب',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 35),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'مرحبًا بك في طليق',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: darkText,
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'أنشئ حسابك للبدء في رحلة تحسين طلاقة الكلام',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: lightGreen,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),

                  TextFormField(
                    controller: _nameController,
                    keyboardType: TextInputType.name,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    textInputAction: TextInputAction.next,
                    decoration: _fieldDecoration(
                      label: 'الاسم',
                      icon: Icons.person_outline_rounded,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'يرجى إدخال الاسم';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: _fieldDecoration(
                      label: 'البريد الإلكتروني',
                      icon: Icons.email_outlined,
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';

                      if (email.isEmpty) {
                        return 'يرجى إدخال البريد الإلكتروني';
                      }

                      final emailIsValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                          .hasMatch(email);

                      if (!emailIsValid) {
                        return 'البريد الإلكتروني غير صحيح';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                    textInputAction: TextInputAction.next,
                    decoration: _fieldDecoration(
                      label: 'رقم الهاتف',
                      icon: Icons.phone_outlined,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'يرجى إدخال رقم الهاتف';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                    textInputAction: TextInputAction.next,
                    decoration: _fieldDecoration(
                      label: 'العمر',
                      icon: Icons.cake_outlined,
                    ),
                    validator: (value) {
                      final age = int.tryParse(value?.trim() ?? '');

                      if (age == null) {
                        return 'يرجى إدخال عمر صحيح';
                      }

                      if (age <= 0 || age > 120) {
                        return 'يرجى إدخال عمر صحيح';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  const Text(
                    'الجنس',
                    style: TextStyle(
                      color: darkText,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 9),

                  Row(
                    children: [
                      _genderChoice(label: 'أنثى', value: 'female'),
                      const SizedBox(width: 12),
                      _genderChoice(label: 'ذكر', value: 'male'),
                    ],
                  ),
                  const SizedBox(height: 18),

                  TextFormField(
                    controller: _passwordController,
                    textAlign: TextAlign.right,
                    focusNode: _passwordFocusNode,
                    obscureText: _hidePassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    textDirection: TextDirection.ltr,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) {
                      setState(() {});
                    },
                    decoration: _fieldDecoration(
                      label: 'كلمة المرور',
                      icon: Icons.lock_outline_rounded,
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
                          color: lightGreen,
                        ),
                      ),
                    ),
                    validator: (_) {
                      if (!_passwordIsValid) {
                        return 'كلمة المرور لا تستوفي جميع الشروط';
                      }

                      return null;
                    },
                  ),

                  // This card is visible only while the password
                  // field has focus.
                  if (_showPasswordRequirements) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F7F6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'متطلبات كلمة المرور',
                            style: TextStyle(
                              color: darkText,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 7),
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

                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _confirmPasswordController,
                    focusNode: _confirmPasswordFocusNode,
                    obscureText: _hideConfirmPassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                    textInputAction: TextInputAction.done,

                    onTap: () {
                      if (_clearConfirmPasswordOnNextFocus) {
                        _confirmPasswordController.clear();

                        setState(() {
                          _clearConfirmPasswordOnNextFocus = false;
                        });
                      }
                    },

                    onChanged: (_) {
                      setState(() {});
                    },

                    onFieldSubmitted: (_) {
                      if (!_isLoading) {
                        _createAccount();
                      }
                    },

                    decoration: _fieldDecoration(
                      label: 'تأكيد كلمة المرور',
                      icon: Icons.lock_reset_rounded,
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
                          color: lightGreen,
                        ),
                      ),
                    ),

                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'يرجى تأكيد كلمة المرور';
                      }

                      if (!_passwordsMatch) {
                        _clearConfirmPasswordOnNextFocus = true;

                        return 'كلمتا المرور غير متطابقتين';
                      }

                      _clearConfirmPasswordOnNextFocus = false;

                      return null;
                    },
                  ),
                  const SizedBox(height: 27),

                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: darkGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: darkGreen.withValues(
                          alpha: 0.55,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
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
                              'إنشاء الحساب',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
