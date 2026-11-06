

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
  bool _conversationShouldStart = false;
  bool _isEndingScenario = false;
  DateTime? _conversationStartedAt;
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

    if (_conversationShouldStart && !_conversationStarted) {
      _conversationStarted = true;
      _conversationStartedAt = DateTime.now();
      _realtimeService.startConversation();
    }
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _isConnecting = false;
    });

    debugPrint('Realtime connection error: $e');
  }
}
Future<void> _endScenario() async {
  if (_isEndingScenario) return;

  if (!_conversationStarted || _conversationStartedAt == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('لم تبدأ المحادثة بعد.')),
    );
    return;
  }

  final elapsedSeconds =
      DateTime.now().difference(_conversationStartedAt!).inSeconds;

  if (elapsedSeconds < 15) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('يجب أن تستمر المحادثة 15 ثانية على الأقل قبل إنهائها.'),
      ),
    );
    return;
  }

  // Keep the saved duration within the backend's supported range.
  final durationSeconds = elapsedSeconds.clamp(15, 300).toInt();
  final endReason = elapsedSeconds > 300 ? 'duration_limit' : 'user_ended';

  setState(() => _isEndingScenario = true);

  try {
    await _videoController.pause();

    // Stop sending microphone audio, but keep the same Realtime session alive
    // so it can evaluate the conversation that has just ended.
    await _realtimeService.muteMicrophoneForAnalysis();
    if (mounted) setState(() => _isMuted = true);

    final analysis = await _realtimeService.requestScenarioAnalysis();
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

    // Allow the user to continue if analysis or saving failed.
    try {
      await _realtimeService.restoreMicrophoneAfterAnalysis();
      if (mounted) {
        setState(() => _isMuted = _realtimeService.isMuted);
      }
    } catch (restoreError) {
      debugPrint('Could not restore microphone after failed analysis: $restoreError');
    }
    try {
      if (_videoController.value.isInitialized &&
          !_videoController.value.isPlaying) {
        await _videoController.play();
      }
    } catch (videoError) {
      debugPrint('Could not resume scenario video: $videoError');
    }

    final message = error.toString().replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تعذر إنهاء السيناريو: $message'),
        duration: const Duration(seconds: 6),
      ),
    );
    setState(() => _isEndingScenario = false);
  }
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

  // Monitor conversation start time
  _videoController.addListener(_checkConversationStart);

  // Connect to Realtime after the first frame
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      _connectRealtime();
    }
  });
}
void _checkConversationStart() {
  if (_conversationShouldStart ||
      !_videoController.value.isInitialized) {
    return;
  }

  final currentPosition = _videoController.value.position;
  // Start the assistant a few seconds before the configured dialogue cue
  // so its greeting does not feel late to the user.
  final adjustedStartSeconds =
      (widget.scenario.conversationStartTime - 5).clamp(
    0,
    widget.scenario.conversationStartTime,
  ).toInt();
  final startTime = Duration(seconds: adjustedStartSeconds);

if (currentPosition >= startTime) {
  _conversationShouldStart = true;

  if (!mounted) return;

  setState(() {});

  if (_isConnected && !_conversationStarted) {
    _conversationStarted = true;
    _conversationStartedAt = DateTime.now();
    _realtimeService.startConversation();
  }
}
}
@override
void dispose() {
  _videoController.removeListener(_checkConversationStart);
  _videoController.dispose();

  _connectionSubscription?.cancel();
  _realtimeService.dispose();
  _eventsSubscription?.cancel();
  super.dispose();
}

Widget _buildMicrophoneButton() {
  return GestureDetector(
    onTap: _isEndingScenario ? null : _toggleMicrophone,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16,
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
          Icon(
            _isMuted
                ? Icons.mic_off_rounded
                : Icons.mic_rounded,
            color: Colors.white,
            size: 22,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              _isMuted ? 'تشغيل الميكروفون' : 'كتم الميكروفون',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
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
  return Scaffold(
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
                          onPressed: () => Navigator.pop(context),
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
  child: Center(
    child: _buildAudioVisualizer(),
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
          child: ElevatedButton.icon(
            onPressed: _isEndingScenario ? null : _endScenario,
            icon: _isEndingScenario
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.stop_rounded),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _isEndingScenario ? 'جاري التحليل...' : 'إنهاء السيناريو',
                maxLines: 1,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(197, 244, 67, 54)
                  .withOpacity(0.85),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
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
      ],
    ),
  );
}
}
