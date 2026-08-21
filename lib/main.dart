import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/presentation/splash_screen.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/student_login_screen.dart';
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
    // Firebase Auth remembers the signed-in student between app
    // launches, so a returning student skips the login screen and
    // lands straight on search. Anyone not signed in — including a
    // student who chose "Continue without signing in" — sees the
    // login screen, which still offers that same skip button.
    final bool isSignedIn = AuthRepository().currentUser != null;

    return MaterialApp(
      title: 'Coasterna',
      theme: appTheme,
        debugShowCheckedModeBanner: false,
      home: kIsWeb
          ? const AdminLoginScreen()
          : SplashScreen(
        nextPage: isSignedIn
            ? const HomePage()
            : const StudentLoginScreen(),
      ),
    );
  }
}