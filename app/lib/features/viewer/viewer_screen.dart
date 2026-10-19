import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../services/webrtc_service.dart';
import '../../core/theme.dart';

class ViewerScreen extends StatelessWidget {
  final WebRTCService webrtc;
  final String peerId;

  const ViewerScreen({super.key, required this.webrtc, required this.peerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Remote Session: $peerId'),
        backgroundColor: AppTheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.danger),
            onPressed: () {
              Navigator.pop(context);
            },
          )
        ],
      ),
      body: Center(
        child: ValueListenableBuilder<RTCVideoValue>(
          valueListenable: webrtc.renderer,
          builder: (context, value, child) {
            if (!value.renderVideo) {
              return const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  SizedBox(height: 16),
                  Text(
                    'Waiting for video stream...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              );
            }
            return RTCVideoView(
              webrtc.renderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
            );
          },
        ),
      ),
    );
  }
}