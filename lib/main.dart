import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
// import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      // options: DefaultFirebaseOptions.currentPlatform, // Uncomment when flutterfire is configured
    );
  } catch (e) {
    // ignore: avoid_print
    print("Firebase not configured: $e");
  }
  runApp(const TyreApp());
}

class TyreApp extends StatelessWidget {
  const TyreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tyre Guard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Roboto', 
      ),
      home: const HomeScreen(),
    );
  }
}
