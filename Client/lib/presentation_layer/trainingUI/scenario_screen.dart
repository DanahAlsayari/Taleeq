

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:client/models/scenario_model.dart';
import 'package:client/services/scenario_realtime_service.dart';
import 'package:client/services/scenario_api_service.dart';
import 'package:client/presentation_layer/trainingUI/scenario_result_screen.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:async';
import 'dart:convert';


class ScenarioScreen extends StatefulWidget {
  const ScenarioScreen({
    super.key,
    required this.attemptId,
    required this.scenario,
  });

  final String attemptId;
  final ScenarioModel scenario;

  @override
  State<ScenarioScreen> createState() => _ScenarioScreenState();
}

class _ScenarioScreenState extends State<ScenarioScreen> {
  late final VideoPlayerController _videoController;
late final ScenarioRealtimeService _realtimeService;

bool _isConnecting = false;
bool _isConnected = false;
bool _conversationStarted = false;
bool _isAssistantSpeaking = false;
bool _isUserSpeaking = false;
bool _isMuted = false;

StreamSubscription<RTCPeerConnectionState>?
    _connectionSubscription;
StreamSubscription<String>? _eventsSubscription;
  bool _isEndingScenario = false;
  bool _isLeavingScenario = false;
  DateTime? _conversationStartedAt;

Timer? _warningTimer;
Timer? _scenarioEndTimer;

static const Duration _maxScenarioDuration =
    Duration(minutes: 5);

static const Duration _warningBeforeEnd =
    Duration(seconds: 10);

bool _timeLimitReached = false;

  Future<void> _confirmExitScenario() async {
    if (_isLeavingScenario || _isEndingScenario) return;

    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'مغادرة السيناريو؟',
          textAlign: TextAlign.right,
        ),
        content: const Text(
          'سيتم إيقاف السيناريو الحالي وإنهاء المحادثة دون حفظ النتيجة. هل أنت متأكد؟',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (shouldExit != true || !mounted) return;

    setState(() => _isLeavingScenario = true);
    _warningTimer?.cancel();
    _scenarioEndTimer?.cancel();

    try {
      await _videoController.pause();
      await _realtimeService.disconnect();
    } catch (error) {
      debugPrint('Scenario exit cleanup error: $error');
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _showScenarioError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: const Color(0xFFD9534F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 5),
        ),
      );
  }


void _startScenarioTimers() {
  _warningTimer?.cancel();
  _scenarioEndTimer?.cancel();

  _warningTimer = Timer(
    _maxScenarioDuration - _warningBeforeEnd,
    () {
      if (!mounted || _isEndingScenario || _timeLimitReached) {
        return;
      }

      ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(
    SnackBar(
      content: const Text(
        'باقي 10 ثوانٍ على انتهاء السيناريو',
        textAlign: TextAlign.right,
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: const Color(0xFFD9534F),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 4),
    ),
  );
    },
  );

  _scenarioEndTimer = Timer(
    _maxScenarioDuration,
    () {
      if (!mounted || _isEndingScenario || _timeLimitReached) {
        return;
      }

      _timeLimitReached = true;

      _endScenario(automatic: true);
    },
  );
}


Future<void> _connectRealtime() async {
  if (_isConnecting || _isConnected) return;

  setState(() {
    _isConnecting = true;
  });

  try {
    final apiService = ScenarioApiService();

    final session = await apiService.createRealtimeSession(
      widget.attemptId,
    );

    final clientSecret = session['client_secret'];

    if (clientSecret is! String || clientSecret.isEmpty) {
      throw Exception('Client secret is missing.');
    }

    await _realtimeService.connect(clientSecret);

    if (!mounted) return;

    setState(() {
      _isConnected = true;
      _isConnecting = false;
    });

    // Start the assistant as soon as the Realtime connection is ready.
    // The scenario video no longer controls the conversation start time.
    if (!_conversationStarted) {
      _conversationStarted = true;
      _conversationStartedAt = DateTime.now();
      _startScenarioTimers();
      _realtimeService.startConversation();
    }
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _isConnecting = false;
    });

    debugPrint('Realtime connection error: $e');
    _showScenarioError('تعذر الاتصال بالمحادثة. تحققي من اتصال الإنترنت وحاولي مرة أخرى.');
  }
}
Future<void> _endScenario({bool automatic = false}) async {
  if (_isEndingScenario) return;

  if (!_conversationStarted || _conversationStartedAt == null) {
    _showScenarioError('لم تبدأ المحادثة بعد.');
    return;
  }

  final elapsedSeconds =
      DateTime.now().difference(_conversationStartedAt!).inSeconds;

  if (elapsedSeconds < 15 && !automatic) {
    _showScenarioError(
      'يجب أن تستمر المحادثة 15 ثانية على الأقل قبل إنهائها.',
    );
    return;
  }

  // Keep the saved duration within the backend's supported range.
  final durationSeconds = elapsedSeconds.clamp(15, 300).toInt();
  final endReason = _timeLimitReached || elapsedSeconds >= 300
    ? 'duration_limit'
    : (automatic ? 'scenario_completed' : 'user_ended');

  final hasReachedTimeLimit = endReason == 'duration_limit';

  _warningTimer?.cancel();
  _scenarioEndTimer?.cancel();
  setState(() => _isEndingScenario = true);

  try {
    await _videoController.pause();

    // Stop sending microphone audio, but keep the same Realtime session alive
    // so it can evaluate the conversation that has just ended.
    await _realtimeService.muteMicrophoneForAnalysis();
    if (mounted) setState(() => _isMuted = true);

    final analysis = await _realtimeService.requestScenarioAnalysis();
    debugPrint(
      'Scenario speech check: sufficient=${analysis['speech_sample_sufficient']}, '
      'events=${(analysis['speech_events'] is List) ? (analysis['speech_events'] as List).length : 'missing'}',
    );

    if (analysis['speech_sample_sufficient'] != true) {
      await _returnToHomeWithError(
        'لم نتمكن من اكتشاف كلام واضح. أعيدي السيناريو وحاولي التحدث بوضوح.',
      );
      return;
    }

    final result = await ScenarioApiService().completeRealtimeScenario(
      attemptId: widget.attemptId,
      durationSeconds: durationSeconds,
      endReason: endReason,
      analysisResult: analysis,
    );

    // Saving is the success boundary. A cleanup issue must not block results.
    try {
      await _realtimeService.disconnect();
    } catch (cleanupError) {
      debugPrint('Realtime cleanup error after saving results: $cleanupError');
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ScenarioResultScreen(
          result: result,
          scenarioName: widget.scenario.name,
        ),
      ),
    );
  } catch (error, stackTrace) {
  debugPrint('Failed to finish scenario: $error');
  debugPrintStack(stackTrace: stackTrace);

  if (!mounted) return;

  // Keep the original error details.
  final message = error.toString().replaceFirst('Exception: ', '');

  // Return to Instructions instead of resuming the scenario.
  await _returnToHomeWithError(
    'تعذر إنهاء السيناريو: $message',
  );
}
}
Future<void> _returnToHomeWithError(String message) async {
  _warningTimer?.cancel();
  _scenarioEndTimer?.cancel();

  try {
    await _realtimeService.disconnect();
  } catch (error) {
    debugPrint('Realtime disconnect error: $error');
  }

  if (!mounted) return;

  final messenger = ScaffoldMessenger.of(context);

  Navigator.of(context).pop();

  messenger
  ..hideCurrentSnackBar()
  ..showSnackBar(
    SnackBar(
      content: Text(
        message,
        textAlign: TextAlign.right,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: const Color(0xFFD9534F),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 5),
    ),
  );
}
void _handleRealtimeEvent(String event) {
  try {
    final data = jsonDecode(event) as Map<String, dynamic>;
    final type = data['type'];

    if (!mounted) return;

    setState(() {
      switch (type) {
        case 'output_audio_buffer.started':
          _isAssistantSpeaking = true;
          _isUserSpeaking = false;
          break;

        case 'output_audio_buffer.stopped':
          _isAssistantSpeaking = false;
          break;

        case 'input_audio_buffer.speech_started':
          _isUserSpeaking = true;
          _isAssistantSpeaking = false;
          break;

        case 'input_audio_buffer.speech_stopped':
          _isUserSpeaking = false;
          break;
        case 'scenario.completed':
          if (!_isEndingScenario) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_isEndingScenario) {
                _endScenario(automatic: true);
              }
            });
          }
          break;
      }
    });
  } catch (e) {
    debugPrint('Error handling Realtime event: $e');
  }
}
void _toggleMicrophone() {
  _realtimeService.toggleMute();

  setState(() {
    _isMuted = !_isMuted;
  });
}
@override
void initState() {
  super.initState();

  _realtimeService = ScenarioRealtimeService();

  // Listen to WebRTC connection states
  _connectionSubscription =
      _realtimeService.connectionStates.listen((state) {
    if (!mounted) return;

    setState(() {
      _isConnected = state ==
          RTCPeerConnectionState.RTCPeerConnectionStateConnected;

      if (state ==
              RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state ==
              RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _isConnecting = false;
      }
    });
  });

  // Listen to Realtime events
  _eventsSubscription = _realtimeService.events.listen(
    _handleRealtimeEvent,
  );

  // Initialize scenario video
  _videoController = VideoPlayerController.networkUrl(
    Uri.parse(widget.scenario.videoUrl),
  )..initialize().then((_) {
      if (!mounted) return;

      setState(() {});
      _videoController.play();
    });

  // Connect to Realtime after the first frame
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      _connectRealtime();
    }
  });
}
@override
void dispose() {
  _videoController.dispose();

  _connectionSubscription?.cancel();
  _realtimeService.dispose();
  _eventsSubscription?.cancel();
  _warningTimer?.cancel();
  _scenarioEndTimer?.cancel();
  super.dispose();
}

Widget _buildMicrophoneButton() {
  return GestureDetector(
    onTap: _isEndingScenario ? null : _toggleMicrophone,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 17,
      ),
      decoration: BoxDecoration(
        color: _isMuted
            ? Colors.red.withOpacity(0.85)
            : Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withOpacity(0.6),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              _isMuted ? 'تشغيل الميكروفون' : 'كتم الميكروفون',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            _isMuted
                ? Icons.mic_off_rounded
                : Icons.mic_rounded,
            color: Colors.white,
            size: 18,
          ),
        ],
      ),
    ),
  );
}

Widget _buildAudioVisualizer() {
  final bool isSpeaking = _isUserSpeaking;

  final List<double> waveHeights = [
    12, 20, 28, 35, 28, 20, 12, 20, 28, 20, 12,
  ];

  return AnimatedContainer(
    duration: const Duration(milliseconds: 250),
    width: 140,
    height: 90,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFF65D6C0)
          .withOpacity(isSpeaking ? 0.13 : 0.03),
      border: Border.all(
        color: const Color(0xFF65D6C0)
            .withOpacity(isSpeaking ? 0.7 : 0.18),
        width: 1.5,
      ),
      boxShadow: isSpeaking
          ? [
              BoxShadow(
                color: const Color(0xFF65D6C0).withOpacity(0.25),
                blurRadius: 20,
                spreadRadius: 3,
              ),
            ]
          : [],
    ),
    child: Center(
      child: SizedBox(
        width: 65,
        height: 45,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: waveHeights.map((height) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 1.2),
              width: 2.5,
              height: isSpeaking ? height : 5,
              decoration: BoxDecoration(
                color: const Color(0xFF65D6C0)
                    .withOpacity(isSpeaking ? 0.95 : 0.25),
                borderRadius: BorderRadius.circular(5),
              ),
            );
          }).toList(),
        ),
      ),
    ),
  );
}
 @override
Widget build(BuildContext context) {
  return PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) {
        _confirmExitScenario();
      }
    },
    child: Scaffold(
    backgroundColor: const Color(0xFFF7F3EA),
    body: Stack(
      fit: StackFit.expand,
      children: [
        // Full-screen scenario video
        if (_videoController.value.isInitialized)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _videoController.value.size.width,
              height: _videoController.value.size.height,
              child: VideoPlayer(_videoController),
            ),
          )
        else
          const Center(
            child: CircularProgressIndicator(),
          ),

        // Dark gradient for readability
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x55000000),
                Colors.transparent,
                Color(0x33000000),
                Color(0x99000000),
              ],
              stops: [0.0, 0.35, 0.65, 1.0],
            ),
          ),
        ),

        SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        widget.scenario.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: _confirmExitScenario,
                          icon: const Icon(
                            Icons.arrow_back_ios_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

Expanded(
  child: Transform.translate(
    offset: const Offset(0, 92),
    child: Center(
      child: _buildAudioVisualizer(),
    ),
  ),
),
Padding(
  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
  child: Directionality(
    textDirection: TextDirection.rtl,
    child: Row(
      children: [
        Expanded(child: _buildMicrophoneButton()),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isEndingScenario ? null : _endScenario,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(197, 244, 67, 54)
                  .withOpacity(0.85),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 17,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'إنهاء السيناريو',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.stop_rounded, size: 18),
              ],
            ),
          ),
        ),
      ],
    ),
  ),
),
            ],
          ),
        ),
        if (_isEndingScenario)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.48),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'جاري تحليل السيناريو...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
    ),
  );
}
}
