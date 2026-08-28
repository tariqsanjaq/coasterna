import 'dart:async';
import 'package:flutter/material.dart';

import '../../search/presentation/home_page.dart';

/// Coasterna — Splash screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Color _kBackground = Color(0xFFF7F4EE);
  static const Duration _kSplashDuration = Duration(milliseconds: 1000);

  @override
  void initState() {
    super.initState();
    Timer(_kSplashDuration, () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const HomePage(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,
      body: Center(
        child: Image.asset(
          'assets/icon/icon.png',
          width: 140,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}