import 'package:flutter/material.dart';

import '../../services/assessment_api_service.dart';
import '../../services/profile_service.dart';
import '../widgets/assesmentWidgets/pre_assessment_intro_screen.dart';
import '../widgets/assesmentWidgets/speech_assesment_intro_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.isActive = true});

  final bool isActive;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = '';
  final ProfileService _profileService = ProfileService();
  String? _profileError;
  final AssessmentApiService _assessmentService = AssessmentApiService();

  String? _nextStep;
  bool _isLoadingAssessmentStatus = true;
  String? _assessmentStatusError;
  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadAssessmentStatus();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _profileService.getProfile();

      if (!mounted) return;

      setState(() {
        _userName = profile['name'] as String;
        _profileError = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _profileError = 'تعذر تحميل بيانات الحساب';
      });
    }
  }

  Future<void> _loadAssessmentStatus() async {
    setState(() {
      _isLoadingAssessmentStatus = true;
      _assessmentStatusError = null;
    });

    try {
      final status = await _assessmentService.getOnboardingStatus();
      final nextStep = status['next_step'];

      if (nextStep != 'pre_assessment' &&
          nextStep != 'speech_assessment' &&
          nextStep != 'completed') {
        throw Exception('Unexpected assessment status');
      }

      if (!mounted) return;

      setState(() {
        _nextStep = nextStep as String;
        _isLoadingAssessmentStatus = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _assessmentStatusError = 'تعذر تحميل حالة التقييم';
        _isLoadingAssessmentStatus = false;
      });
    }
  }

  Future<void> _continueAssessment() async {
    final Widget screen;

    if (_nextStep == 'pre_assessment') {
      screen = const PreAssessmentIntroScreen();
    } else if (_nextStep == 'speech_assessment') {
      screen = const SpeechAssesmentIntroScreen();
    } else {
      return;
    }

    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));

    if (!mounted) return;

    await _loadAssessmentStatus();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isActive && !oldWidget.isActive) {
      _loadProfile();
      _loadAssessmentStatus();
    }
  }

  Widget _buildAssessmentCard() {
    final completed = _nextStep == 'completed';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF398681), Color(0xFF5B9D98)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            completed ? Icons.check_circle_outline : Icons.assignment_outlined,
            color: Colors.white,
            size: 36,
          ),
          const SizedBox(height: 16),
          Text(
            completed ? 'جلساتك التدريبية' : 'أكمل تقييمك',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            completed
                ? 'أكملت التقييمات بنجاح. جلسات التدريب المخصصة ستكون متاحة قريبًا.'
                : 'أكمل التقييم القبلي وتقييم الكلام للحصول على جلسات تدريب وخطة تناسب احتياجاتك.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: completed ? null : _continueAssessment,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1F5F5A),
              disabledBackgroundColor: const Color(0xFFDDE8E6),
              disabledForegroundColor: const Color(0xFF526B68),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              completed
                  ? 'التدريب قريبًا'
                  : _nextStep == 'pre_assessment'
                  ? 'ابدأ التقييم القبلي'
                  : 'متابعة تقييم الكلام',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF6),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _userName.isEmpty ? 'مرحبًا 👋' : 'مرحبًا، $_userName 👋',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0xFF2E3A38),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'خطوتك القادمة نحو كلام أكثر راحة',
                textAlign: TextAlign.right,
                style: TextStyle(color: Color(0xFF6FA7A3), fontSize: 16),
              ),
              if (_profileError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _profileError!,
                  style: const TextStyle(color: Color(0xFFB55252)),
                ),
                TextButton(
                  onPressed: _loadProfile,
                  child: const Text('إعادة المحاولة'),
                ),
              ],
              const SizedBox(height: 24),

              if (_isLoadingAssessmentStatus)
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1F5F5A)),
                )
              else if (_assessmentStatusError != null) ...[
                Text(
                  _assessmentStatusError!,
                  style: const TextStyle(color: Color(0xFFB55252)),
                ),
                TextButton(
                  onPressed: _loadAssessmentStatus,
                  child: const Text('إعادة تحميل حالة التقييم'),
                ),
              ] else
                _buildAssessmentCard(),
            ],
          ),
        ),
      ),
    );
  }
}
