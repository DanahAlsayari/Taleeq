import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../../services/auth_storage.dart';
import '../widgets/assesmentWidgets/pre_assessment_intro_screen.dart';
import '../../services/api_config_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
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

  bool _clearPasswordsOnNextFocus = false;

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

  void _clearPasswordsForRetry() {
    if (!_clearPasswordsOnNextFocus) {
      return;
    }

    _passwordController.clear();
    _confirmPasswordController.clear();

    setState(() {
      _clearPasswordsOnNextFocus = false;
    });
  }

  Future<void> _createAccount() async {
    FocusScope.of(context).unfocus();

    final formIsValid = _formKey.currentState?.validate() ?? false;

    if (!formIsValid) {
      _clearPasswordsOnNextFocus = true;
      return;
    }

    if (_selectedGender == null) {
      _showMessage('ظٹط±ط¬ظ‰ ط§ط®طھظٹط§ط± ط§ظ„ط¬ظ†ط³');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final normalizedEmail = _emailController.text.trim().toLowerCase();

    try {
      // Create a new account.
      final signupResponse = await http.post(
        Uri.parse('${ApiConfig.authBaseUrl}/signup'),
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

      if (signupResponse.statusCode < 200 ||
          signupResponse.statusCode >= 300) {
        _clearPasswordsOnNextFocus = true;

        _showMessage(
          _readErrorMessage(
            signupResponse,
            fallback: 'طھط¹ط°ط± ط¥ظ†ط´ط§ط، ط§ظ„ط­ط³ط§ط¨',
          ),
        );

        return;
      }

      // Log the new user in automatically.
      final loginResponse = await http.post(
        Uri.parse('${ApiConfig.authBaseUrl}/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': normalizedEmail,
          'password': _passwordController.text,
        }),
      );

      if (loginResponse.statusCode < 200 ||
          loginResponse.statusCode >= 300) {
        _clearPasswordsOnNextFocus = true;

        _showMessage(
          _readErrorMessage(
            loginResponse,
            fallback: 'طھظ… ط¥ظ†ط´ط§ط، ط§ظ„ط­ط³ط§ط¨طŒ ظˆظ„ظƒظ† طھط¹ط°ط± طھط³ط¬ظٹظ„ ط§ظ„ط¯ط®ظˆظ„',
          ),
        );

        return;
      }

      final loginData =
          jsonDecode(loginResponse.body) as Map<String, dynamic>;

      final token = loginData['access_token'] as String?;

      if (token == null || token.isEmpty) {
        _clearPasswordsOnNextFocus = true;
        _showMessage('ظ„ظ… ظٹط±ط³ظ„ ط§ظ„ط®ط§ط¯ظ… ط±ظ…ط² طھط³ط¬ظٹظ„ ط§ظ„ط¯ط®ظˆظ„');
        return;
      }

      await AuthStorage.saveToken(token);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) =>
              const PreAssessmentIntroScreen(allowBack: false),
        ),
        (route) => false,
      );
    } catch (error) {
      _clearPasswordsOnNextFocus = true;
      _showMessage('طھط¹ط°ط± ط§ظ„ط§طھطµط§ظ„ ط¨ط§ظ„ط®ط§ط¯ظ…. طھط£ظƒط¯ ظ…ظ† طھط´ط؛ظٹظ„ ط§ظ„ط®ط§ط¯ظ… .');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _readErrorMessage(
    http.Response response, {
    required String fallback,
  }) {
    try {
      final decoded =
          jsonDecode(response.body) as Map<String, dynamic>;

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
        return 'ط§ظ„ط¨ط±ظٹط¯ ط§ظ„ط¥ظ„ظƒطھط±ظˆظ†ظٹ ظ…ط³طھط®ط¯ظ… ط¨ط§ظ„ظپط¹ظ„. ط¬ط±ظ‘ط¨ طھط³ط¬ظٹظ„ ط§ظ„ط¯ط®ظˆظ„ ';

      case 'Phone number already registered':
        return 'ط±ظ‚ظ… ط§ظ„ظ‡ط§طھظپ ظ…ط³طھط®ط¯ظ… ط¨ط§ظ„ظپط¹ظ„. ط¬ط±ظ‘ط¨ طھط³ط¬ظٹظ„ ط§ظ„ط¯ط®ظˆظ„ ط¥ظ„ظ‰ ط­ط³ط§ط¨ظƒ ط§ظ„ط³ط§ط¨ظ‚';

      case 'Email and phone number already registered':
        return 'ط§ظ„ط¨ط±ظٹط¯ ط§ظ„ط¥ظ„ظƒطھط±ظˆظ†ظٹ ظˆط±ظ‚ظ… ط§ظ„ظ‡ط§طھظپ ظ…ط³طھط®ط¯ظ…ط§ظ† ط¨ط§ظ„ظپط¹ظ„. ط¬ط±ظ‘ط¨ طھط³ط¬ظٹظ„ ط§ظ„ط¯ط®ظˆظ„ ';

      case 'Account information cannot be used':
        return 'طھط¹ط°ط± ط¥ظ†ط´ط§ط، ط§ظ„ط­ط³ط§ط¨. ط¥ط°ط§ ظƒط§ظ† ظ„ط¯ظٹظƒ ط­ط³ط§ط¨ ط³ط§ط¨ظ‚طŒ ط¬ط±ظ‘ط¨ طھط³ط¬ظٹظ„ ط§ظ„ط¯ط®ظˆظ„ ';

      case 'Passwords do not match.':
      case 'Passwords do not match':
        return 'ظƒظ„ظ…طھط§ ط§ظ„ظ…ط±ظˆط± ط؛ظٹط± ظ…طھط·ط§ط¨ظ‚طھظٹظ†';

      case 'Password must be at least 8 characters long.':
        return 'ظٹط¬ط¨ ط£ظ† طھطھظƒظˆظ† ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط± ظ…ظ† 8 ط£ط­ط±ظپ ط¹ظ„ظ‰ ط§ظ„ط£ظ‚ظ„';

      case 'Password must contain at least one uppercase letter.':
        return 'ظٹط¬ط¨ ط£ظ† طھط­طھظˆظٹ ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط± ط¹ظ„ظ‰ ط­ط±ظپ ظƒط¨ظٹط±';

      case 'Password must contain at least one lowercase letter.':
        return 'ظٹط¬ط¨ ط£ظ† طھط­طھظˆظٹ ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط± ط¹ظ„ظ‰ ط­ط±ظپ طµط؛ظٹط±';

      case 'Password must contain at least one number.':
        return 'ظٹط¬ط¨ ط£ظ† طھط­طھظˆظٹ ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط± ط¹ظ„ظ‰ ط±ظ‚ظ…';

      case 'Password must contain at least one special character.':
        return 'ظٹط¬ط¨ ط£ظ† طھط­طھظˆظٹ ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط± ط¹ظ„ظ‰ ط±ظ…ط² ط®ط§طµ';

      default:
        return message;
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    const errorColor = Color(0xFFB55252);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
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
      prefixIcon: Icon(icon, color: lightGreen),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: darkGreen,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _requirement(String text, bool isSatisfied) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            isSatisfied
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
            color: isSatisfied ? darkGreen : Colors.grey,
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isSatisfied
                    ? darkGreen
                    : Colors.grey.shade700,
                fontSize: 14,
                fontWeight: isSatisfied
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _genderChoice({
    required String label,
    required String value,
  }) {
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

  Widget _requiredLabel(
    String text, {
    Color color = Colors.grey,
  }) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$text ',
            style: TextStyle(color: color),
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          elevation: 0,
          foregroundColor: darkText,
          title: const Text(
            'ط¥ظ†ط´ط§ط، ط­ط³ط§ط¨',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 35),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'ظ…ط±ط­ط¨ظ‹ط§ ط¨ظƒ ظپظٹ ط·ظ„ظٹظ‚',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: darkText,
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'ط£ظ†ط´ط¦ ط­ط³ط§ط¨ظƒ ظ„ظ„ط¨ط¯ط، ظپظٹ ط±ط­ظ„ط© طھط­ط³ظٹظ† ط·ظ„ط§ظ‚ط© ط§ظ„ظƒظ„ط§ظ…',
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
                      label: 'ط§ظ„ط§ط³ظ…',
                      icon: Icons.person_outline_rounded,
                    ),
                    validator: (value) {
                      final name = value?.trim() ?? '';

                      if (name.isEmpty) {
                        return 'ظٹط±ط¬ظ‰ ط¥ط¯ط®ط§ظ„ ط§ظ„ط§ط³ظ…';
                      }

                      if (name.length < 2 ||
                          name.length > 50) {
                        return 'ظٹط¬ط¨ ط£ظ† ظٹطھظƒظˆظ† ط§ظ„ط§ط³ظ… ظ…ظ† 2 ط¥ظ„ظ‰ 50 ط­ط±ظپظ‹ط§';
                      }

                      final nameIsValid = RegExp(
                        r"^[A-Za-z\u0621-\u063A\u0641-\u064A]+(?: [A-Za-z\u0621-\u063A\u0641-\u064A]+)*$",
                      ).hasMatch(name);

                      if (!nameIsValid) {
                        return 'ظٹط±ط¬ظ‰ ط§ط³طھط®ط¯ط§ظ… ط§ظ„ط£ط­ط±ظپ ط§ظ„ط¹ط±ط¨ظٹط© ط£ظˆ ط§ظ„ط¥ظ†ط¬ظ„ظٹط²ظٹط© ظپظ‚ط·';
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
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[\x21-\x7E]'),
                      ),
                    ],
                    decoration: _fieldDecoration(
                      label: 'ط§ظ„ط¨ط±ظٹط¯ ط§ظ„ط¥ظ„ظƒطھط±ظˆظ†ظٹ',
                      icon: Icons.email_outlined,
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';

                      if (email.isEmpty) {
                        return 'ظٹط±ط¬ظ‰ ط¥ط¯ط®ط§ظ„ ط§ظ„ط¨ط±ظٹط¯ ط§ظ„ط¥ظ„ظƒطھط±ظˆظ†ظٹ';
                      }

                      final emailIsValid = RegExp(
                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                      ).hasMatch(email);

                      if (!emailIsValid) {
                        return 'ط§ظ„ط¨ط±ظٹط¯ ط§ظ„ط¥ظ„ظƒطھط±ظˆظ†ظٹ ط؛ظٹط± طµط­ظٹط­';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    maxLength: 10,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                    textInputAction: TextInputAction.next,
                    decoration: _fieldDecoration(
                      label: 'ط±ظ‚ظ… ط§ظ„ظ‡ط§طھظپ',
                      icon: Icons.phone_outlined,
                    ),
                    validator: (value) {
                      final phone = value?.trim() ?? '';

                      if (phone.isEmpty) {
                        return 'ظٹط±ط¬ظ‰ ط¥ط¯ط®ط§ظ„ ط±ظ‚ظ… ط§ظ„ظ‡ط§طھظپ';
                      }

                      if (!RegExp(r'^05\d{8}$').hasMatch(phone)) {
                        return 'ط±ظ‚ظ… ط§ظ„ظ‡ط§طھظپ ظٹط¬ط¨ ط£ظ† ظٹطھظƒظˆظ† ظ…ظ† 10 ط£ط±ظ‚ط§ظ… ظˆظٹط¨ط¯ط£ ط¨ظ€ 05';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                    textInputAction: TextInputAction.next,
                    decoration: _fieldDecoration(
                      label: 'ط§ظ„ط¹ظ…ط±',
                      icon: Icons.cake_outlined,
                    ),
                    validator: (value) {
                      final ageText = value?.trim() ?? '';

                      if (ageText.isEmpty) {
                        return 'ظٹط±ط¬ظ‰ ط¥ط¯ط®ط§ظ„ ط§ظ„ط¹ظ…ط±';
                      }

                      final age = int.tryParse(ageText);

                      if (age == null) {
                        return 'ظٹط±ط¬ظ‰ ط¥ط¯ط®ط§ظ„ ط¹ظ…ط± طµط­ظٹط­';
                      }

                      if (age < 13 || age > 100) {
                        return 'ظٹط¬ط¨ ط£ظ† ظٹظƒظˆظ† ط§ظ„ط¹ظ…ط± ط¨ظٹظ† 13 ظˆ100 ط³ظ†ط©';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  _requiredLabel(
                    'ط§ظ„ط¬ظ†ط³',
                    color: darkText,
                  ),

                  const SizedBox(height: 9),

                  Row(
                    children: [
                      _genderChoice(
                        label: 'ط£ظ†ط«ظ‰',
                        value: 'female',
                      ),
                      const SizedBox(width: 12),
                      _genderChoice(
                        label: 'ط°ظƒط±',
                        value: 'male',
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  TextFormField(
                    controller: _passwordController,
                    textAlign: TextAlign.right,
                    focusNode: _passwordFocusNode,
                    obscureText: _hidePassword,
                    onTap: _clearPasswordsForRetry,
                    autocorrect: false,
                    enableSuggestions: false,
                    textDirection: TextDirection.ltr,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9!@#$%^&*]'),
                      ),
                      LengthLimitingTextInputFormatter(20),
                    ],
                    onChanged: (_) {
                      setState(() {});
                    },
                    decoration: _fieldDecoration(
                      label: 'ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط±',
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
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'ظٹط±ط¬ظ‰ ط¥ط¯ط®ط§ظ„ ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط±';
                      }

                      if (!_passwordIsValid) {
                        return 'ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط± ظ„ط§ طھط³طھظˆظپظٹ ط¬ظ…ظٹط¹ ط§ظ„ط´ط±ظˆط·';
                      }

                      return null;
                    },
                  ),

                  if (_showPasswordRequirements) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F7F6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: borderColor,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'ظ…طھط·ظ„ط¨ط§طھ ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط±',
                            style: TextStyle(
                              color: darkText,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 7),
                          _requirement(
                            '8 ط£ط­ط±ظپ ط¹ظ„ظ‰ ط§ظ„ط£ظ‚ظ„',
                            _hasEightCharacters,
                          ),
                          _requirement(
                            'ط­ط±ظپ ظƒط¨ظٹط± ظˆط§ط­ط¯ ط¹ظ„ظ‰ ط§ظ„ط£ظ‚ظ„ (A-Z)',
                            _hasUppercase,
                          ),
                          _requirement(
                            'ط­ط±ظپ طµط؛ظٹط± ظˆط§ط­ط¯ ط¹ظ„ظ‰ ط§ظ„ط£ظ‚ظ„ (a-z)',
                            _hasLowercase,
                          ),
                          _requirement(
                            'ط±ظ‚ظ… ظˆط§ط­ط¯ ط¹ظ„ظ‰ ط§ظ„ط£ظ‚ظ„ (0-9)',
                            _hasNumber,
                          ),
                          _requirement(
                            'ط±ظ…ط² ط®ط§طµ ظˆط§ط­ط¯ (! @ # \$ % ^ & *)',
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
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9!@#$%^&*]'),
                      ),
                      LengthLimitingTextInputFormatter(20),
                    ],
                    onTap: _clearPasswordsForRetry,
                    onChanged: (_) {
                      setState(() {});
                    },
                    onFieldSubmitted: (_) {
                      if (!_isLoading) {
                        _createAccount();
                      }
                    },
                    decoration: _fieldDecoration(
                      label: 'طھط£ظƒظٹط¯ ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط±',
                      icon: Icons.lock_reset_rounded,
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _hideConfirmPassword =
                                !_hideConfirmPassword;
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
                        return 'ظٹط±ط¬ظ‰ طھط£ظƒظٹط¯ ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط±';
                      }

                      if (!_passwordsMatch) {
                        _clearPasswordsOnNextFocus = true;
                        return 'ظƒظ„ظ…طھط§ ط§ظ„ظ…ط±ظˆط± ط؛ظٹط± ظ…طھط·ط§ط¨ظ‚طھظٹظ†';
                      }

                      _clearPasswordsOnNextFocus = false;
                      return null;
                    },
                  ),

                  const SizedBox(height: 27),

                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed:
                          _isLoading ? null : _createAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: darkGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            darkGreen.withValues(alpha: 0.55),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(16),
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
                              'ط¥ظ†ط´ط§ط، ط§ظ„ط­ط³ط§ط¨',
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