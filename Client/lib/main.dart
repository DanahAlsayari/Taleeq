import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import 'presentation_layer/authenticationUI/reset_password_screen.dart';
import 'presentation_layer/authenticationUI/welcome_screen.dart';

void main() {
  runApp(const TaleeqApp());
}

class TaleeqApp extends StatefulWidget {
  const TaleeqApp({super.key});

  @override
  State<TaleeqApp> createState() => _TaleeqAppState();
}

class _TaleeqAppState extends State<TaleeqApp> {
  final AppLinks _appLinks = AppLinks();

  StreamSubscription<Uri>? _linkSubscription;
  String? _resetToken;

  @override
  void initState() {
    super.initState();

    _handleInitialLink();
    _listenForLinks();
  }

  Future<void> _handleInitialLink() async {
    final uri = await _appLinks.getInitialLink();

    if (uri != null) {
      _handleLink(uri);
    }
  }

  void _listenForLinks() {
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleLink(uri);
      },
    );
  }

  void _handleLink(Uri uri) {
    if (uri.scheme == 'taleeq' && uri.host == 'reset-password') {
      final token = uri.queryParameters['token'];

      if (token != null && token.isNotEmpty) {
        setState(() {
          _resetToken = token;
        });
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
      scaffoldBackgroundColor: const Color(0xFFFFFBF6),

     fontFamily: 'Tajawal',

     colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1F5F5A),
    ),
  ),

      // Makes the entire application right-to-left.
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },

      // Normally display the welcome screen.
      // If the app receives a reset token, display the reset screen.
      home: _resetToken == null
          ? const WelcomeScreen()
          : ResetPasswordScreen(
              token: _resetToken!,
            ),
    );
  }
}