import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/config.dart';

/// Client-side signaling connection.
///
/// Usage:
///   final svc = SignalingService();
///   await svc.connect(deviceId: '123456789', deviceName: 'My PC');
///   svc.messages.listen((msg) { ... });
class SignalingService {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  String? _deviceId;
  String? _deviceName;
  bool _registered = false;
  Timer? _reconnectTimer;
  bool _manuallyClosed = false;

  /// All incoming messages from the server.
  Stream<Map<String, dynamic>> get messages => _controller.stream;

  String? get deviceId => _deviceId;
  bool get isRegistered => _registered;

  Future<void> connect({required String deviceId, required String deviceName}) async {
    _deviceId = deviceId;
    _deviceName = deviceName;
    _manuallyClosed = false;
    await _openSocket();
  }

  Future<void> _openSocket() async {
    try {
      debugPrint('[signaling] connecting to ${AppConfig.signalingUrl}…');
      _channel = WebSocketChannel.connect(Uri.parse(AppConfig.signalingUrl));
      await _channel!.ready;
      debugPrint('[signaling] socket open');
      _registered = false;

      _sub = _channel!.stream.listen(
        _onData,
        onDone: _onDisconnected,
        onError: (e) => debugPrint('[signaling] error: $e'),
      );

      send({
        'type': 'register',
        'v': AppConfig.protocolVersion,
        'deviceId': _deviceId,
        'deviceName': _deviceName,
      });
    } catch (e) {
      debugPrint('[signaling] connect failed: $e');
      _scheduleReconnect();
    }
  }

  void _onData(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      if (msg['type'] == 'registered') {
        _registered = true;
        debugPrint('[signaling] registered as ${msg['deviceId']}');
      }
      _controller.add(msg);
    } catch (e) {
      debugPrint('[signaling] bad message: $e');
    }
  }

  void _onDisconnected() {
    debugPrint('[signaling] socket closed');
    _registered = false;
    _sub?.cancel();
    _sub = null;
    _channel = null;
    if (!_manuallyClosed) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!_manuallyClosed && _deviceId != null) _openSocket();
    });
  }

  void send(Map<String, dynamic> msg) {
    if (_channel == null) {
      debugPrint('[signaling] send skipped — no socket');
      return;
    }
    _channel!.sink.add(jsonEncode(msg));
  }

  // ── Protocol helpers ─────────────────────────────────────

  void requestConnection(String to) => send({
        'type': 'connect-request',
        'v': AppConfig.protocolVersion,
        'to': to,
      });

  void respondConnection({required String to, required bool accepted}) => send({
        'type': 'connect-response',
        'v': AppConfig.protocolVersion,
        'to': to,
        'accepted': accepted,
      });

  void sendOffer({required String to, required Map<String, dynamic> sdp}) =>
      send({'type': 'offer', 'v': AppConfig.protocolVersion, 'to': to, 'sdp': sdp});

  void sendAnswer({required String to, required Map<String, dynamic> sdp}) =>
      send({'type': 'answer', 'v': AppConfig.protocolVersion, 'to': to, 'sdp': sdp});

  void sendIce({required String to, required Map<String, dynamic> candidate}) =>
      send({'type': 'ice', 'v': AppConfig.protocolVersion, 'to': to, 'candidate': candidate});

  void sendBye({required String to, String reason = 'user-closed'}) => send(
      {'type': 'bye', 'v': AppConfig.protocolVersion, 'to': to, 'reason': reason});

  Future<void> disconnect() async {
    _manuallyClosed = true;
    _reconnectTimer?.cancel();
    await _sub?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _registered = false;
  }
}