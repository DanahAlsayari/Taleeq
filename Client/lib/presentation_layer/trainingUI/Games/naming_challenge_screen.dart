import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'game_stuttering_analysis.dart';
import '../../../services/naming_challenge_api_service.dart';
import '../../../services/recording_service.dart';

class NamingChallengeScreen extends StatefulWidget {
  const NamingChallengeScreen({
    super.key,
    required this.difficulty,
  });

  final String difficulty;

  @override
  State<NamingChallengeScreen> createState() =>
      _NamingChallengeScreenState();
}

class _NamingChallengeScreenState extends State<NamingChallengeScreen>
    with SingleTickerProviderStateMixin {
  static const int _gameDurationSeconds = 20;
  static const Color _teal = Color(0xFF1F5F5A);
  static const Color _mint = Color(0xFF6FA7A3);
  static const Color _background = Color(0xFFFFFBF6);
  static const Color _coral = Color(0xFFD97757);

  final NamingChallengeApiService _apiService =
      NamingChallengeApiService();
  final RecordingService _recordingService = RecordingService();

  Timer? _gameTimer;
  late final AnimationController _confettiController;

  Map<String, dynamic>? _prompt;
  Map<String, dynamic>? _result;

  int _remainingSeconds = _gameDurationSeconds;
  bool _isLoadingPrompt = true;
  bool _isRecording = false;
  bool _isAnalyzing = false;
  bool _hasStarted = false;
  bool _resultDialogOpen = false;
  bool _errorDialogOpen = false;
  bool _showingResultPage = false;
  String? _errorMessage;
  String? _lastRecordingPath;
  String? _errorStage;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _loadPrompt();
  }

  Future<void> _loadPrompt() async {
    if (mounted) {
      setState(() {
        _isLoadingPrompt = true;
        _errorMessage = null;
      });
    }

    try {
      final prompt = await _apiService.getRandomPrompt(
  difficulty: widget.difficulty,
);
      if (!mounted) return;

      _gameTimer?.cancel();
      _gameTimer = null;
      setState(() {
        _prompt = prompt;
        _isLoadingPrompt = false;
        _hasStarted = false;
        _isRecording = false;
        _isAnalyzing = false;
        _result = null;
        _lastRecordingPath = null;
        _remainingSeconds = _gameDurationSeconds;
        _errorMessage = null;
        _errorStage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingPrompt = false;
        _errorMessage = _readableError(error);
        _errorStage = 'prompt';
      });
      _showErrorDialog();
    }
  }

  String _readableError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _startChallenge() async {
    if (_prompt == null || _isRecording || _isAnalyzing) return;

    setState(() {
      _errorMessage = null;
      _result = null;
      _lastRecordingPath = null;
    });

    bool started;
    try {
      started = await _recordingService.startRecording('naming_challenge');
    } catch (error) {
      if (!mounted) return;
      _showError(
        'تعذر بدء التسجيل. تأكد من السماح للتطبيق باستخدام الميكروفون.',
        stage: 'recording',
      );
      return;
    }

    if (!mounted) {
      if (started) await _recordingService.stopRecording();
      return;
    }

    if (!started) {
      _showError(
        'تعذر بدء التسجيل. تأكد من السماح للتطبيق باستخدام الميكروفون.',
        stage: 'recording',
      );
      return;
    }

    setState(() {
      _isRecording = true;
      _hasStarted = true;
      _remainingSeconds = _gameDurationSeconds;
      _errorMessage = null;
    });

    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_remainingSeconds <= 1) {
        timer.cancel();
        _finishChallenge();
        return;
      }

      setState(() => _remainingSeconds--);
    });
  }

  Future<void> _finishChallenge() async {
    if (!_isRecording) return;

    _gameTimer?.cancel();
    _gameTimer = null;

    setState(() {
      _isRecording = false;
      _isAnalyzing = true;
      _remainingSeconds = 0;
    });

    String? recordingPath;
    try {
      recordingPath = await _recordingService.stopRecording();
    } catch (_) {
      recordingPath = null;
    }

    if (!mounted) return;

    if (recordingPath == null || recordingPath.isEmpty) {
      setState(() => _isAnalyzing = false);
      _showError('تعذر حفظ التسجيل. أعد التسجيل وحاول مرة أخرى.',
          stage: 'recording');
      return;
    }

    _lastRecordingPath = recordingPath;
    await _analyzeLastRecording();
  }

  Future<void> _analyzeLastRecording() async {
    final path = _lastRecordingPath;
    final prompt = _prompt;
    if (path == null || prompt == null) return;

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final promptId = (prompt['id'] as num).toInt();
      final result = await _apiService.analyzeRecording(
        promptId: promptId,
        recordingPath: path,
      );

      if (!mounted) return;
      setState(() {
        _result = result;
        _isAnalyzing = false;
      });
      _showResultDialog();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      _showError(
        '${_readableError(error)}',
        stage: 'analysis',
      );
    }
  }

  void _showError(
    String message, {
    required String stage,
  }) {
    if (!mounted) return;

    setState(() {
      _errorMessage = message;
      _errorStage = stage;
      _isAnalyzing = false;
    });
  }

  Future<void> _showErrorDialog() async {
    if (!mounted || _errorDialogOpen || _errorMessage == null) return;
    _errorDialogOpen = true;
    final stage = _errorStage ?? 'recording';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        String title;
        IconData icon;
        switch (stage) {
          case 'prompt':
            title = 'تعذر تحميل التحدي';
            icon = Icons.cloud_off_rounded;
            break;
          case 'analysis':
            title = 'تعذر تحليل التسجيل';
            icon = Icons.analytics_outlined;
            break;
          default:
            title = 'حدث خطأ';
            icon = Icons.error_outline_rounded;
        }

        return AlertDialog(
          backgroundColor: _background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          icon: Icon(icon, size: 44, color: _coral),
          title: Text(title, textAlign: TextAlign.center),
          content: Text(
            _errorMessage ?? 'حدث خطأ غير متوقع. حاول مرة أخرى.',
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.5),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _errorDialogOpen = false;
                  if (stage == 'prompt') {
                    _loadPrompt();
                  } else if (stage == 'analysis' &&
                      _lastRecordingPath != null) {
                    _analyzeLastRecording();
                  } else {
                    _resetForSamePrompt();
                  }
                },
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  stage == 'prompt'
                      ? 'إعادة تحميل التحدي'
                      : stage == 'analysis' && _lastRecordingPath != null
                          ? 'إعادة التحليل'
                          : 'إعادة التسجيل',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _errorDialogOpen = false;
              },
              child: const Text('إغلاق'),
            ),
          ],
        );
      },
    );

    _errorDialogOpen = false;
  }

 
Future<void> _showResultDialog() async {
  if (!mounted || _result == null) return;

  final newRecord = _result!['new_record'] == true;

  if (newRecord) {
    _confettiController.forward(from: 0);
  }

  setState(() {
    _showingResultPage = true;
    _resultDialogOpen = false;
  });
}

Widget _buildResultPage() {
  final result = _result!;
  final validCount =
      (result['valid_count'] as num?)?.toInt() ?? 0;
  final newRecord = result['new_record'] == true;
  final previousScore =
      (result['previous_best_score'] as num?)?.toInt() ?? 0;
  final bestScore =
      (result['best_score'] as num?)?.toInt() ?? validCount;

  final rawItems = result['valid_items'];
  final items = rawItems is List
      ? rawItems.map((item) => item.toString()).toList()
      : <String>[];

  return SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),

        Icon(
          newRecord
              ? Icons.emoji_events_rounded
              : Icons.sentiment_dissatisfied,
          size: 68,
          color: newRecord ? _teal : _coral,
        ),

        const SizedBox(height: 12),

        Text(
          newRecord ? 'رقم قياسي جديد! 🎉' : ' فيه فرصة للتحسن ',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _teal,
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 10),

        Text(
          newRecord
              ? 'أحسنت! سجّلنا نتيجتك في هذا الموضوع.'
              : 'واصل التدريب وحاول تتجاوز أفضل نتيجة سابقة لك.',
          textAlign: TextAlign.center,
          style: const TextStyle(height: 1.5),
        ),

        const SizedBox(height: 24),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22),
          decoration: BoxDecoration(
            color: newRecord
                ? const Color(0xFFEAF4F2)
                : const Color(0xFFFFF1E9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text(
                '$validCount',
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: _teal,
                ),
              ),
              const SizedBox(height: 4),
              const Text('إجابة صحيحة في هذه المحاولة'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: _scoreSummaryCard(
                title: 'أعلى نتيجة سابقة',
                score: previousScore,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _scoreSummaryCard(
                title: 'أفضل نتيجة',
                score: bestScore,
              ),
            ),
          ],
        ),

        if (newRecord) ...[
          const SizedBox(height: 16),
          const Text(
            'حققت أفضل نتيجة لك في هذا الموضوع!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _teal,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],

        if (items.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'الإجابات الصحيحة',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map(
                  (item) => Chip(
                    label: Text(item),
                    backgroundColor: Colors.white,
                  ),
                )
                .toList(),
          ),
        ],


        const SizedBox(height: 28),



// زر تحليل التأتأة
OutlinedButton(
  onPressed: _showStutteringAnalysis,
  style: OutlinedButton.styleFrom(
    foregroundColor: _teal,
    minimumSize: const Size.fromHeight(52),
    side: const BorderSide(color: _mint),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15),
    ),
  ),
  child: const Row(
    mainAxisAlignment: MainAxisAlignment.center,
    mainAxisSize: MainAxisSize.min,
    children: [
      
      
      Text('عرض تحليل التأتأة'),
      SizedBox(width: 8),
      Icon(Icons.analytics_outlined, size: 20),
    ],
  ),
),

const SizedBox(height: 14),

// زرا المحاولة والتحدي الجديد
Row(
  children: [
    Expanded(
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _showingResultPage = false;
          });
          _resetForSamePrompt();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _teal,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('حاول مجددًا'),
            SizedBox(width: 8),
            Icon(Icons.replay_rounded, size: 20),
          ],
        ),
      ),
    ),

    const SizedBox(width: 12),

    Expanded(
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            _showingResultPage = false;
          });
          _loadPrompt();
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: _teal,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          side: const BorderSide(color: _mint),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('تحدٍ جديد'),
            SizedBox(width: 8),
            Icon(Icons.auto_awesome, size: 20),
          ],
        ),
      ),
    ),
  ],
),



        const SizedBox(height: 12),

      ],
    ),
  );
}

Future<void> _showStutteringAnalysis() async {
  if (!mounted || _result == null) return;

  await GameStutteringAnalysis.show(
    context: context,
    speechAnalysis: _result!['speech_analysis'],
  );

  // إغلاق نافذة التحليل يعيد المستخدم إلى صفحة النتيجة.
  // لا نغلق صفحة النتيجة ولا نمسح بياناتها.
}

  Widget _scoreSummaryCard({required String title, required int score}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4F2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(title, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 5),
          Text('$score',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _teal,
              )),
        ],
      ),
    );
  }

  void _resetForSamePrompt() {
    if (!mounted) return;
    _gameTimer?.cancel();
    setState(() {
      _result = null;
      _errorMessage = null;
      _errorStage = null;
      _hasStarted = false;
      _isRecording = false;
      _isAnalyzing = false;
      _lastRecordingPath = null;
      _remainingSeconds = _gameDurationSeconds;
    });
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _confettiController.dispose();
    _recordingService.disposeRecord();
    super.dispose();
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: _background,
    appBar: AppBar(
      backgroundColor: _background,
      elevation: 0,
      centerTitle: true,
      title: Text(
        _showingResultPage
            ? 'نتيجة التحدي'
            : 'تحدي التعداد',
        style: const TextStyle(
          color: _teal,
          fontWeight: FontWeight.bold,
        ),
      ),
      iconTheme: const IconThemeData(color: _teal),
      leading: _showingResultPage
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                setState(() {
                  _showingResultPage = false;
                });
              },
            )
          : null,
    ),
    body: SafeArea(
      child: _showingResultPage && _result != null
          ? _buildResultPage()
          : _buildBody(),
    ),
  );
}


  Widget _buildBody() {
    if (_isLoadingPrompt) {
      return const Center(
        child: CircularProgressIndicator(color: _teal),
      );
    }

    if (_prompt == null) {
      return _buildErrorState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildProgressHeader(),
          const SizedBox(height: 24),

          _buildPromptCard(),
          const SizedBox(height: 20),

          if (_isRecording || _isAnalyzing) ...[
            _buildTimerCard(),
            const SizedBox(height: 20),
          ],

          // إظهار الخطأ داخل الصفحة بدل نافذة منبثقة.
          if (_errorMessage != null) ...[
            _buildInlineError(),
            const SizedBox(height: 16),
          ],

          if (_isAnalyzing)
            _buildAnalyzingState()
          else if (_isRecording)
            _buildStopButton()
          else if (_errorMessage == null) ...[
            if (_result == null)
              _buildStartButton()
            else ...[
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _resultDialogOpen ? null : _showResultDialog,
                  icon: const Icon(Icons.assessment_outlined),
                  label: const Text('عرض النتيجة'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _teal,
                    side: const BorderSide(color: _mint),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _startChallenge,
                  icon: const Icon(Icons.mic_rounded),
                  label: const Text('إعادة التسجيل'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _isLoadingPrompt ? null : _loadPrompt,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('تحدٍ جديد'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _teal,
                  side: const BorderSide(color: _mint),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  Widget _buildProgressHeader() {
    return Column(
      children: [
        const Icon(Icons.lightbulb_rounded, size: 42, color: _mint),
        const SizedBox(height: 8),
        const Text(
          'مستعد للتحدي؟',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _teal,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'سيظهر لك موضوع. اذكر أكبر عدد ممكن من الإجابات الصحيحة خلال 20 ثانية. سيحلّل طليق إجاباتك، ويحفظ نتيجتك ويقارنها بأفضل نتيجة سابقة لك في الموضوع نفسه.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.7,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildPromptCard() {
    final promptAr = _prompt?['prompt_ar']?.toString() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4F2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD5E9E6)),
      ),
      child: Column(
        children: [
          const Text(
            'سؤال التحدي',
            style: TextStyle(color: _teal, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          Text(
            promptAr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 25,
              height: 1.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF214B48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerCard() {
    final progress = _remainingSeconds / _gameDurationSeconds;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 124,
            height: 124,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 9,
                    backgroundColor: const Color(0xFFE8EEEC),
                    color: _remainingSeconds <= 5 ? _coral : _mint,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_remainingSeconds',
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        color: _teal,
                      ),
                    ),
                    const Text('ثانية', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isRecording ? Icons.mic : Icons.hourglass_top_rounded,
                color: _isRecording ? _coral : _mint,
              ),
              const SizedBox(width: 8),
              Text(
                _isRecording
                    ? 'جاري تسجيل إجاباتك...'
                    : 'جاري تجهيز النتيجة...',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isLoadingPrompt ? null : _startChallenge,
        icon: const Icon(Icons.mic_rounded),
        label: const Text(
          'ابدأ التحدي',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _teal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildStopButton() {
    return Column(
      children: [
        SizedBox(
          height: 54,
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _finishChallenge,
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('إنهاء التسجيل الآن'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _teal,
              side: const BorderSide(color: _mint),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: _restartRecording,
          icon: const Icon(Icons.replay_rounded),
          label: const Text('إعادة التسجيل'),
        ),
      ],
    );
  }

  Future<void> _restartRecording() async {
    if (!_isRecording) return;
    _gameTimer?.cancel();
    try {
      await _recordingService.stopRecording();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _hasStarted = false;
      _remainingSeconds = _gameDurationSeconds;
      _lastRecordingPath = null;
    });
    await _startChallenge();
  }

  Widget _buildRetryRecordingButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _startChallenge,
        icon: const Icon(Icons.mic_rounded),
        label: const Text('إعادة التسجيل'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _teal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyzingState() {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          CircularProgressIndicator(color: _teal),
          SizedBox(height: 16),
          Text(
            'نحلّل إجاباتك الآن...',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'قد يستغرق التحليل بعض الوقت.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: _coral),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'تعذر تحميل السؤال.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadPrompt,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineError() {
    final isPromptError = _errorStage == 'prompt';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1E9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF0C5B4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: _coral,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _errorMessage ?? 'حدث خطأ غير متوقع.',
                  style: const TextStyle(
                    color: Color(0xFF713D2C),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _isRecording || _isAnalyzing
                ? null
                : () {
                    if (isPromptError) {
                      _loadPrompt();
                    } else {
                      _resetForSamePrompt();
                      _startChallenge();
                    }
                  },
            icon: Icon(
              isPromptError
                  ? Icons.refresh_rounded
                  : Icons.mic_rounded,
            ),
            label: Text(
              isPromptError
                  ? 'إعادة تحميل التحدي'
                  : 'إعادة التسجيل',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress});

  final double progress;

  static const List<Color> _colors = [
    Color(0xFF1F5F5A),
    Color(0xFF6FA7A3),
    Color(0xFFF2C14E),
    Color(0xFFD97757),
    Color(0xFFB9DAD4),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(24);
    const particleCount = 48;

    for (var i = 0; i < particleCount; i++) {
      final startX = random.nextDouble() * size.width;
      final drift = (random.nextDouble() - 0.5) * 70;
      final startY = -20 - random.nextDouble() * size.height * 0.4;

      final fall = progress * (size.height + 160);
      final x = startX + drift * progress;
      final y = startY + fall;

      final particleSize = 3 + random.nextDouble() * 5;
      final rotation =
          progress * math.pi * 4 + random.nextDouble() * math.pi;

      // تجاهل القطع التي تجاوزت أسفل النافذة.
      if (y > size.height + particleSize * 2) {
        continue;
      }

      // تبدأ القطع بالتلاشي عند اقترابها من أسفل النافذة.
      final fadeStart = size.height * 0.82;
      final fadeEnd = size.height + particleSize * 2;

      final opacity = y <= fadeStart
          ? 1.0
          : ((fadeEnd - y) / (fadeEnd - fadeStart))
              .clamp(0.0, 1.0)
              .toDouble();

      final paint = Paint()
        ..color = _colors[i % _colors.length].withOpacity(opacity);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: particleSize,
            height: particleSize * 1.8,
          ),
          const Radius.circular(1),
        ),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
