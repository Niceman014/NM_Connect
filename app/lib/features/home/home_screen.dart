import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../services/signaling_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _sig = SignalingService();
  final _targetCtrl = TextEditingController();
  final _log = <String>[];
  StreamSubscription? _msgSub;

  String? _myId;
  bool _online = false;
  String? _incomingFrom;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('device_id');
    if (id == null) {
      id = _generateId();
      await prefs.setString('device_id', id);
    }
    _myId = id;

    await _sig.connect(deviceId: id, deviceName: 'NM Connect (${id.substring(0, 4)})');
    _msgSub = _sig.messages.listen(_onMessage);

    setState(() {});
  }

  String _generateId() {
    final rnd = Random.secure();
    final n = rnd.nextInt(900000000) + 100000000; // 9-digit, no leading zero
    return n.toString();
  }

  Future<void> _regenerateId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = _generateId();
    await prefs.setString('device_id', id);
    await _sig.disconnect();
    if (!mounted) return;
    setState(() {
      _myId = id;
      _online = false;
      _log.clear();
    });
    await _sig.connect(deviceId: id, deviceName: 'NM Connect (${id.substring(0, 4)})');
    _msgSub?.cancel();
    _msgSub = _sig.messages.listen(_onMessage);
  }

  void _onMessage(Map<String, dynamic> msg) {
    final type = msg['type'];
    _appendLog('← $type');
    if (type == 'registered') {
      setState(() => _online = true);
    } else if (type == 'connect-request') {
      setState(() => _incomingFrom = msg['from'] as String);
      _showAcceptDialog(msg['from'] as String, msg['fromDeviceName'] as String? ?? 'Unknown');
    } else if (type == 'connect-response') {
      final accepted = msg['accepted'] == true;
      _appendLog(accepted ? '✓ peer accepted' : '✗ peer declined');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(accepted ? 'Peer accepted — handshake next step!' : 'Peer declined')),
        );
      }
      setState(() => _incomingFrom = null);
    } else if (type == 'error') {
      final code = msg['code'];
      _appendLog('⚠ error: $code');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $code')));
      }
    }
  }

  void _appendLog(String line) {
    if (!mounted) return;
    setState(() {
      _log.insert(0, '${DateTime.now().toIso8601String().substring(11, 19)}  $line');
      if (_log.length > 8) _log.removeLast();
    });
  }

  Future<void> _showAcceptDialog(String from, String name) async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Incoming connection'),
        content: Text('$name ($from)\nwants to connect to this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Deny'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    _sig.respondConnection(to: from, accepted: accepted ?? false);
    setState(() => _incomingFrom = null);
  }

  void _connect() {
    final target = _targetCtrl.text.trim();
    if (target.length != 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a 9-digit ID')),
      );
      return;
    }
    if (target == _myId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot connect to yourself')),
      );
      return;
    }
    _sig.requestConnection(target);
    _appendLog('→ connect-request to $target');
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _sig.disconnect();
    _targetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.cast_connected, color: AppTheme.accent),
            const SizedBox(width: 8),
            Text('NM Connect', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            _StatusDot(online: _online),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _label('This device'),
              _idCard(),
              const SizedBox(height: 24),
              _label('Connect to another device'),
              TextField(
                controller: _targetCtrl,
                keyboardType: TextInputType.number,
                maxLength: 9,
                style: const TextStyle(fontSize: 20, letterSpacing: 3),
                decoration: const InputDecoration(
                  hintText: '9-digit ID',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _online ? _connect : null,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Connect'),
                ),
              ),
              const SizedBox(height: 32),
              _label('Session log'),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _log.isEmpty ? '— nothing yet —' : _log.join('\n'),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1.5,
            color: Colors.white54,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _idCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  _myId ?? '…',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 6,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Regenerate ID',
                icon: const Icon(Icons.refresh),
                onPressed: _regenerateId,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Share this ID with the person you want to help or receive help from.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool online;
  const _StatusDot({required this.online});
  @override
  Widget build(BuildContext context) {
    final c = online ? AppTheme.accent : Colors.orange;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(online ? 'Online' : 'Connecting…', style: TextStyle(color: c, fontSize: 12)),
      ],
    );
  }
}