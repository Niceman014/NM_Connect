import 'package:flutter/material.dart';
import 'core/config.dart';
import 'core/theme.dart';
import 'features/home/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NmConnectApp());
}

class NmConnectApp extends StatelessWidget {
  const NmConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const HomeScreen(),
    );
  }
}