
import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ScenarioRealtimeService {
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  MediaStream? _localStream;
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

  bool get isMuted => _isMuted;

  // 1. Connect to OpenAI Realtime
  Future<void> connect(String clientSecret) async {
    try {
      // Create Peer Connection
      _peerConnection = await createPeerConnection({
        'sdpSemantics': 'unified-plan',
      });

      // Listen to connection state
      _peerConnection!.onConnectionState = (state) {
        _connectionController.add(state);
      };

      // Get microphone
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      });

      // Add microphone track to WebRTC
      for (final track in _localStream!.getAudioTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }

      // Create Data Channel
    _dataChannel = await _peerConnection!.createDataChannel(
  'oai-events',
  RTCDataChannelInit(),
);

_dataChannelReady = Completer<void>();

_dataChannel!.onDataChannelState = (state) {
  if (state == RTCDataChannelState.RTCDataChannelOpen &&
      !(_dataChannelReady?.isCompleted ?? true)) {
    _dataChannelReady!.complete();
  }
};

      _dataChannel!.onMessage = (message) {
        if (message.isBinary) return;

        _eventsController.add(message.text);
      };

      // Create SDP Offer
      final offer = await _peerConnection!.createOffer();

      await _peerConnection!.setLocalDescription(offer);

      // Send SDP Offer to OpenAI
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/realtime/calls'),
        headers: {
          'Authorization': 'Bearer $clientSecret',
          'Content-Type': 'application/sdp',
        },
        body: offer.sdp,
      );

      if (response.statusCode != 200 &&
          response.statusCode != 201) {
        throw Exception(
          'Realtime connection failed: ${response.statusCode}',
        );
      }

      // Set SDP Answer
      final answer = RTCSessionDescription(
        response.body,
        'answer',
      );

      await _peerConnection!.setRemoteDescription(answer);
      await _dataChannelReady!.future.timeout(
  const Duration(seconds: 20),
);

sendEvent({
  'type': 'response.create',
});

    } catch (e) {
      await disconnect();
      rethrow;
    }
  }

  // 2. Send an event to OpenAI
  void sendEvent(Map<String, dynamic> event) {
  if (_dataChannel == null) {
    throw Exception('Realtime data channel is not available.');
  }

  _dataChannel!.send(
    RTCDataChannelMessage(
      jsonEncode(event),
    ),
  );
}

  // 3. Mute / Unmute microphone
  Future<void> toggleMute() async {
    if (_localStream == null) return;

    _isMuted = !_isMuted;

    for (final track in _localStream!.getAudioTracks()) {
      track.enabled = !_isMuted;
    }
  }

  // 4. Disconnect and release resources
  Future<void> disconnect() async {
    await _dataChannel?.close();
    _dataChannel = null;

    await _peerConnection?.close();
    _peerConnection = null;

    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await track.stop();
      }

      await _localStream!.dispose();
      _localStream = null;
    }

    _isMuted = false;
  }

  // 5. Dispose streams
  Future<void> dispose() async {
    await disconnect();

    await _eventsController.close();
    await _connectionController.close();
  }
}
