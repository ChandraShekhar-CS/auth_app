import 'dart:async';
import 'package:flutter/material.dart';
import 'package:auth_app/auth_gate.dart'; // We will navigate to the AuthGate

/// A splash screen that shows for a few seconds when the app starts.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Set a timer to navigate away from the splash screen after 3 seconds.
    Timer(const Duration(seconds: 3), () {
      // Ensure the widget is still in the tree before navigating.
      if (mounted) {
        // Replace the current screen with the AuthGate so the user can't
        // navigate back to the splash screen.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthGate()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // You can set a custom background color for your splash screen.
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // This displays your logo from the assets folder.
            // Make sure 'assets/logo.png' exists.
            Image.asset('assets/logo.png', height: 150),
            const SizedBox(height: 24),
            // Shows a loading indicator below the logo.
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
            ),
          ],
        ),
      ),
    );
  }
}