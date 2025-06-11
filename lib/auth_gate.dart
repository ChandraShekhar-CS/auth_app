import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:auth_app/auth_screen.dart'; // We will create this next
// And this one too
import 'package:auth_app/main_scaffold.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        // Listen to the authentication state changes.
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            debugPrint("AuthGate Stream Error: ${snapshot.error}");
            return const AuthScreen();
          }

          if (snapshot.hasData && snapshot.data != null) {
            return const MainScaffold();
          }

          return const AuthScreen();
        },
      ),
    );
  }
}
