import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_storage.dart';
import '../../services/signup_otp_service.dart';
import '../widgets/assesmentWidgets/pre_assessment_intro_screen.dart';

class SignupOtpScreen extends StatefulWidget {
  const SignupOtpScreen({
    super.key,
    required this.registrationId,
    required this.email,
    required this.resendAfterSeconds,
  });

  final String registrationId;
  final String email;
  final int resendAfterSeconds;

  @override
  State<SignupOtpScreen> createState() => _SignupOtpScreenState();
}

class _SignupOtpScreenState extends State<SignupOtpScreen> {
  static const _teal = Color(0xFF1F5F5A);
  static const _background = Color(0xFFFFFBF6);
  static const _darkText = Color(0xFF2E3A38);
  static const _errorColor = Color(0xFFB55252);

  final _codeController = TextEditingController();
  final _service = SignupOtpService();

  Timer? _timer;
  late DateTime _resendAvailableAt;

  int _secondsRemaining = 0;
  bool _busy = false;
  bool _accountCreated = false;
  bool _tokenSaved = false;
  String? _verifiedToken;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _startCooldown(widget.resendAfterSeconds);
  }

  void _startCooldown(int seconds) {
    _timer?.cancel();

    _resendAvailableAt = DateTime.now().add(Duration(seconds: seconds));
    _secondsRemaining = seconds;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final milliseconds = _resendAvailableAt
          .difference(DateTime.now())
          .inMilliseconds;
      final remaining = milliseconds > 0 ? (milliseconds / 1000).ceil() : 0;

      setState(() {
        _secondsRemaining = remaining;
      });

      if (remaining == 0) timer.cancel();
    });
  }

  Future<void> _verify() async {
    if (_busy || _accountCreated) return;

    FocusScope.of(context).unfocus();

    final code = _codeController.text.trim();

    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      setState(() {
        _error = 'يرجى إدخال رمز التحقق المكوّن من 6 أرقام';
        _notice = null;
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });

    try {
      final data = await _service.verify(
        registrationId: widget.registrationId,
        code: code,
      );

      if (!mounted) return;

      final token = data['access_token'];

      if (token is! String || token.isEmpty) {
        throw const SignupOtpException(
          'لم يرسل الخادم رمز تسجيل الدخول. يرجى تسجيل الدخول إلى حسابك.',
        );
      }

      // The account now exists, even if saving the token needs a retry.
      _verifiedToken = token;
      _timer?.cancel();
      _codeController.clear();

      setState(() {
        _accountCreated = true;
      });

      await _saveVerifiedToken();
    } on SignupOtpException catch (exception) {
      if (!mounted) return;

      setState(() {
        _error = exception.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'تعذر إكمال التحقق. يرجى المحاولة مرة أخرى.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _saveVerifiedToken() async {
    try {
      await AuthStorage.saveToken(_verifiedToken!);

      if (!mounted) return;

      setState(() {
        _tokenSaved = true;
        _verifiedToken = null;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'تم إنشاء حسابك، لكن تعذر حفظ تسجيل الدخول. اضغط متابعة للمحاولة مجددًا.';
      });
    }
  }

  Future<void> _continue() async {
    if (_busy) return;

    if (!_tokenSaved) {
      setState(() {
        _busy = true;
      });

      await _saveVerifiedToken();

      if (!mounted) return;

      setState(() {
        _busy = false;
      });

      if (!_tokenSaved) return;
    }

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const PreAssessmentIntroScreen(allowBack: false),
      ),
      (route) => false,
    );
  }

  Future<void> _resend() async {
    if (_busy || _secondsRemaining > 0 || _accountCreated) return;

    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });

    try {
      final data = await _service.resend(registrationId: widget.registrationId);

      if (!mounted) return;

      final seconds = data['resend_after_seconds'];
      _startCooldown(seconds is int ? seconds : 60);
      _codeController.clear();

      setState(() {
        _notice = 'تم إرسال رمز جديد. يرجى استخدام أحدث رمز وصلك.';
      });
    } on SignupOtpException catch (exception) {
      if (!mounted) return;

      final retryAfter = exception.retryAfterSeconds;

      if (retryAfter != null && retryAfter > 0) {
        _startCooldown(retryAfter);
      }

      setState(() {
        _error = exception.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'تعذر إعادة إرسال الرمز. يرجى المحاولة مرة أخرى.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Widget _buildOtpBody({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight > 48
                  ? constraints.maxHeight - 48
                  : 0,
            ),
            child: Align(
              alignment: _accountCreated
                  ? Alignment.center
                  : Alignment.topCenter,
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy && !_accountCreated,
      child: Scaffold(
        backgroundColor: _background,
        appBar: _accountCreated
            ? null
            : AppBar(
                backgroundColor: _background,
                automaticallyImplyLeading: false,
                leading: _accountCreated
                    ? null
                    : IconButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const BackButtonIcon(),
                        color: _teal,
                      ),
              ),
        body: SafeArea(
          child: _buildOtpBody(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_accountCreated) const SizedBox(height: 24),
                Icon(
                  _accountCreated
                      ? Icons.check_circle_outline_rounded
                      : Icons.mark_email_read_outlined,
                  size: 72,
                  color: _teal,
                ),
                const SizedBox(height: 24),
                Text(
                  _accountCreated
                      ? 'تم إنشاء حسابك بنجاح'
                      : 'التحقق من البريد الإلكتروني',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _darkText,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (!_accountCreated) ...[
                  const Text(
                    'أدخل رمز التحقق المكوّن من 6 أرقام المرسل إلى',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _darkText, height: 1.6),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.email,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _teal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _codeController,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.center,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    autocorrect: false,
                    enableSuggestions: false,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    style: const TextStyle(
                      fontSize: 26,
                      letterSpacing: 8,
                      color: _darkText,
                    ),
                    decoration: InputDecoration(
                      labelText: 'رمز التحقق',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onChanged: (_) {
                      if (_error != null) {
                        setState(() {
                          _error = null;
                        });
                      }
                    },
                    onSubmitted: (_) => _verify(),
                  ),
                ] else ...[
                  const Text(
                    'تم التحقق من بريدك الإلكتروني. يمكنك الآن متابعة خطوات التقييم.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _darkText, height: 1.7),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _errorColor, height: 1.6),
                  ),
                ],
                if (_notice != null && !_accountCreated) ...[
                  const SizedBox(height: 12),
                  Text(
                    _notice!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _teal, height: 1.6),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _teal,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _busy
                      ? null
                      : _accountCreated
                      ? _continue
                      : _verify,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_accountCreated ? 'متابعة' : 'تحقق'),
                ),
                if (!_accountCreated) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _busy || _secondsRemaining > 0 ? null : _resend,
                    child: Text(
                      _secondsRemaining > 0
                          ? 'إعادة إرسال الرمز بعد $_secondsRemaining ثانية'
                          : 'إعادة إرسال الرمز',
                    ),
                  ),
                  const Text(
                    'لم يصلك الرمز؟ تحقق من مجلد الرسائل غير المرغوب فيها.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF526B68),
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
