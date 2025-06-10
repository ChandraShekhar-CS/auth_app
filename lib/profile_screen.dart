import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  File? _pickedImageFile;
  String? _photoUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill the text fields with user data
    if (_currentUser?.displayName != null) {
      _usernameController.text = _currentUser!.displayName!;
    }
    _photoUrl = _currentUser?.photoURL;
  }

  // --- Image Picking and Uploading ---
  Future<void> _pickImage() async {
    final pickedImage = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 50, // Compress image to save space
      maxWidth: 150,
    );

    if (pickedImage == null) {
      return;
    }

    setState(() {
      _pickedImageFile = File(pickedImage.path);
    });

    await _uploadImage();
  }

  Future<void> _uploadImage() async {
    if (_pickedImageFile == null || _currentUser == null) return;

    setState(() => _isUploading = true);
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('user_images')
          .child('${_currentUser.uid}.jpg');

      await storageRef.putFile(_pickedImageFile!);
      final imageUrl = await storageRef.getDownloadURL();

      // Update user profile with new image URL
      await _currentUser.updatePhotoURL(imageUrl);
      // Also save to Firestore for easy access elsewhere
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.uid)
          .set({'photoUrl': imageUrl}, SetOptions(merge: true));

      setState(() {
        _photoUrl = imageUrl;
      });
       if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated!'), backgroundColor: Colors.green),
      );

    } catch (error) {
       if (!mounted) return;
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image: $error'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }


  // --- User Data Management ---
  Future<void> _updateUsername() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || _currentUser == null) return;

    setState(() => _isLoading = true);
    try {
      await _currentUser.updateDisplayName(_usernameController.text.trim());
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.uid)
          .set({'displayName': _usernameController.text.trim()}, SetOptions(merge: true));
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username updated successfully!'), backgroundColor: Colors.green),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update username: $error'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- New Function to show change password dialog ---
  void _showChangePasswordDialog() {
    final passwordFormKey = GlobalKey<FormState>();
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();

    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Change Password'),
            content: Form(
              key: passwordFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Current Password',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your current password.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().length < 6) {
                        return 'Password must be at least 6 characters long.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (passwordFormKey.currentState!.validate()) {
                    _changePassword(
                      currentPasswordController.text,
                      newPasswordController.text,
                    );
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Update'),
              )
            ],
          );
        });
  }

  Future<void> _changePassword(String currentPassword, String newPassword) async {
    if (_currentUser == null || _currentUser.email == null) return;

    // Re-authenticate user before changing password
    try {
      final cred = EmailAuthProvider.credential(
          email: _currentUser.email!, password: currentPassword);
      await _currentUser.reauthenticateWithCredential(cred);
      
      // If re-authentication is successful, update password
      await _currentUser.updatePassword(newPassword);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (error) {
       if (!mounted) return;
       String errorMessage = 'An error occurred.';
       if (error.code == 'wrong-password') {
         errorMessage = 'The current password you entered is incorrect.';
       } else {
         errorMessage = error.message ?? errorMessage;
       }
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    }
  }


  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // --- Profile Picture Section ---
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                child: _photoUrl == null 
                  ? Icon(Icons.person, size: 60, color: Colors.grey.shade600)
                  : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: IconButton(
                    icon: _isUploading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white,))
                          : const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    onPressed: _pickImage,
                  ),
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            _currentUser?.email ?? 'user@example.com',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
          ),
        ),
        const SizedBox(height: 32),

        // --- Edit Profile Card ---
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Edit Profile',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username / Display Name',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
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
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.save_as_outlined),
                        onPressed: _updateUsername,
                        label: const Text('Save Changes'),
                      ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        // --- Account Actions Card ---
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.lock_reset_rounded),
                title: const Text('Change Password'),
                subtitle: const Text('Update your password'),
                onTap: _showChangePasswordDialog, // Updated onTap
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Icon(Icons.logout, color: Colors.red.shade700),
                title: Text('Sign Out', style: TextStyle(color: Colors.red.shade700)),
                onTap: _signOut,
              ),
            ],
          ),
        )
      ],
    );
  }
}
