
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/dont_say_it_api_service.dart';
import '../../../services/recording_service.dart';
import 'game_stuttering_analysis.dart';
import 'shared_game_layout.dart';

class DontSayItScreen extends StatefulWidget {
  const DontSayItScreen({
    super.key,
    required this.difficulty,
    this.previousAttempt,
  });

  final String difficulty;
  final Map<String, dynamic>? previousAttempt;

  @override
  State<DontSayItScreen> createState() => _DontSayItScreenState();
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

    final previous = widget.previousAttempt;
    if (previous != null) {
      final rawAnalysis = previous['game_analysis'];
      final gameAnalysis = rawAnalysis is Map
          ? Map<String, dynamic>.from(rawAnalysis)
          : <String, dynamic>{};

      // The progress API stores some game flags at the attempt's top level.
      gameAnalysis['meaning_matched'] =
          previous['target_guessed'] ?? gameAnalysis['meaning_matched'];
      gameAnalysis['forbidden_word_spoken'] =
          previous['forbidden_word_spoken'] ??
          gameAnalysis['forbidden_word_spoken'];

      _result = <String, dynamic>{
        ...previous,
        'prediction': <String, dynamic>{
          'predicted_word': previous['target_word'] ??
              previous['predicted_word'] ??
              'غير متوفر',
        },
        'game_analysis': gameAnalysis,
      };
      _isLoading = false;
      _challenge = <String, dynamic>{
        'target_word_ar': previous['target_word'] ?? 'غير متوفر',
        'difficulty': previous['difficulty'] ?? widget.difficulty,
      };
    } else {
      _loadChallenge();
    }
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

  // إعادة المحاولة تعني تسجيلًا جديدًا، وليس إعادة تحليل التسجيل السابق.
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

  Future<void> _toggleRecordingPlayback() async {
    final path = _recordingPath;

    if (path == null) return;

    try {
      if (_recorder.player.playing) {
        await _recorder.pauseAudio();
      } else {
        await _recorder.loadAudio(path);
        await _recorder.resumeAudio();
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تشغيل التسجيل الصوتي.'),
        ),
      );
    }
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
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _teal),
      );
    }

    if (widget.previousAttempt != null && _result != null) {
      return _buildResultPage();
    }

    if (_challenge == null) {
      return _buildErrorState();
    }

    if (_result != null) {
      return _buildResultPage();
    }

    final forbidden = _challenge!['forbidden_words'];

    final forbiddenWords = forbidden is List
        ? forbidden.map((word) => word.toString()).toList()
        : <String>[];

    final duration =
        (_challenge!['duration_seconds'] as num?)?.toInt() ?? 30;

    return SharedGameRecordingLayout(
      intro: Column(
        children: [
Transform.flip(
  flipX: true,
  child: const Icon(
    Icons.record_voice_over_rounded,
    size: 42,
    color: _mint,
  ),
),
          const SizedBox(height: 4),
          const Text(
            'صف الكلمة دون أن تقولها!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _teal,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'عندك $duration ثانية لتوصل المعنى. لا تنطق الكلمة المستهدفة أو أي كلمة ممنوعة.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.7,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
      gameCard: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTargetCard(),
          const SizedBox(height: 10),
          _buildForbiddenCard(forbiddenWords),
        ],
      ),
      remainingSeconds: _remainingSeconds,
      durationSeconds: duration,
      isRecording: _isRecording,
      isAnalyzing: _isAnalyzing,
      onStart: _startRecording,
      onStop: _finishRecording,
      onNewChallenge: _loadChallenge,
      errorWidget:
          _errorMessage == null ? null : _buildErrorMessage(),
      analyzingMessage: 'نحلّل وصفك الآن...',
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
          const SizedBox(height: 16),

          // التسجيل الصوتي متاح للمحاولة الحالية فقط؛ لا نملك مسار تسجيل تاريخي.
          if (widget.previousAttempt == null) ...[
            const SizedBox(height: 12),
            _buildRecordingPlayer(),
            const SizedBox(height: 14),
          ],

          // عرض تحليل التأتأة
          ElevatedButton(
            onPressed: _result?['speech_analysis'] == null
                ? null
                : _showSpeechAnalysis,
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              elevation: 0,
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
          if (widget.previousAttempt == null) ...[
            const SizedBox(height: 14),

            // حاول مجددًا + تحدٍ جديد
            Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _retryAnalysis,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _teal,
                    minimumSize: const Size(0, 52),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    side: const BorderSide(color: _mint),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    textDirection: TextDirection.ltr,
                    mainAxisSize: MainAxisSize.min,
                    children: [
  Icon(Icons.replay_rounded, size: 20),
  SizedBox(width: 8),
  Text(
    'حاول مجددًا',
    textDirection: TextDirection.rtl,
  ),
],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _loadChallenge,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _teal,
                    minimumSize: const Size(0, 52),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    side: const BorderSide(color: _mint),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    textDirection: TextDirection.ltr,
                    mainAxisSize: MainAxisSize.min,
              children: [
  Icon(Icons.auto_awesome_rounded, size: 20),
  SizedBox(width: 8),
  Text(
    'تحدٍ جديد',
    textDirection: TextDirection.rtl,
  ),
],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // العودة إلى الصفحة الرئيسية
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).popUntil(
                  (route) => route.isFirst,
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: _teal,
                side: const BorderSide(color: _mint),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                textDirection: TextDirection.ltr,
                mainAxisSize: MainAxisSize.min,
                children: [
  Icon(Icons.home_outlined, size: 21),
  SizedBox(width: 8),
  Text(
    'العودة إلى الصفحة الرئيسية',
    textDirection: TextDirection.rtl,
    style: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
    ),
  ),
],
              ),
            ),
          ),
          ],
        ],
      ),
    );
  }

  Widget _buildTargetCard() {
    final target = _challenge?['target_word_ar']?.toString() ?? '—';

    return Container(
      padding: const EdgeInsets.all(17),
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
          const SizedBox(height: 8),
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
                side: const BorderSide(
                  color: Color(0xFFF0C5B4),
                ),
              );
            }).toList(),
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
      child: Text(
        _errorMessage!,
        style: const TextStyle(height: 1.5),
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
            passed
                ? Icons.emoji_events_rounded
                : Icons.sentiment_dissatisfied_rounded,
            color: passed ? _teal : _coral,
            size: 48,
          ),
          const SizedBox(height: 10),
          Text(
            passed
                ? 'أحسنت! اجتزت التحدي 🎉'
                : 'لم تجتز التحدي هذه المرة',
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
            gameAnalysis['forbidden_word_spoken'] == true
                ? 'نعم'
                : 'لا',
          ),
          if (forbiddenList.isNotEmpty)
            _resultRow(
              'الكلمات المخالفة',
              forbiddenList.join('، '),
            ),
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

  ButtonStyle _primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: _teal,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
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

  String _formatAudioTime(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildRecordingPlayer() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E8E4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              StreamBuilder<bool>(
                stream: _recorder.player.playingStream,
                initialData: _recorder.player.playing,
                builder: (context, snapshot) {
                  final isPlaying = snapshot.data ?? false;
                  return IconButton(
                    onPressed: _toggleRecordingPlayback,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 42,
                      minHeight: 42,
                    ),
                    icon: Icon(
                      isPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                      color: _teal,
                      size: 38,
                    ),
                  );
                },
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'استمع إلى تسجيلك',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: _teal,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.headphones_rounded,
                color: _teal,
                size: 23,
              ),
            ],
          ),
          StreamBuilder<Duration>(
            stream: _recorder.player.positionStream,
            initialData: _recorder.player.position,
            builder: (context, positionSnapshot) {
              final position =
                  positionSnapshot.data ?? Duration.zero;
              return StreamBuilder<Duration?>(
                stream: _recorder.player.durationStream,
                initialData: _recorder.player.duration,
                builder: (context, durationSnapshot) {
                  final duration =
                      durationSnapshot.data ?? Duration.zero;
                  final progress = duration.inMilliseconds > 0
                      ? (position.inMilliseconds /
                              duration.inMilliseconds)
                          .clamp(0.0, 1.0)
                      : 0.0;

                  return Row(
                    children: [
                      Text(
                        _formatAudioTime(position),
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 11,
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape:
                                const RoundSliderThumbShape(
                              enabledThumbRadius: 5,
                            ),
                            overlayShape:
                                const RoundSliderOverlayShape(
                              overlayRadius: 12,
                            ),
                          ),
                          child: Slider(
                            value: progress.toDouble(),
                            onChanged: duration.inMilliseconds > 0
                                ? (value) {
                                    _recorder.player.seek(
                                      Duration(
                                        milliseconds:
                                            (duration.inMilliseconds *
                                                    value)
                                                .round(),
                                      ),
                                    );
                                  }
                                : null,
                            activeColor: _mint,
                            inactiveColor:
                                const Color(0xFFE5EAE7),
                          ),
                        ),
                      ),
                      Text(
                        _formatAudioTime(duration),
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

}
