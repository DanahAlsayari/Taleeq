import 'package:flutter/material.dart';

import '../../services/real_life_challenge_service.dart';

class RealLifeChallengeScreen extends StatefulWidget {
  const RealLifeChallengeScreen({super.key});

  @override
  State<RealLifeChallengeScreen> createState() =>
      _RealLifeChallengeScreenState();
}

class _RealLifeChallengeScreenState extends State<RealLifeChallengeScreen> {
  static const _teal = Color(0xFF1F5F5A);
  static const _background = Color(0xFFFCFAF6);
  static const _text = Color(0xFF2E3A38);
  static const _muted = Color(0xFF526B68);

  final _service = RealLifeChallengeService();
  final _reflectionController = TextEditingController();

  Map<String, dynamic>? _challenge;
  String _savedReflection = '';
  String? _error;
  bool _loading = true;
  bool _busy = false;

  bool get _completed => _challenge?['is_completed'] == true;

  bool get _hasUnsavedChanges =>
      _reflectionController.text.trim() != _savedReflection.trim();

  @override
  void initState() {
    super.initState();
    _reflectionController.addListener(_onReflectionChanged);
    _load();
  }

  @override
  void dispose() {
    _reflectionController.removeListener(_onReflectionChanged);
    _reflectionController.dispose();
    super.dispose();
  }

  void _onReflectionChanged() {
    setState(() {});
  }

  String _errorMessage(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _applyChallenge(Map<String, dynamic> challenge) {
    _savedReflection = challenge['reflection'] as String? ?? '';
    _reflectionController.text = _savedReflection;

    setState(() {
      _challenge = challenge;
      _error = null;
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final challenge = await _service.ensureCurrent();

      if (!mounted) return;
      _applyChallenge(challenge);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _errorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _changeCompletion() async {
    if (_busy || _challenge == null) return;

    setState(() {
      _busy = true;
    });

    try {
      final updated = await _service.updateCompletion(
        attemptId: _challenge!['id'] as int,
        isCompleted: !_completed,
      );

      if (!mounted) return;

      // Keep any reflection the user is still editing.
      setState(() {
        _challenge = updated;
      });

      _showMessage(
        _completed
            ? 'أحسنت! يمكنك الآن مشاركة تجربتك إن رغبت.'
            : 'تم إلغاء تحديد الإكمال.',
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(_errorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _saveReflection() async {
    if (_busy || !_completed || !_hasUnsavedChanges) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _busy = true;
    });

    try {
      final updated = await _service.saveReflection(
        attemptId: _challenge!['id'] as int,
        reflection: _reflectionController.text,
      );

      if (!mounted) return;

      _applyChallenge(updated);
      _showMessage('تم حفظ تجربتك.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(_errorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _nextChallenge() async {
    if (_busy || !_completed || _hasUnsavedChanges) return;

    setState(() {
      _busy = true;
    });

    try {
      final next = await _service.nextChallenge(
        attemptId: _challenge!['id'] as int,
      );

      if (!mounted) return;

      FocusScope.of(context).unfocus();
      _applyChallenge(next);
      _showMessage('تحدٍّ جديد بانتظارك.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(_errorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _confirmLeaving() async {
    if (_busy || !_hasUnsavedChanges) return;

    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('مغادرة دون حفظ؟'),
        content: const Text('لديك تعديلات على تجربتك لم تُحفظ بعد.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('متابعة الكتابة'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('مغادرة'),
          ),
        ],
      ),
    );

    if (!mounted || discard != true) return;

    // Rebuild PopScope before trying to leave again.
    _reflectionController.text = _savedReflection;

    await WidgetsBinding.instance.endOfFrame;

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Widget _buildChallenge() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4F1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD9E9E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.flag_outlined, color: _teal, size: 32),
          const SizedBox(height: 14),
          Text(
            _challenge!['title'] as String,
            style: const TextStyle(
              color: _teal,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _challenge!['instructions'] as String,
            style: const TextStyle(color: _text, fontSize: 16, height: 1.8),
          ),
          const SizedBox(height: 18),
          const Text(
            'جرّب التحدّي خارج التطبيق عندما تتاح لك الفرصة، '
            'ثم عُد لتحديد إكماله.',
            style: TextStyle(color: _muted, fontSize: 14, height: 1.7),
          ),
        ],
      ),
    );
  }

  Widget _buildReflection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F3EC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEDE4D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'كيف كانت تجربتك؟',
            style: TextStyle(
              color: _text,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'مشاركتك اختيارية. يمكنك العودة لكتابة تجربتك '
            'قبل اختيار تحدٍّ جديد.',
            style: TextStyle(color: _muted, height: 1.6),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _reflectionController,
            enabled: !_busy,
            minLines: 4,
            maxLines: 8,
            maxLength: 2000,
            textInputAction: TextInputAction.newline,
            style: const TextStyle(color: _text, height: 1.6),
            decoration: InputDecoration(
              hintText: 'ما الذي ساعدك؟ وهل واجهت أي صعوبة؟',
              hintStyle: const TextStyle(color: _muted, fontSize: 14),
              filled: true,
              fillColor: const Color(0xFFFFFCF7),
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFDDDCD4)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy || !_hasUnsavedChanges ? null : _saveReflection,
            icon: const Icon(Icons.save_outlined),
            label: const Text('حفظ تجربتي'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _teal));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _load,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildChallenge(),
          const SizedBox(height: 20),
          if (_completed) ...[
            const Row(
              children: [
                Icon(Icons.check_circle, color: _teal),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تم إكمال التحدّي',
                    style: TextStyle(
                      color: _teal,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _busy ? null : _changeCompletion,
              icon: const Icon(Icons.undo),
              label: const Text('إلغاء تحديد الإكمال'),
            ),
            const SizedBox(height: 12),
            _buildReflection(),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _busy || _hasUnsavedChanges ? null : _nextChallenge,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('تحدٍّ جديد'),
            ),
            const SizedBox(height: 8),
            Text(
              _hasUnsavedChanges
                  ? 'احفظ تعديلاتك قبل اختيار تحدٍّ جديد.'
                  : 'ستبقى تجربتك السابقة محفوظة في سجل التحدّيات.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 13, height: 1.6),
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: _busy ? null : _changeCompletion,
              icon: const Icon(Icons.check),
              label: const Text('أكملت التحدّي'),
            ),
            const SizedBox(height: 8),
            const Text(
              'يبقى هذا التحدّي متاحًا حتى تكمله.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, height: 1.6),
            ),
            if (_hasUnsavedChanges) ...[
              const SizedBox(height: 8),
              const Text(
                'تعديلات تجربتك ما زالت هنا. '
                'يمكنك حفظها بعد تحديد الإكمال مجددًا.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, height: 1.6),
              ),
            ],
          ],
          if (_busy) ...[
            const SizedBox(height: 18),
            const LinearProgressIndicator(color: _teal),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: Theme.of(context).copyWith(
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: _teal,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: _teal,
              minimumSize: const Size.fromHeight(50),
              side: const BorderSide(color: _teal),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: _teal),
          ),
        ),
        child: PopScope(
          canPop: !_busy && !_hasUnsavedChanges,
          onPopInvokedWithResult: (didPop, result) async {
            if (!didPop) {
              await _confirmLeaving();
            }
          },
          child: Scaffold(
            backgroundColor: _background,
            appBar: AppBar(
              title: const Text('تحدّيك الواقعي'),
              centerTitle: true,
              backgroundColor: _background,
              foregroundColor: _teal,
              surfaceTintColor: Colors.transparent,
            ),
            body: SafeArea(child: _buildContent()),
          ),
        ),
      ),
    );
  }
}
