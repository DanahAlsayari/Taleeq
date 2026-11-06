
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;

class ScenarioRealtimeService {
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  MediaStream? _localStream;
  final RTCVideoRenderer _remoteAudioRenderer = RTCVideoRenderer();
  bool _isRemoteAudioRendererInitialized = false;
  Completer<void>? _dataChannelReady;

  final StreamController<String> _eventsController =
      StreamController<String>.broadcast();

  final StreamController<RTCPeerConnectionState>
      _connectionController =
      StreamController<RTCPeerConnectionState>.broadcast();

  Stream<String> get events => _eventsController.stream;

  Stream<RTCPeerConnectionState> get connectionStates =>
      _connectionController.stream;

  bool _isMuted = false;
  bool _isDisconnecting = false;
  bool _isDisposed = false;
  bool _conversationStartSent = false;
  bool _responseInProgress = false;
  Completer<void>? _cancelResponseDone;
  Completer<Map<String, dynamic>>? _analysisCompleter;
  bool _awaitingAnalysisResponse = false;
  String? _analysisResponseId;
  String? _activeResponseId;
  bool? _wasMutedBeforeAnalysis;
  String? _lastRealtimeError;
  String? _lastRealtimeEventType;

  bool get isMuted => _isMuted;

  Future<void> connect(String clientSecret) async {
    if (_isDisposed || _isDisconnecting) {
      throw StateError('Realtime service is already closing.');
    }

    try {
      await _remoteAudioRenderer.initialize();
      _isRemoteAudioRendererInitialized = true;

      _peerConnection = await createPeerConnection({
        'sdpSemantics': 'unified-plan',
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
      });

      if (_isDisconnecting) return;

      _peerConnection!.onConnectionState = (state) {
        if (_isDisconnecting ||
            _isDisposed ||
            _connectionController.isClosed) {
          return;
        }

        _connectionController.add(state);
      };

      _peerConnection!.onTrack = (event) {
        if (_isDisconnecting || _isDisposed) return;

        if (event.track.kind == 'audio') {
          event.track.enabled = true;

          if (event.streams.isNotEmpty) {
            _remoteAudioRenderer.srcObject = event.streams.first;
            debugPrint(
              'Realtime remote audio attached: ${event.streams.first.id}',
            );
          } else {
            debugPrint('Realtime remote audio track received without a stream.');
          }
        }
      };

      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      });

      if (_isDisconnecting) return;

      for (final track in _localStream!.getAudioTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }

      if (_isDisconnecting) return;

      _dataChannel = await _peerConnection!.createDataChannel(
        'oai-events',
        RTCDataChannelInit(),
      );

      _dataChannelReady = Completer<void>();

      _dataChannel!.onDataChannelState = (state) {
        if (_isDisconnecting || _isDisposed) return;

        if (state == RTCDataChannelState.RTCDataChannelOpen &&
            !(_dataChannelReady?.isCompleted ?? true)) {
          _dataChannelReady!.complete();
        }
      };

      _dataChannel!.onMessage = (message) {
        if (message.isBinary ||
            _isDisconnecting ||
            _isDisposed ||
            _eventsController.isClosed) {
          return;
        }

        _eventsController.add(message.text);
        _handleServerEvent(message.text);
      };

      final iceGatheringComplete = Completer<void>();
      _peerConnection!.onIceGatheringState = (state) {
        if (state == RTCIceGatheringState.RTCIceGatheringStateComplete &&
            !iceGatheringComplete.isCompleted) {
          iceGatheringComplete.complete();
        }
      };

      final offer = await _peerConnection!.createOffer();

      if (_isDisconnecting) return;

      await _peerConnection!.setLocalDescription(offer);

      if (_isDisconnecting) return;

      try {
        await iceGatheringComplete.future.timeout(
          const Duration(seconds: 8),
        );
      } on TimeoutException {
        debugPrint('ICE gathering timed out; using the available local SDP.');
      }

      final localDescription = await _peerConnection!.getLocalDescription();
      final localSdp = localDescription?.sdp ?? offer.sdp;

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/realtime/calls'),
        headers: {
          'Authorization': 'Bearer $clientSecret',
          'Content-Type': 'application/sdp',
        },
        body: localSdp,
      );

      if (_isDisconnecting) return;

      if (response.statusCode != 200 &&
          response.statusCode != 201) {
        throw Exception(
          'Realtime connection failed: ${response.statusCode}',
        );
      }

      final answer = RTCSessionDescription(
        response.body,
        'answer',
      );

      await _peerConnection!.setRemoteDescription(answer);

      if (_isDisconnecting) return;

      await _dataChannelReady!.future.timeout(
        const Duration(seconds: 20),
      );
    } catch (e) {
      await disconnect();
      rethrow;
    }
  }
void startConversation() {
debugPrint('START CONVERSATION CALLED');

if (_conversationStartSent ||
    _isDisconnecting ||
    _isDisposed) {
  debugPrint('START IGNORED');
  return;
}

  if (_dataChannel == null ||
      _dataChannel!.state != RTCDataChannelState.RTCDataChannelOpen) {
    debugPrint('Data channel is not ready.');
    return;
  }

  _conversationStartSent = true;

  debugPrint('Sending ONE initial response.create');

  sendEvent({
    'type': 'response.create',
  });
}


Future<void> stopConversation() async {
  if (_isDisconnecting || _isDisposed) return;

  final channel = _dataChannel;

  if (channel == null ||
      channel.state != RTCDataChannelState.RTCDataChannelOpen) {
    return;
  }

  channel.send(
    RTCDataChannelMessage(
      jsonEncode({'type': 'response.cancel'}),
    ),
  );
}

  void _handleServerEvent(String rawEvent) {
    try {
      final event = jsonDecode(rawEvent);
      if (event is! Map<String, dynamic>) return;

      final type = event['type']?.toString();
      _lastRealtimeEventType = type;
      debugPrint('Realtime server event: $type');

      // Realtime reports invalid response.create payloads and other server
      // errors as top-level "error" events, not response.failed events.
      if (type == 'error') {
        final error = event['error'];
        final message = error is Map
            ? '${error['message'] ?? error['code'] ?? error}'
            : '${error ?? 'Unknown Realtime API error'}';
        _lastRealtimeError = message;
        debugPrint('Realtime API error: $message');
        final completer = _analysisCompleter;
        if (completer != null && !completer.isCompleted) {
          completer.completeError(
            StateError('Realtime API rejected the analysis request: $message'),
          );
        }
        return;
      }

      if (type == 'response.created') {
        _responseInProgress = true;
        final response = event['response'];
        final responseId =
            response is Map<String, dynamic> ? response['id']?.toString() : null;
        _activeResponseId = responseId;
        if (_awaitingAnalysisResponse && responseId != null) {
          _analysisResponseId = responseId;
        }
        return;
      }

      if (type == 'response.done') {
        final response = event['response'];
        final responseId =
            response is Map<String, dynamic> ? response['id']?.toString() : null;

        // A response.done received while cancelling belongs to the old turn.
        final cancelCompleter = _cancelResponseDone;
        if (cancelCompleter != null && !cancelCompleter.isCompleted) {
          cancelCompleter.complete();
          if (_activeResponseId == responseId) {
            _responseInProgress = false;
            _activeResponseId = null;
          }
          return;
        }

        // Ignore late events from an earlier response. Only the response
        // created for this analysis request may complete the analysis future.
        if (responseId == null ||
            _analysisResponseId == null ||
            responseId != _analysisResponseId) {
          if (_activeResponseId == responseId) {
            _responseInProgress = false;
            _activeResponseId = null;
          }
          return;
        }

        _responseInProgress = false;
        _activeResponseId = null;
        final analysisCompleter = _analysisCompleter;
        if (analysisCompleter == null || analysisCompleter.isCompleted) return;

        if (response is! Map<String, dynamic> ||
            response['status'] != 'completed') {
          analysisCompleter.completeError(
            StateError('Realtime analysis response did not complete.'),
          );
          return;
        }

        final output = response['output'];
        if (output is! List) {
          analysisCompleter.completeError(
            StateError('Realtime analysis output is missing.'),
          );
          return;
        }

        for (final item in output) {
          if (item is Map<String, dynamic> &&
              item['type'] == 'function_call' &&
              item['name'] == 'submit_scenario_analysis' &&
              item['arguments'] is String) {
            final decoded = jsonDecode(item['arguments'] as String);
            if (decoded is! Map) {
              throw const FormatException(
                'Analysis arguments must be a JSON object.',
              );
            }
            analysisCompleter.complete(Map<String, dynamic>.from(decoded));
            return;
          }
        }

        analysisCompleter.completeError(
          StateError('Realtime did not return the scenario analysis function.'),
        );
        return;
      }

      if (type == 'response.failed') {
        final response = event['response'];
        final responseId =
            response is Map<String, dynamic> ? response['id']?.toString() : null;
        if (responseId != null && responseId == _analysisResponseId) {
          final details = response is Map
              ? response['status_details']
              : null;
          final failure = details is Map
              ? details['error']
              : event['error'];
          final message = failure is Map
              ? '${failure['message'] ?? failure['code'] ?? failure}'
              : '${failure ?? 'unknown error'}';
          _lastRealtimeError = message;
          debugPrint('Realtime analysis response failed: $message');
          final completer = _analysisCompleter;
          if (completer != null && !completer.isCompleted) {
            completer.completeError(
              StateError('Realtime analysis failed: $message'),
            );
          }
        }
      }
    } catch (error, stackTrace) {
      final completer = _analysisCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    }
  }

  Future<Map<String, dynamic>> requestScenarioAnalysis() async {
    if (_analysisCompleter != null) {
      throw StateError('Scenario analysis is already in progress.');
    }

    // Cancel only when the assistant still has an active response.
    if (_responseInProgress) {
      final cancelCompleter = Completer<void>();
      _cancelResponseDone = cancelCompleter;
      try {
        sendEvent({'type': 'response.cancel'});
        await cancelCompleter.future.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        debugPrint('Timed out waiting for the cancelled Realtime response.');
      } finally {
        _cancelResponseDone = null;
      }
    }

    final completer = Completer<Map<String, dynamic>>();
    _analysisCompleter = completer;
    _analysisResponseId = null;
    _awaitingAnalysisResponse = true;
    _lastRealtimeError = null;
    _lastRealtimeEventType = null;

    try {
      sendEvent({
        'type': 'response.create',
        'response': {
          'output_modalities': ['text'],
          'instructions': '''
Evaluate the user's speech across the complete conversation in this Realtime session.
Return the result only by calling submit_scenario_analysis.
Treat fluency_score and rhythm_score as approximate qualitative ratings on a 0-100 scale, not clinical measurements. Use null if there is insufficient evidence.
Do not claim precise acoustic measurements from conversational context alone. Set percentage metrics and speaking_rate_wpm to null unless reliably measurable from available evidence. Percentage metrics, when available, must be from 0 to 100. Keep feedback concise, specific, and supportive.
''',
          'tools': [
            {
              'type': 'function',
              'name': 'submit_scenario_analysis',
              'description': 'Submit the final structured evaluation of the scenario conversation.',
              'strict': true,
              'parameters': {
                'type': 'object',
                'properties': {
                  'scores': {
                    'type': 'object',
                    'description': 'Approximate qualitative ratings from 0 to 100, not clinical measurements.',
                    'properties': {
                      'fluency_score': {
                        'type': ['number', 'null'],
                        'description': 'Fluency rating from 0 to 100, or null if it cannot be assessed.',
                      },
                      'rhythm_score': {
                        'type': ['number', 'null'],
                        'description': 'Speech rhythm rating from 0 to 100, or null if it cannot be assessed.',
                      },
                    },
                    'required': ['fluency_score', 'rhythm_score'],
                    'additionalProperties': false,
                  },
                  'metrics': {
                    'type': 'object',
                    'properties': {
                      'stuttering_percent': {'type': ['number', 'null']},
                      'repetition_percent': {'type': ['number', 'null']},
                      'prolongation_percent': {'type': ['number', 'null']},
                      'block_percent': {'type': ['number', 'null']},
                      'speaking_rate_wpm': {'type': ['number', 'null']},
                    },
                    'required': [
                      'stuttering_percent',
                      'repetition_percent',
                      'prolongation_percent',
                      'block_percent',
                      'speaking_rate_wpm',
                    ],
                    'additionalProperties': false,
                  },
                  'feedback': {
                    'type': 'object',
                    'properties': {
                      'strength': {'type': 'string'},
                      'improvement': {'type': 'string'},
                    },
                    'required': ['strength', 'improvement'],
                    'additionalProperties': false,
                  },
                  'speech_events': {
                    'type': 'array',
                    'items': {
                      'type': 'object',
                      'properties': {
                        'event_type': {
                          'type': 'string',
                          'enum': ['repetition', 'prolongation', 'block'],
                        },
                        'word_or_sound': {'type': 'string'},
                        'confidence': {'type': ['number', 'null']},
                      },
                      'required': ['event_type', 'word_or_sound', 'confidence'],
                      'additionalProperties': false,
                    },
                  },
                },
                'required': ['scores', 'metrics', 'feedback', 'speech_events'],
                'additionalProperties': false,
              },
            },
          ],
          'tool_choice': {
            'type': 'function',
            'name': 'submit_scenario_analysis',
          },
        },
      });

      try {
        return await completer.future.timeout(const Duration(seconds: 60));
      } on TimeoutException {
        final responseState = _analysisResponseId == null
            ? 'No response.created event was received.'
            : 'Analysis response id: $_analysisResponseId; last event: $_lastRealtimeEventType.';
        final apiError = _lastRealtimeError == null
            ? ''
            : ' Last Realtime error: $_lastRealtimeError';
        throw TimeoutException(
          'Realtime analysis timed out. $responseState$apiError',
          const Duration(seconds: 60),
        );
      }
    } finally {
      _analysisCompleter = null;
      _awaitingAnalysisResponse = false;
      _analysisResponseId = null;
    }
  }

  void sendEvent(Map<String, dynamic> event) {
    if (_isDisconnecting ||
        _isDisposed ||
        _dataChannel == null ||
        _dataChannel!.state !=
            RTCDataChannelState.RTCDataChannelOpen) {
      throw StateError('Realtime data channel is not available.');
    }

    _dataChannel!.send(
      RTCDataChannelMessage(jsonEncode(event)),
    );
  }

  Future<void> toggleMute() async {
    if (_localStream == null ||
        _isDisconnecting ||
        _isDisposed) {
      return;
    }

    _isMuted = !_isMuted;

    for (final track in _localStream!.getAudioTracks()) {
      track.enabled = !_isMuted;
    }
  }

  Future<void> muteMicrophoneForAnalysis() async {
    if (_localStream == null || _isDisconnecting || _isDisposed) return;
    _wasMutedBeforeAnalysis = _isMuted;
    for (final track in _localStream!.getAudioTracks()) {
      track.enabled = false;
    }
    _isMuted = true;
  }

  Future<void> restoreMicrophoneAfterAnalysis() async {
    if (_localStream == null || _isDisconnecting || _isDisposed) return;
    final shouldRemainMuted = _wasMutedBeforeAnalysis ?? false;
    for (final track in _localStream!.getAudioTracks()) {
      track.enabled = !shouldRemainMuted;
    }
    _isMuted = shouldRemainMuted;
    _wasMutedBeforeAnalysis = null;
  }

  Future<void> disconnect() async {
    if (_isDisconnecting) return;

    _isDisconnecting = true;

    final channel = _dataChannel;
    final peer = _peerConnection;
    final stream = _localStream;

    _dataChannel = null;
    _peerConnection = null;
    _localStream = null;
    _dataChannelReady = null;

    if (channel != null) {
      channel.onMessage = null;
      channel.onDataChannelState = null;
      await channel.close();
    }

    if (peer != null) {
      peer.onConnectionState = null;
      peer.onIceGatheringState = null;
      await peer.close();
    }

    if (stream != null) {
      for (final track in stream.getTracks()) {
        await track.stop();
      }

      await stream.dispose();
    }

    if (_isRemoteAudioRendererInitialized) {
      _remoteAudioRenderer.srcObject = null;
      await _remoteAudioRenderer.dispose();
      _isRemoteAudioRendererInitialized = false;
    }

    _isMuted = false;
  }

  Future<void> dispose() async {
    if (_isDisposed) return;

    await disconnect();

    _isDisposed = true;

    if (!_eventsController.isClosed) {
      await _eventsController.close();
    }

    if (!_connectionController.isClosed) {
      await _connectionController.close();
    }
  }
}
