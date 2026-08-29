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
  static const Color _kFallbackIcon = Color(0xFF0F2B43);
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
          // This is the very first frame the app ever draws, so it must
          // never be the thing that fails. If the asset cannot be
          // resolved, fall back to a plain icon instead of an error box.
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.directions_bus,
            size: 140,
            color: _kFallbackIcon,
          ),
        ),
      ),
    );
  }
}
