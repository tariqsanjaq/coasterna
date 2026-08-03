import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Artboard 1 — Splash. Matches the CERTIFIED
/// Coasterna_UI_Design_v8.7.pdf, page 4, exactly: a light background
/// (not full-color), with a centered card showing the bus+pin mark
/// and the lowercase "coasterna" wordmark underneath.
///
/// Auto-advances to [nextPage] after a fixed delay.
///
/// NOTE: the bus+pin icon below is a built-in Flutter icon stand-in.
/// Swap it for the real brand mark (a designed image asset) once it
/// exists — that is a separate later task.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.nextPage});

  final Widget nextPage;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // initState() runs exactly once, when this widget is first
    // created — the only safe place to start a one-shot timer like
    // this. Starting it inside build() would restart it every redraw.
    Future.delayed(const Duration(seconds: 2), _goToNextPage);
  }

  void _goToNextPage() {
    // If this widget is destroyed before the delay finishes (app
    // closed, hot reload, etc.), calling Navigator here would throw.
    // This guard prevents that.
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => widget.nextPage),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The spec does NOT show a full-color splash — only the small
      // logo card is colored. The screen itself uses the light
      // app background.
      backgroundColor: AppColors.background,
      body: Center(
        child: Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Image.asset(
            'assets/images/coasterna_logo.png',
            width: 140,
          ),
        ),
      ),
    );
  }
}