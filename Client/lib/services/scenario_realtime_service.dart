
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;

class ScenarioRealtimeService {
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  MediaStream? _localStream;
  Completer<void>? _dataChannelReady;
  Future<void>? _disconnectFuture;
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

  bool get isMuted => _isMuted;

  Future<void> connect(String clientSecret) async {
    if (_isDisposed || _isDisconnecting) {
      throw StateError('Realtime service is already closing.');
    }

    try {
      final peer = await createPeerConnection({
  'sdpSemantics': 'unified-plan',
});

if (_isDisconnecting || _isDisposed) {
  await peer.close();
  return;
}

_peerConnection = peer;
      _peerConnection!.onConnectionState = (state) {
        if (_isDisconnecting ||
            _isDisposed ||
            _connectionController.isClosed) {
          return;
        }

        _connectionController.add(state);
      };

final stream = await navigator.mediaDevices.getUserMedia({
  'audio': {
    'echoCancellation': true,
    'noiseSuppression': true,
    'autoGainControl': true,
  },
  'video': false,
});

if (_isDisconnecting || _isDisposed) {
  for (final track in stream.getTracks()) {
    await track.stop();
  }
  await stream.dispose();
  return;
}

_localStream = stream;
   final currentStream = _localStream!;
final currentPeer = _peerConnection!;

for (final track in currentStream.getAudioTracks()) {
  if (_isDisconnecting || _isDisposed) return;

  await currentPeer.addTrack(track, currentStream);
}

if (_isDisconnecting || _isDisposed) return;
     final channel = await currentPeer.createDataChannel(
  'oai-events',
  RTCDataChannelInit(),
);

if (_isDisconnecting || _isDisposed) {
  await channel.close();
  return;
}

_dataChannel = channel;
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
      };

final offer = await currentPeer.createOffer();

if (_isDisconnecting || _isDisposed) return;

await currentPeer.setLocalDescription(offer);

if (_isDisconnecting || _isDisposed) return;
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/realtime/calls'),
        headers: {
          'Authorization': 'Bearer $clientSecret',
          'Content-Type': 'application/sdp',
        },
        body: offer.sdp,
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
      // Route audio to the phone's external speaker.
await Helper.setSpeakerphoneOn(true);


debugPrint('🔊 Speakerphone enabled');
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

  Future<void> disconnect() {
  if (_disconnectFuture != null) {
    return _disconnectFuture!;
  }

  if (_isDisposed) return Future.value();

  _isDisconnecting = true;
  _disconnectFuture = _performDisconnect();

  return _disconnectFuture!;
}

Future<void> _performDisconnect() async {
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
    await peer.close();
  }

  if (stream != null) {
    for (final track in stream.getTracks()) {
      await track.stop();
    }

    await stream.dispose();
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
