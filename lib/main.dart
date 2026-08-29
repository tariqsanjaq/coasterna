import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'core/theme/app_theme.dart';
import 'features/admin/presentation/admin_login_screen.dart';
import 'features/splash/presentation/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const CoasternaApp());
}

class CoasternaApp extends StatelessWidget {
  const CoasternaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coasterna',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      // The Admin Dashboard is web-only: on web the app opens straight
      // on the admin login gate, on mobile it opens the student splash.
      home: kIsWeb ? const AdminLoginScreen() : const SplashScreen(),
    );
  }
}
