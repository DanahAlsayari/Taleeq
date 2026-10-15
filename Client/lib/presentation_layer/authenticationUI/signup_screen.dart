import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../widgets/journey_stepper.dart';
import 'signup_otp_screen.dart';
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
  final _emailFieldKey = GlobalKey<FormFieldState<String>>();
  final _phoneFieldKey = GlobalKey<FormFieldState<String>>();
  final _passwordFieldKey = GlobalKey<FormFieldState<String>>();
  final _confirmPasswordFieldKey = GlobalKey<FormFieldState<String>>();

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
  bool _isLoading = false;
  bool _showGenderError = false;

  String? _selectedGender;
  String? _emailServerError;
  String? _phoneServerError;
  final Map<String, String> _backendFieldErrors = {};

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

  bool _showBackendValidationErrors(http.Response response) {
    final errors = <String, String>{};
    const fieldMessages = {
      'name': 'يرجى التحقق من الاسم المدخل',
      'email':
          'البريد الإلكتروني غير صالح. يرجى التحقق من اسم البريد واسم النطاق',
      'phone_number': 'رقم الهاتف يجب أن يتكون من 10 أرقام ويبدأ بـ 05',
      'age': 'يجب إدخال عمر صحيح بين 13 و100 سنة',
      'gender': 'يرجى اختيار الجنس',
      'password': 'كلمة المرور لا تستوفي جميع الشروط',
      'confirm_password': 'يرجى التحقق من تأكيد كلمة المرور',
    };

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return false;
      final detail = decoded['detail'];

      if (response.statusCode == 422 && detail is List) {
        for (final error in detail) {
          if (error is! Map) continue;
          final location = error['loc'];
          if (location is! List) continue;
          for (final part in location) {
            final field = part.toString();
            final message = fieldMessages[field];
            if (message != null) {
              errors[field] = message;
              break;
            }
          }
        }
      } else if (response.statusCode == 400 && detail is String) {
        if (detail == 'Passwords do not match.' ||
            detail == 'Passwords do not match') {
          errors['confirm_password'] = 'كلمتا المرور غير متطابقتين';
        } else if (detail.startsWith('Password ')) {
          final translated = _translateBackendError(detail);
          errors['password'] = translated == detail
              ? 'كلمة المرور لا تستوفي جميع الشروط'
              : translated;
        } else if (detail == 'Account information cannot be used') {
          errors['email'] = 'تعذر استخدام بيانات الحساب. يرجى التحقق منها';
          errors['phone_number'] =
              'تعذر استخدام بيانات الحساب. يرجى التحقق منها';
        }
      }
    } catch (_) {
      return false;
    }

    if (errors.isEmpty) return false;
    setState(() {
      _backendFieldErrors.addAll(errors);
    });
    return true;
  }

  Future<void> _createAccount() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _showGenderError = _selectedGender == null;
    });

    final formIsValid = _formKey.currentState?.validate() ?? false;

    if (!formIsValid) {
      _clearPasswordsOnNextFocus = !_passwordIsValid || !_passwordsMatch;
      return;
    }

    if (_showGenderError) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final normalizedEmail = _emailController.text.trim().toLowerCase();

    try {
      final signupResponse = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/signup'),
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

      if (!mounted) return;

      if (signupResponse.statusCode < 200 || signupResponse.statusCode >= 300) {
        String? detail;

        try {
          final decoded = jsonDecode(signupResponse.body);
          if (decoded is Map && decoded['detail'] is String) {
            detail = decoded['detail'] as String;
          }
        } catch (_) {}

        final emailUsed =
            detail == 'Email already registered' ||
            detail == 'Email and phone number already registered';

        final phoneUsed =
            detail == 'Phone number already registered' ||
            detail == 'Email and phone number already registered';

        if (emailUsed || phoneUsed) {
          setState(() {
            _emailServerError = emailUsed
                ? 'البريد الإلكتروني مستخدم بالفعل'
                : null;
            _phoneServerError = phoneUsed ? 'رقم الهاتف مستخدم بالفعل' : null;
          });

          _formKey.currentState?.validate();
          return;
        }

        if (_showBackendValidationErrors(signupResponse)) return;

        _showMessage(
          'تعذر إنشاء الحساب بسبب مشكلة في الخادم. يرجى المحاولة مرة أخرى',
        );
        return;
      }

      final decoded = jsonDecode(utf8.decode(signupResponse.bodyBytes));

      if (decoded is! Map<String, dynamic>) {
        _showMessage('تعذر قراءة استجابة الخادم. يرجى المحاولة مرة أخرى.');
        return;
      }

      final registrationId = decoded['registration_id'];
      final resendAfterSeconds = decoded['resend_after_seconds'];

      if (registrationId is! String ||
          registrationId.isEmpty ||
          resendAfterSeconds is! int) {
        _showMessage('تعذر بدء التحقق من البريد الإلكتروني.');
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SignupOtpScreen(
            registrationId: registrationId,
            email: normalizedEmail,
            resendAfterSeconds: resendAfterSeconds,
          ),
        ),
      );
    } catch (error) {
      _clearPasswordsOnNextFocus = true;
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
          return fallback;
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
        return 'البريد الإلكتروني مستخدم بالفعل. جرّب تسجيل الدخول ';

      case 'Phone number already registered':
        return 'رقم الهاتف مستخدم بالفعل. جرّب تسجيل الدخول إلى حسابك السابق';

      case 'Email and phone number already registered':
        return 'البريد الإلكتروني ورقم الهاتف مستخدمان بالفعل. جرّب تسجيل الدخول ';

      case 'Account information cannot be used':
        return 'تعذر إنشاء الحساب. إذا كان لديك حساب سابق، جرّب تسجيل الدخول ';

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
        return 'يرجى التحقق من البيانات المدخلة';
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
      errorMaxLines: 3,
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
            _showGenderError = false;
            _backendFieldErrors.remove('gender');
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
              color:
                  (_showGenderError ||
                      _backendFieldErrors.containsKey('gender'))
                  ? Colors.red
                  : (isSelected ? darkGreen : borderColor),
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

  Widget _requiredLabel(String text, {Color color = Colors.grey}) {
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
          automaticallyImplyLeading: false,
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
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: IconButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.of(context)
                                  .popUntil((route) => route.isFirst);
                            },
                      icon: const Icon(Icons.arrow_back_ios_new),
                    ),
                  ),
                  const JourneyStepper(currentStep: 1),

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
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    controller: _nameController,
                    onChanged: (_) {
                      setState(() {
                        _backendFieldErrors.remove('name');
                      });
                    },
                    forceErrorText: _backendFieldErrors['name'],
                    keyboardType: TextInputType.name,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    textInputAction: TextInputAction.next,
                    decoration: _fieldDecoration(
                      label: 'الاسم',
                      icon: Icons.person_outline_rounded,
                    ),
                    validator: (value) {
                      final name = value?.trim() ?? '';

                      if (name.isEmpty) {
                        return 'يرجى إدخال الاسم';
                      }

                      if (name.length < 2 || name.length > 50) {
                        return 'يجب أن يتكون الاسم من 2 إلى 50 حرفًا';
                      }

                      final nameIsValid = RegExp(
                        r"^[A-Za-z\u0621-\u063A\u0641-\u064A]+(?: [A-Za-z\u0621-\u063A\u0641-\u064A]+)*$",
                      ).hasMatch(name);

                      if (!nameIsValid) {
                        return 'يرجى استخدام الأحرف العربية أو الإنجليزية فقط';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  TextFormField(
                    key: _emailFieldKey,
                    autovalidateMode:
                        _emailFieldKey.currentState?.hasError == true
                        ? AutovalidateMode.onUserInteraction
                        : AutovalidateMode.onUnfocus,
                    controller: _emailController,
                    forceErrorText:
                        _backendFieldErrors['email'] ?? _emailServerError,
                    onChanged: (_) {
                      setState(() {
                        _emailServerError = null;
                        _backendFieldErrors.remove('email');
                      });
                    },
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\x21-\x7E]')),
                    ],
                    decoration: _fieldDecoration(
                      label: 'البريد الإلكتروني',
                      icon: Icons.email_outlined,
                    ),
                    validator: (value) {
                      final email = value ?? '';

                      if (email.trim().isEmpty) {
                        return 'يرجى إدخال البريد الإلكتروني';
                      }

                      if (RegExp(r'\s').hasMatch(email)) {
                        return 'يجب ألا يحتوي البريد الإلكتروني على مسافات';
                      }

                      final atCount = '@'.allMatches(email).length;

                      if (atCount == 0) {
                        return 'يجب أن يحتوي البريد الإلكتروني على الرمز @';
                      }

                      if (atCount > 1) {
                        return 'يجب أن يحتوي البريد الإلكتروني على رمز @ واحد فقط';
                      }

                      final parts = email.split('@');
                      final username = parts[0];
                      final domain = parts[1];

                      if (username.isEmpty) {
                        return 'يرجى إدخال اسم البريد قبل الرمز @';
                      }

                      if (domain.isEmpty) {
                        return 'يرجى إدخال اسم النطاق بعد الرمز @';
                      }

                      if (!domain.contains('.')) {
                        return 'يرجى إدخال نطاق كامل، مثل gmail.com';
                      }

                      final domainParts = domain.split('.');

                      if (domainParts.any((part) => part.isEmpty)) {
                        return 'اسم النطاق غير مكتمل، مثل gmail.com';
                      }

                      final domainIsValid = domainParts.every(
                        (part) => RegExp(
                          r'^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$',
                        ).hasMatch(part),
                      );

                      if (!domainIsValid) {
                        return 'اسم النطاق يحتوي على أحرف غير مسموحة';
                      }

                      if (username.startsWith('.') ||
                          username.endsWith('.') ||
                          username.contains('..')) {
                        return 'اسم البريد يجب ألا يبدأ أو ينتهي بنقطة أو يحتوي على نقطتين متتاليتين';
                      }

                      final usernameIsValid = RegExp(
                        r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+$",
                      ).hasMatch(username);

                      if (!usernameIsValid) {
                        return 'اسم البريد يحتوي على أحرف غير مسموحة';
                      }

                      return _emailServerError;
                    },
                  ),

                  const SizedBox(height: 14),

                  TextFormField(
                    key: _phoneFieldKey,
                    autovalidateMode:
                        _phoneFieldKey.currentState?.hasError == true
                        ? AutovalidateMode.onUserInteraction
                        : AutovalidateMode.onUnfocus,
                    controller: _phoneController,
                    forceErrorText:
                        _backendFieldErrors['phone_number'] ??
                        _phoneServerError,
                    onChanged: (_) {
                      setState(() {
                        _phoneServerError = null;
                        _backendFieldErrors.remove('phone_number');
                      });
                    },
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
                      label: 'رقم الهاتف',
                      icon: Icons.phone_outlined,
                    ),
                    validator: (value) {
                      final phone = value?.trim() ?? '';

                      if (phone.isEmpty) {
                        return 'يرجى إدخال رقم الهاتف';
                      }

                      if (!RegExp(r'^05\d{8}$').hasMatch(phone)) {
                        return 'رقم الهاتف يجب أن يتكون من 10 أرقام ويبدأ بـ 05';
                      }

                      return _phoneServerError;
                    },
                  ),

                  const SizedBox(height: 14),

                  TextFormField(
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    controller: _ageController,
                    onChanged: (_) {
                      setState(() {
                        _backendFieldErrors.remove('age');
                      });
                    },
                    forceErrorText: _backendFieldErrors['age'],
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                    textInputAction: TextInputAction.next,
                    decoration: _fieldDecoration(
                      label: 'العمر',
                      icon: Icons.cake_outlined,
                    ),
                    validator: (value) {
                      final ageText = value?.trim() ?? '';

                      if (ageText.isEmpty) {
                        return 'يرجى إدخال العمر';
                      }

                      final age = int.tryParse(ageText);

                      if (age == null) {
                        return 'يرجى إدخال عمر صحيح';
                      }

                      if (age < 13 || age > 100) {
                        return 'يجب أن يكون العمر بين 13 و100 سنة';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  _requiredLabel('الجنس', color: darkText),

                  const SizedBox(height: 9),

                  Row(
                    children: [
                      _genderChoice(label: 'أنثى', value: 'female'),
                      const SizedBox(width: 12),
                      _genderChoice(label: 'ذكر', value: 'male'),
                    ],
                  ),
                  if (_showGenderError ||
                      _backendFieldErrors.containsKey('gender'))
                    const Padding(
                      padding: EdgeInsetsDirectional.only(start: 12, top: 8),
                      child: Text(
                        'يرجى اختيار الجنس',
                        textAlign: TextAlign.right,
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),

                  const SizedBox(height: 18),

                  TextFormField(
                    key: _passwordFieldKey,
                    autovalidateMode:
                        _passwordFieldKey.currentState?.hasError == true
                        ? AutovalidateMode.onUserInteraction
                        : AutovalidateMode.onUnfocus,
                    controller: _passwordController,
                    forceErrorText: _backendFieldErrors['password'],
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
                      setState(() {
                        _backendFieldErrors.remove('password');
                      });
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
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'يرجى إدخال كلمة المرور';
                      }

                      if (!_passwordIsValid) {
                        return 'كلمة المرور لا تستوفي جميع الشروط';
                      }

                      return null;
                    },
                  ),

                  ...[
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
                    key: _confirmPasswordFieldKey,
                    autovalidateMode:
                        _confirmPasswordFieldKey.currentState?.hasError == true
                        ? AutovalidateMode.onUserInteraction
                        : AutovalidateMode.onUnfocus,
                    controller: _confirmPasswordController,
                    forceErrorText: _backendFieldErrors['confirm_password'],
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
                      setState(() {
                        _backendFieldErrors.remove('confirm_password');
                      });
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
                        return 'كلمتا المرور غير متطابقتين';
                      }

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
