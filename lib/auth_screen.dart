import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // A boolean to toggle between login and signup forms.
  bool _isLogin = true;
  // State for loading indicator.
  bool _isLoading = false;
  // Form key for validation.
  final _formKey = GlobalKey<FormState>();

  // Text editing controllers to get user input.
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  // Controller for the forgot password email dialog.
  final TextEditingController _forgotPasswordEmailController =
      TextEditingController();

  // Handles the primary authentication logic (sign-in or sign-up).
  void _submitForm() async {
    final bool isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return; // If form is not valid, do nothing.
    }

    // Hide keyboard
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        // Attempt to sign in the user.
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        // Navigation on success is handled by AuthGate.
      } else {
        // Attempt to create a new user account.
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        // Navigation on success is handled by AuthGate.
      }
    } on FirebaseAuthException catch (error) {
      String errorMessage = 'Authentication failed. Please try again.';
      if (error.message != null && error.message!.isNotEmpty) {
        errorMessage = error.message!;
      }
      // Map common error codes to more user-friendly messages.
      switch (error.code) {
        case 'user-not-found':
          errorMessage =
              'No user found with that email. Please check your email or sign up.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password. Please try again.';
          break;
        case 'email-already-in-use':
          errorMessage =
              'An account already exists with that email. Please sign in or use a different email.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is badly formatted.';
          break;
        case 'weak-password':
          errorMessage =
              'The password is too weak. Please choose a stronger password.';
          break;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      // Catch any other unexpected errors.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text('An unexpected error occurred. Please try again later.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _forgotPasswordEmailController
        .dispose(); // Dispose the forgot password controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // =================================================================
                // START: LOGO AND COMPANY NAME SECTION
                // =================================================================

                // TODO: Replace this Icon widget with your actual logo.
                // For example, if your logo is in 'assets/logo.png', use:
                 
                
                  Image.asset('assets/logo.png', height: 80),
                
                const SizedBox(height: 16),

                // Main App Title
                const Text(
                  'NetProphetsGlobal',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Company Name
                const Text(
                  'Technology For Change',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 48),

                // =================================================================
                // END: LOGO AND COMPANY NAME SECTION
                // =================================================================

                // Section title for Login/Signup form
                Text(
                  _isLogin ? 'Sign In to Your Account' : 'Create a New Account',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Email Input Field
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email Address'),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.none,
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty ||
                        !value.contains('@')) {
                      return 'Please enter a valid email address.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password Input Field
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.trim().length < 6) {
                      return 'Password must be at least 6 characters long.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Submit Button
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _submitForm,
                        child: Text(_isLogin ? 'Sign In' : 'Sign Up'),
                      ),
                const SizedBox(height: 16),

                // Toggle Button to switch between Sign In and Sign Up
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLogin = !_isLogin;
                    });
                  },
                  child: Text(
                    _isLogin
                        ? 'Don\'t have an account? Sign Up'
                        : 'Already have an account? Sign In',
                  ),
                ),
                // "Forgot Password?" Button - visible only on login form
                if (_isLogin)
                  TextButton(
                    onPressed: _showForgotPasswordDialog,
                    child: const Text('Forgot Password?'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Displays a dialog for the user to request a password reset email.
  void _showForgotPasswordDialog() {
    _forgotPasswordEmailController.clear(); // Clear any previous input.
    showDialog(
      context: context,
      builder: (dialogContext) {
        // Use dialogContext to avoid confusion with screen context
        return AlertDialog(
          title: const Text('Reset Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  "Enter your email address and we'll send you a link to reset your password."),
              const SizedBox(height: 20), // Increased spacing
              TextField(
                controller: _forgotPasswordEmailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'you@example.com',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined), // Added icon
                ),
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () =>
                  Navigator.of(dialogContext).pop(), // Use dialogContext
            ),
            ElevatedButton(
              child: const Text('Send Reset Email'),
              onPressed: () async {
                final email = _forgotPasswordEmailController.text.trim();
                if (email.isEmpty || !email.contains('@')) {
                  // Show SnackBar inside the dialog if possible, or ensure it's clearly associated.
                  // For simplicity, using screen's ScaffoldMessenger.
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          const Text('Please enter a valid email address.'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                  return; // Keep dialog open for correction.
                }

                Navigator.of(dialogContext)
                    .pop(); // Close dialog before async operation.

                // Show loading indicator on the main screen.
                if (mounted) setState(() => _isLoading = true);

                try {
                  await FirebaseAuth.instance
                      .sendPasswordResetEmail(email: email);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Password reset email sent to $email. Please check your inbox (and spam folder).'),
                        backgroundColor: Colors.green, // Success color
                      ),
                    );
                  }
                } on FirebaseAuthException catch (e) {
                  String errorMessage =
                      'Failed to send reset email. Please try again.';
                  if (e.code == 'user-not-found') {
                    errorMessage = 'No user found with this email address.';
                  } else if (e.code == 'invalid-email') {
                    errorMessage = 'The email address is not valid.';
                  }
                  // Other codes like 'too-many-requests' could be handled.
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(errorMessage),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                } catch (e) {
                  // Catch any other unexpected errors.
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                            'An unexpected error occurred. Please try again.'),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() => _isLoading = false); // Hide loading indicator.
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }
}