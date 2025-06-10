import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _currentUser = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (_currentUser?.displayName != null) {
      _usernameController.text = _currentUser!.displayName!;
    }
  }

  void _updateUsername() async {
    final isValid = _formKey.currentState!.validate();
    if (!isValid || _currentUser == null) return;

    setState(() => _isLoading = true);
    try {
      await _currentUser.updateDisplayName(_usernameController.text.trim());
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username updated successfully!'), backgroundColor: Colors.green),
      );
      if(mounted) setState(() {}); 
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update username: $error'), backgroundColor: Colors.red),
      );
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  void _resetPassword() async {
    if (_currentUser?.email == null) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _currentUser!.email!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset link sent to your email!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send reset link: $error'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile Settings')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username / Display Name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Username cannot be empty.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _updateUsername,
                    child: const Text('Update Username'),
                  ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Change Password',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                  'A link to reset your password will be sent to your email address.',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _resetPassword,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                child: const Text('Send Password Reset Link'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
