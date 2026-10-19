import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'signaling_service.dart';

class WebRTCService {
  final SignalingService signaling;
  RTCPeerConnection? _peerConnection;
  final RTCVideoRenderer renderer = RTCVideoRenderer();
  MediaStream? _localStream;
  String? _peerId;

  bool get isRendererInitialized => renderer.srcObject != null;

  WebRTCService(this.signaling);

  Future<void> init() async {
    await renderer.initialize();
  }

  Future<void> _createPeerConnection() async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    };

    _peerConnection = await createPeerConnection(config);

    // Send ICE candidates to the other peer via Signaling
    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate.candidate != null && _peerId != null) {
        signaling.sendIce(to: _peerId!, candidate: candidate.toMap());
      }
    };

    // When we receive a video track (Viewer side)
    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        renderer.srcObject = event.streams[0];
        debugPrint('[WebRTC] Remote stream attached to renderer');
      }
    };

    _peerConnection!.onConnectionState = (state) {
      debugPrint('[WebRTC] Connection State: $state');
    };
  }

  // ── HOST SIDE (Capturing Screen) ──────────────────────────
  Future<void> startHost(String targetId) async {
    _peerId = targetId;
    await _createPeerConnection();

    // Capture the screen
    final mediaConstraints = {
      'video': true,
      'audio': false, // Audio comes later
    };
    
    _localStream = await navigator.mediaDevices.getDisplayMedia(mediaConstraints);
    
    for (final track in _localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
    }

    // Create Offer
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    
    // Send Offer via Signaling
    signaling.sendOffer(to: targetId, sdp: offer.toMap());
    debugPrint('[WebRTC] Host created Offer and sent to $targetId');
  }

  // ── VIEWER SIDE (Receiving Screen) ────────────────────────
  Future<void> handleOffer(String fromId, Map<String, dynamic> sdpMap) async {
    _peerId = fromId;
    await _createPeerConnection();

    final offer = RTCSessionDescription(sdpMap['sdp'], sdpMap['type']);
    await _peerConnection!.setRemoteDescription(offer);

    // Create Answer
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    // Send Answer via Signaling
    signaling.sendAnswer(to: fromId, sdp: answer.toMap());
    debugPrint('[WebRTC] Viewer created Answer and sent to $fromId');
  }

  Future<void> handleAnswer(Map<String, dynamic> sdpMap) async {
    final answer = RTCSessionDescription(sdpMap['sdp'], sdpMap['type']);
    await _peerConnection!.setRemoteDescription(answer);
    debugPrint('[WebRTC] Host received Answer');
  }

  Future<void> handleIce(Map<String, dynamic> candidateMap) async {
    final candidate = RTCIceCandidate(
      candidateMap['candidate'],
      candidateMap['sdpMid'],
      candidateMap['sdpMLineIndex'],
    );
    await _peerConnection?.addCandidate(candidate);
  }

  Future<void> dispose() async {
    _localStream?.getTracks().forEach((track) => track.stop());
    await _peerConnection?.close();
    _peerConnection = null;
    _localStream = null;
    renderer.srcObject = null;
    _peerId = null;
  }
}