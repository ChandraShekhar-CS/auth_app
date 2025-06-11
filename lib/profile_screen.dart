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

class _ProfileScreenState extends State<ProfileScreen> with AutomaticKeepAliveClientMixin<ProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _deleteConfirmController = TextEditingController();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;
  File? _pickedImageFile;
  String? _photoUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (_currentUser != null) {
      _usernameController.text = _currentUser!.displayName ?? '';
      _photoUrl = _currentUser!.photoURL;
    }
  }

  Future<void> _pickImage() async {
    final pickedImage = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 150,
    );

    if (pickedImage == null) return;

    setState(() {
      _pickedImageFile = File(pickedImage.path);
    });

    await _uploadImage();
  }

  Future<void> _uploadImage() async {
    final user = _currentUser;
    if (_pickedImageFile == null || user == null) return;

    setState(() => _isUploading = true);
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('user_images')
          .child('${user.uid}.jpg');

      await storageRef.putFile(_pickedImageFile!);
      final imageUrl = await storageRef.getDownloadURL();

      await user.updatePhotoURL(imageUrl);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'photoUrl': imageUrl}, SetOptions(merge: true));

      if(mounted) {
        setState(() {
            _photoUrl = imageUrl;
        });
      }
    } catch (error) {
      // Handle error
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _updateUsername() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    final user = _currentUser;
    if (!isValid || user == null) return;

    setState(() => _isLoading = true);
    try {
      await user.updateDisplayName(_usernameController.text.trim());
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'displayName': _usernameController.text.trim()},
              SetOptions(merge: true));
    } catch (error) {
      // Handle error
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
<<<<<<< HEAD
  
  void _showChangePasswordDialog() {
    if (_currentUser == null) return;

    final GlobalKey<FormState> passwordFormKey = GlobalKey<FormState>();
    final TextEditingController currentPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
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
                  decoration: const InputDecoration(labelText: 'Current Password'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your current password.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New Password'),
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
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (passwordFormKey.currentState?.validate() == true) {
                  await _changePassword(
                    currentPasswordController.text,
                    newPasswordController.text,
                  );
                  if(dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                }
              },
              child: const Text('Update Password'),
            )
          ],
        );
      },
    ).whenComplete(() {
      currentPasswordController.dispose();
      newPasswordController.dispose();
    });
  }

  Future<void> _changePassword(String currentPassword, String newPassword) async {
=======

void _showChangePasswordDialog() {
  if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User not found. Please re-login.'), backgroundColor: Colors.red),
    );
    return;
  }

  final GlobalKey<FormState> passwordFormKey = GlobalKey<FormState>();
  final TextEditingController currentPasswordController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();

  showDialog(
    context: context, // Screen's context
    builder: (dialogOuterContext) { // Context for the dialog's frame
      final NavigatorState capturedDialogNavigator = Navigator.of(dialogOuterContext);

      return Builder( // New Builder widget
        builder: (dialogInnerContext) { // Fresh context for AlertDialog
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
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your current password.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      border: OutlineInputBorder(),
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
                onPressed: () {
                  if (capturedDialogNavigator.canPop()) {
                    capturedDialogNavigator.pop();
                  }
                  // Controllers are disposed in .then() or .whenComplete()
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (passwordFormKey.currentState?.validate() == true) {
                    final String currentPasswordVal = currentPasswordController.text;
                    final String newPasswordVal = newPasswordController.text;

                    await _changePassword(
                      currentPasswordVal,
                      newPasswordVal,
                    );

                    if (!mounted) return;

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && capturedDialogNavigator.canPop()) {
                        capturedDialogNavigator.pop();
                      }
                    });
                  }
                },
                child: const Text('Update Password'),
              )
            ],
          );
        }
      );
    },
  ).whenComplete(() { // This .whenComplete is on the showDialog Future
    currentPasswordController.dispose();
    newPasswordController.dispose();
  });
}

  // Handles the logic for changing the user's password.
  Future<void> _changePassword(
      String currentPassword, String newPassword) async {
>>>>>>> 770337839f3016115ede58c4cbe2b7bfa043cff5
    final user = _currentUser;
    if (user == null || user.email == null) return;

    setState(() => _isLoading = true);
    try {
      final cred = EmailAuthProvider.credential(
          email: user.email!, password: currentPassword);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
    } catch (error) {
      // handle error
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  void _showDeleteAccountConfirmationDialog() {
     if (_currentUser == null) return;
    _deleteConfirmController.clear();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Account Permanently?'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text('This action is irreversible.'),
                const SizedBox(height: 16),
                const Text('Type "DELETE" to confirm:'),
                const SizedBox(height: 8),
                TextField(
                  controller: _deleteConfirmController,
                  decoration: const InputDecoration(hintText: 'DELETE'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () {
                if (_deleteConfirmController.text == "DELETE") {
                    Navigator.of(context).pop();
                    _deleteAccount();
                }
              },
              child: const Text('Confirm Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAccount() async {
    final user = _currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);
    try {
      await user.delete();
    } catch (e) {
      // handle error
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _deleteConfirmController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    super.build(context);
=======
    super.build(context); // Call super.build
    // If for some reason this screen is built without a user, show a message.
>>>>>>> 770337839f3016115ede58c4cbe2b7bfa043cff5
    if (_currentUser == null) {
      return const Center(child: Text("No user logged in."));
    }
    
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey.shade300,
                backgroundImage:
                    _photoUrl != null ? NetworkImage(_photoUrl!) : null,
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
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
          child: Text(_currentUser?.email ?? 'user@example.com'),
        ),
        const SizedBox(height: 32),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Edit Profile', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(labelText: 'Username'),
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
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.lock_reset_rounded),
                title: const Text('Change Password'),
                onTap: _showChangePasswordDialog,
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.delete_forever, color: Colors.red.shade700),
                title: Text('Delete Account', style: TextStyle(color: Colors.red.shade700)),
                onTap: _showDeleteAccountConfirmationDialog,
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.logout, color: Colors.blue.shade700),
                title: Text('Sign Out', style: TextStyle(color: Colors.blue.shade700)),
                onTap: _signOut,
              ),
            ],
          ),
        )
      ],
    );
  }
}
