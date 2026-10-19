/// NM Connect — app-wide constants.
class AppConfig {
  AppConfig._();

  /// Dev: local server. Prod will be wss://signal.nmconnect.app/ws
  static const String signalingUrl = 'ws://localhost:8080/ws';
  static const int protocolVersion = 1;
  static const String appName = 'NM Connect';
}