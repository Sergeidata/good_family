import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const FamilyFocusApp());
}

class FamilyFocusApp extends StatelessWidget {
  const FamilyFocusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Good Family',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: const SplashScreen(),
    );
  }
}