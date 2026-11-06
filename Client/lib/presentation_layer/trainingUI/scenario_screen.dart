

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:client/models/scenario_model.dart';
import 'package:client/services/scenario_realtime_service.dart';
import 'package:client/services/scenario_api_service.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:async';
import 'dart:convert';
import 'package:client/services/scenario_recording_service.dart';
import 'dart:io';

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
late final ScenarioRecordingService _recordingService;

bool _isRecording = false;
bool _isEndingScenario = false;
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

// Start local recording after Realtime connects.
await _recordingService.startRecording();

if (!mounted) return;

setState(() {
  _isRecording = true;
  _isConnected = true;
  _isConnecting = false;
});
    if (!mounted) return;

    setState(() {
      _isConnected = true;
      _isConnecting = false;
    });

    if (_conversationShouldStart && !_conversationStarted) {
      _conversationStarted = true;
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

  _isEndingScenario = true;

  try {
    await _videoController.pause();

    String? recordingPath;

    if (_isRecording) {
      recordingPath = await _recordingService.stopRecording();
      _isRecording = false;
    }

    await _realtimeService.disconnect();

    if (recordingPath != null) {
      final file = File(recordingPath);

      if (await file.exists()) {
        debugPrint('SCENARIO RECORDING SAVED');
        debugPrint('PATH: $recordingPath');
        debugPrint('SIZE: ${await file.length()} bytes');
      } else {
        debugPrint('Recording file does not exist.');
      }
    }

    if (!mounted) return;

    Navigator.pop(context);
  } catch (e) {
    debugPrint('Error ending scenario: $e');
    _isEndingScenario = false;
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
_recordingService = ScenarioRecordingService();
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
  final startTime = Duration(
    seconds: widget.scenario.conversationStartTime,
  );

if (currentPosition >= startTime) {
  _conversationShouldStart = true;

  if (!mounted) return;

  setState(() {});

  if (_isConnected && !_conversationStarted) {
    _conversationStarted = true;
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
  _recordingService.dispose();
  _eventsSubscription?.cancel();

  super.dispose();
}

Widget _buildMicrophoneButton() {
  return GestureDetector(
    onTap: _toggleMicrophone,
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
        children: [
          Icon(
            _isMuted
                ? Icons.mic_off_rounded
                : Icons.mic_rounded,
            color: Colors.white,
            size: 22,
          ),
          const SizedBox(width: 10),
          Text(
            _isMuted ? 'تشغيل المايكروفون' : 'كتم المايكروفون',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
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
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _endScenario,
                      icon: const Icon(
                        Icons.arrow_back_ios_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Column(
                      children: [
                        Text(
                          widget.scenario.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                      ],
                    ),
                   
                  ],
                ),
              ),

const Spacer(),

_buildAudioVisualizer(),

const Spacer(),

Padding(
  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.center,
    textDirection: TextDirection.ltr,
    children: [
      ElevatedButton.icon(
        onPressed: _endScenario,
        icon: const Icon(Icons.stop_rounded),
        label: const Text('إنهاء السيناريو'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(197, 244, 67, 54)
              .withOpacity(0.85),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
      const SizedBox(width: 12),
      _buildMicrophoneButton(),
    ],
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
