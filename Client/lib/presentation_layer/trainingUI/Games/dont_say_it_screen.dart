
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/dont_say_it_api_service.dart';
import '../../../services/recording_service.dart';
import 'game_stuttering_analysis.dart';

class DontSayItScreen extends StatefulWidget {
  const DontSayItScreen({
    super.key,
    required this.difficulty,
  });

  final String difficulty;

  @override
  State<DontSayItScreen> createState() =>
      _DontSayItScreenState();
}

class _DontSayItScreenState extends State<DontSayItScreen> {
  static const Color _teal = Color(0xFF1F5F5A);
  static const Color _mint = Color(0xFF6FA7A3);
  static const Color _background = Color(0xFFFFFBF6);
  static const Color _coral = Color(0xFFD97757);

  final DontSayItApiService _api = DontSayItApiService();
  final RecordingService _recorder = RecordingService();

  Timer? _timer;

  Map<String, dynamic>? _challenge;
  Map<String, dynamic>? _result;

  int _remainingSeconds = 30;
  bool _isLoading = true;
  bool _isRecording = false;
  bool _isAnalyzing = false;

  String? _recordingPath;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadChallenge();
  }

  Future<void> _loadChallenge() async {
    _timer?.cancel();

    if (mounted) {
      setState(() {
        _isLoading = true;
        _isRecording = false;
        _isAnalyzing = false;
        _result = null;
        _recordingPath = null;
        _errorMessage = null;
        _remainingSeconds = 30;
      });
    }

    try {
      final challenge = await _api.getRandomChallenge(
        difficulty: widget.difficulty,
      );

      if (!mounted) return;

      final duration =
          (challenge['duration_seconds'] as num?)?.toInt() ?? 30;

      setState(() {
        _challenge = challenge;
        _remainingSeconds = duration;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = _readableError(error);
      });
    }
  }

  String _readableError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _startRecording() async {
    if (_challenge == null || _isRecording || _isAnalyzing) return;

    setState(() {
      _errorMessage = null;
      _result = null;
      _recordingPath = null;
    });

    bool started;

    try {
      started = await _recorder.startRecording('dont_say_it');
    } catch (_) {
      started = false;
    }

    if (!mounted) {
      if (started) await _recorder.stopRecording();
      return;
    }

    if (!started) {
      setState(() {
        _errorMessage =
            'تعذر بدء التسجيل. تأكدي من السماح للتطبيق باستخدام الميكروفون.';
      });
      return;
    }

    final duration =
        (_challenge?['duration_seconds'] as num?)?.toInt() ?? 30;

    setState(() {
      _isRecording = true;
      _remainingSeconds = duration;
    });

    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_remainingSeconds <= 1) {
        timer.cancel();
        _finishRecording();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  Future<void> _finishRecording() async {
    if (!_isRecording) return;

    _timer?.cancel();
    _timer = null;

    setState(() {
      _isRecording = false;
      _isAnalyzing = true;
      _remainingSeconds = 0;
      _errorMessage = null;
    });

    String? path;

    try {
      path = await _recorder.stopRecording();
    } catch (_) {
      path = null;
    }

    if (!mounted) return;

    if (path == null || path.isEmpty) {
      setState(() {
        _isAnalyzing = false;
        _errorMessage = 'تعذر حفظ التسجيل. حاولي التسجيل مرة أخرى.';
      });
      return;
    }

    _recordingPath = path;
    await _analyzeRecording();
  }

  Future<void> _analyzeRecording() async {
    final challenge = _challenge;
    final path = _recordingPath;

    if (challenge == null || path == null) return;

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final id = (challenge['id'] as num).toInt();

      final result = await _api.analyzeRecording(
        challengeId: id,
        recordingPath: path,
      );

      if (!mounted) return;

      setState(() {
        _result = result;
        _isAnalyzing = false;
      });

    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isAnalyzing = false;
        _errorMessage = _readableError(error);
      });
    }
  }

  // إعادة المحاولة تعني تسجيل صوت جديد دائمًا، وليس إعادة تحليل الملف السابق.
  Future<void> _retryAnalysis() async {
    if (!mounted || _isRecording || _isAnalyzing) return;

    setState(() {
      _result = null;
      _recordingPath = null;
      _errorMessage = null;
      _remainingSeconds =
          (_challenge?['duration_seconds'] as num?)?.toInt() ?? 30;
    });

    await _startRecording();
  }

  Future<void> _showSpeechAnalysis() async {
    if (_result == null) return;

    await GameStutteringAnalysis.show(
      context: context,
      speechAnalysis: _result!['speech_analysis'],
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.disposeRecord();
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
        iconTheme: const IconThemeData(color: _teal),
        title: const Text(
          'لا تقولها',
          style: TextStyle(
            color: _teal,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _teal),
      );
    }

    if (_challenge == null) {
      return _buildErrorState();
    }

    // بعد اكتمال التحليل نعرض صفحة نتيجة مستقلة بدل نافذة منبثقة.
    if (_result != null) {
      return _buildResultPage();
    }

    final forbidden = _challenge!['forbidden_words'];

    final forbiddenWords = forbidden is List
        ? forbidden.map((word) => word.toString()).toList()
        : <String>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.record_voice_over_rounded,
            size: 48,
            color: _mint,
          ),
          const SizedBox(height: 10),

          const Text(
            'صف الكلمة دون أن تقولها!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: _teal,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'عندك 30 ثانية لتوصل المعنى. لا تنطق الكلمة المستهدفة أو أي كلمة ممنوعة.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.7,
              color: Colors.grey.shade700,
            ),
          ),

          const SizedBox(height: 24),

          _buildTargetCard(),

          const SizedBox(height: 16),

          _buildForbiddenCard(forbiddenWords),

          if (_isRecording || _isAnalyzing) ...[
            const SizedBox(height: 20),
            _buildTimerCard(),
          ],

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            _buildErrorMessage(),
          ],

          const SizedBox(height: 20),

          if (_isAnalyzing)
            _buildAnalyzingState()
          else if (_isRecording)
            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _finishRecording,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('إنهاء التسجيل'),
                style: _primaryButtonStyle(),
              ),
            )
          else if (_result == null)
            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _startRecording,
                icon: const Icon(Icons.mic_rounded),
                label: const Text('ابدأ التحدي'),
                style: _primaryButtonStyle(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          const Icon(
            Icons.emoji_events_rounded,
            size: 54,
            color: _mint,
          ),
          const SizedBox(height: 12),
          const Text(
            'نتيجة التحدي',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _teal,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 22),
          _buildResultCard(),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: _result?['speech_analysis'] == null
                ? null
                : _showSpeechAnalysis,
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
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
                Icon(Icons.analytics_outlined),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _retryAnalysis,
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
                Text('حاول مرة أخرى'),
                SizedBox(width: 8),
                Icon(Icons.replay_rounded),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _loadChallenge,
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
                Text('تحدٍ جديد'),
                SizedBox(width: 8),
                Icon(Icons.skip_previous_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ButtonStyle _primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: _teal,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
    );
  }

  Widget _buildTargetCard() {
    final target = _challenge?['target_word_ar']?.toString() ?? '—';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4F2),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD5E9E6)),
      ),
      child: Column(
        children: [
          const Text(
            'الكلمة المستهدفة',
            style: TextStyle(
              color: _teal,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            target,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: Color(0xFF214B48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForbiddenCard(List<String> words) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8DED8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.block_rounded, color: _coral),
              SizedBox(width: 8),
              Text(
                'الكلمات الممنوعة',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: words.map((word) {
              return Chip(
                label: Text(
                  word,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: const Color(0xFFFFF1E9),
                side: const BorderSide(color: Color(0xFFF0C5B4)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerCard() {
    final duration =
        (_challenge?['duration_seconds'] as num?)?.toInt() ?? 30;

    final progress = duration > 0
        ? (_remainingSeconds / duration).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 116,
            height: 116,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
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
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: _teal,
                      ),
                    ),
                    const Text('ثانية'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _isRecording ? 'جاري تسجيل وصفك...' : 'جاري تحليل التسجيل...',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzingState() {
    return const Padding(
      padding: EdgeInsets.all(18),
      child: Column(
        children: [
          CircularProgressIndicator(color: _teal),
          SizedBox(height: 14),
          Text(
            'نحلّل وصفك الآن...',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6),
          Text(
            'قد يستغرق التحليل بعض الوقت.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1E9),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFF0C5B4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _errorMessage!,
            style: const TextStyle(height: 1.5),
          ),
          if (!_isRecording && !_isAnalyzing) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _retryAnalysis,
              icon: const Icon(Icons.mic_rounded),
              label: const Text('إعادة التسجيل'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final result = _result!;
    final passed = result['passed'] == true;

    final rawGameAnalysis = result['game_analysis'];

    final gameAnalysis = rawGameAnalysis is Map
        ? Map<String, dynamic>.from(rawGameAnalysis)
        : <String, dynamic>{};

    final rawPrediction = result['prediction'];

    final prediction = rawPrediction is Map
        ? Map<String, dynamic>.from(rawPrediction)
        : <String, dynamic>{};

    final predictedWord =
        prediction['predicted_word']?.toString() ??
        result['predicted_word']?.toString() ??
        'غير متوفر';

    final reason =
        gameAnalysis['reasoning_ar']?.toString() ??
        gameAnalysis['summary_ar']?.toString();

    final matchedForbidden = gameAnalysis['matched_forbidden_words'];

    final forbiddenList = matchedForbidden is List
        ? matchedForbidden.map((word) => word.toString()).toList()
        : <String>[];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: passed
            ? const Color(0xFFEAF4F2)
            : const Color(0xFFFFF1E9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: passed
              ? const Color(0xFFD5E9E6)
              : const Color(0xFFF0C5B4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            passed ? Icons.emoji_events_rounded : Icons.refresh_rounded,
            color: passed ? _teal : _coral,
            size: 48,
          ),
          const SizedBox(height: 10),
          Text(
            passed ? 'أحسنت! اجتزت التحدي 🎉' : 'لم تجتز التحدي هذه المرة',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: passed ? _teal : _coral,
            ),
          ),
          const SizedBox(height: 18),
          _resultRow('الكلمة المتوقعة', predictedWord),
          _resultRow(
            'وصل المعنى',
            gameAnalysis['meaning_matched'] == true ? 'نعم' : 'لا',
          ),
          _resultRow(
            'نطق كلمة ممنوعة',
            gameAnalysis['forbidden_word_spoken'] == true ? 'نعم' : 'لا',
          ),
          if (forbiddenList.isNotEmpty)
            _resultRow('الكلمات المخالفة', forbiddenList.join('، ')),
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'التفسير',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              reason,
              style: const TextStyle(height: 1.6),
            ),
          ],
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.start,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
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
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: _coral,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'تعذر تحميل التحدي.',
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.5),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _loadChallenge,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
              style: _primaryButtonStyle(),
            ),
          ],
        ),
      ),
    );
  }
}
