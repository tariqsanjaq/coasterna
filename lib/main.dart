import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/presentation/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coasterna',
      theme: appTheme,
      home: SplashScreen(
        // Temporary placeholder destination until the real search
        // screen exists. Replace nextPage once it is built.
        nextPage: Scaffold(
          appBar: AppBar(title: const Text('Coasterna')),
          body: const Center(child: Text('Home placeholder')),
        ),
      ),
    );
  }
}