import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/presentation/splash_screen.dart';
import 'features/search/presentation/home_page.dart';
import 'features/admin/presentation/admin_login_screen.dart';


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
      home: kIsWeb
          ? const AdminLoginScreen()
          : SplashScreen(nextPage: const HomePage()),
    );
  }
}