
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'game_stuttering_analysis.dart';
import '../../../services/naming_challenge_api_service.dart';
import '../../../services/recording_service.dart';
import 'shared_game_layout.dart';

class NamingChallengeScreen extends StatefulWidget {
  const NamingChallengeScreen({
    super.key,
    required this.difficulty,
    this.previousAttempt,
  });

  final String difficulty;
  final Map<String, dynamic>? previousAttempt;

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
  Duration _recordingPosition = Duration.zero;
  Duration _recordingDuration = Duration.zero;

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

    final previousAttempt = widget.previousAttempt;
    if (previousAttempt != null) {
      final saved = Map<String, dynamic>.from(previousAttempt);
      final score = saved['valid_count'] ?? saved['last_score'] ?? saved['score'] ?? 0;
      final best = saved['best_score'] ?? score;
      _result = {
        ...saved,
        'valid_count': score,
        'last_score': score,
        'previous_score': score,
        'best_score': best,
        'new_record': false,
        'valid_items': saved['valid_items'] is List ? saved['valid_items'] : <dynamic>[],
      };
      _showingResultPage = true;
      _isLoadingPrompt = false;
    } else {
      _loadPrompt();
    }
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
      started = await _recordingService.startRecording(
        'naming_challenge',
      );
    } catch (_) {
      if (!mounted) return;

      _showError(
        'تعذر بدء التسجيل. تأكد من السماح للتطبيق باستخدام الميكروفون.',
        stage: 'recording',
      );
      return;
    }

    if (!mounted) {
      if (started) {
        await _recordingService.stopRecording();
      }
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
      _remainingSeconds = _gameDurationSeconds;
      _errorMessage = null;
    });

    _gameTimer?.cancel();

    _gameTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
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
      },
    );
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

      _showError(
        'تعذر حفظ التسجيل. أعد التسجيل وحاول مرة أخرى.',
        stage: 'recording',
      );
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
        _readableError(error),
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
    if (!mounted || _errorDialogOpen || _errorMessage == null) {
      return;
    }

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
          icon: Icon(
            icon,
            size: 44,
            color: _coral,
          ),
          title: Text(
            title,
            textAlign: TextAlign.center,
          ),
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
                      : stage == 'analysis' &&
                              _lastRecordingPath != null
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
    });
  }

  Future<void> _toggleRecordingPlayback() async {
    final path = _lastRecordingPath;

    if (path == null) return;

    try {
      if (_recordingService.player.playing) {
        await _recordingService.pauseAudio();
      } else {
        await _recordingService.loadAudio(path);
        await _recordingService.resumeAudio();
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
  String _formatAudioTime(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;

  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

Widget _buildRecordingPlayer() {
  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 8,
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
              stream: _recordingService.player.playingStream,
              initialData: _recordingService.player.playing,
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
            const SizedBox(width: 8),
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
          stream: _recordingService.player.positionStream,
          initialData: _recordingService.player.position,
          builder: (context, positionSnapshot) {
            final position =
                positionSnapshot.data ?? Duration.zero;

            return StreamBuilder<Duration?>(
              stream: _recordingService.player.durationStream,
              initialData: _recordingService.player.duration,
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
                          thumbShape: const RoundSliderThumbShape(
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
                                  _recordingService.player.seek(
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


  Widget _buildResultPage() {
    final result = _result!;
    final validCount =
        (result['valid_count'] as num?)?.toInt() ?? 0;
    final newRecord = result['new_record'] == true;
    final bestScore =
        (result['best_score'] as num?)?.toInt() ?? validCount;

    final lastScore =
        (result['previous_score'] as num?)?.toInt() ?? 0;
    final rawItems = result['valid_items'];
    final items = rawItems is List
        ? rawItems.map((item) => item.toString()).toList()
        : <String>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          
          Icon(
            newRecord
                ? Icons.emoji_events_rounded
                : Icons.sentiment_dissatisfied,
            size: 50,
            color: newRecord ? _teal : _coral,
          ),
          const SizedBox(height: 5),
          Text(
            newRecord ? 'رقم قياسي جديد! 🎉' : 'فيه فرصة للتحسن',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _teal,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            newRecord
                ? 'أحسنت! سجّلنا نتيجتك في هذا الموضوع.'
                : 'واصل التدريب وحاول تتجاوز أفضل نتيجة سابقة لك.',
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.5),
          ),
          const SizedBox(height: 13),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 17),
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
                    fontSize: 35,
                    fontWeight: FontWeight.bold,
                    color: _teal,
                  ),
                ),
                
                const Text('إجابة صحيحة في هذه المحاولة'),
              ],
            ),
          ),
          const SizedBox(height: 16),
        
Row(
  children: [
    Expanded(
      child: _scoreSummaryCard(
        title: 'آخر نتيجة',
        score: lastScore,
        icon: Icons.history_rounded,
      ),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: _scoreSummaryCard(
        title: 'أفضل نتيجة',
        score: bestScore,
        icon: Icons.emoji_events_rounded,
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
          if (widget.previousAttempt == null) ...[
            const SizedBox(height: 12),
            _buildRecordingPlayer(),
            const SizedBox(height: 14),
          ],
          OutlinedButton(
            onPressed: _showStutteringAnalysis,
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
Row(
  children: [
    Expanded(
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            _showingResultPage = false;
          });
          _resetForSamePrompt();
        },
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
          children: [ Icon(Icons.replay_rounded, size: 20),SizedBox(width: 8),
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
        onPressed: () {
          setState(() {
            _showingResultPage = false;
          });
          _loadPrompt();
        },
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
            
            
            Icon(Icons.auto_awesome_rounded, size: 20),SizedBox(width: 8),Text(
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
      children: [            SizedBox(width: 8),
        Text(
          'العودة إلى التمارين ',
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

  Future<void> _showStutteringAnalysis() async {
    if (!mounted || _result == null) return;

    await GameStutteringAnalysis.show(
      context: context,
      speechAnalysis: _result!['speech_analysis'],
    );
  }

Widget _scoreSummaryCard({
  required String title,
  required int score,
  required IconData icon,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(
      vertical: 14,
      horizontal: 8,
    ),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF4F2),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        Icon(
          icon,
          color: _mint,
          size: 25,
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '$score',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _teal,
          ),
        ),
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
          _showingResultPage ? 'نتيجة التحدي' : 'تحدي التعداد',
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
          if (widget.previousAttempt != null) {
            Navigator.of(context).pop();
            return;
          }

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

    return SharedGameRecordingLayout(
      intro: _buildProgressHeader(),
      gameCard: _buildPromptCard(),
      remainingSeconds: _remainingSeconds,
      durationSeconds: _gameDurationSeconds,
      isRecording: _isRecording,
      isAnalyzing: _isAnalyzing,
      onStart: _startChallenge,
      onStop: _finishChallenge,
      onNewChallenge: _loadPrompt,
      errorWidget: _errorMessage == null ? null : _buildInlineError(),
      analyzingMessage: 'جاري تحليل إجاباتك...',
    );
  }

  Widget _buildProgressHeader() {
    return Column(
      children: [
        const Icon(
          Icons.lightbulb_rounded,
          size: 42,
          color: _mint,
        ),
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
          '.اذكر أكبر عدد ممكن من الإجابات على الموضوع التالي خلال 20 ثانية',
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
            style: TextStyle(
              color: _teal,
              fontWeight: FontWeight.w600,
            ),
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

      if (y > size.height + particleSize * 2) {
        continue;
      }

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
