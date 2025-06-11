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
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _deleteConfirmController =
      TextEditingController();
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

  // --- Image Picking and Uploading ---
  Future<void> _pickImage() async {
    final pickedImage = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
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
    // Create a local variable to ensure the user object is not null in this scope.
    final user = _currentUser;
    if (_pickedImageFile == null || user == null) {
      return;
    }

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

      setState(() {
        _photoUrl = imageUrl;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Profile picture updated!'),
            backgroundColor: Colors.green),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to upload image: $error'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // --- User Data Management ---
  Future<void> _updateUsername() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    // Create a local variable for null safety
    final user = _currentUser;
    if (!isValid || user == null) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      await user.updateDisplayName(_usernameController.text.trim());
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'displayName': _usernameController.text.trim()},
              SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Username updated successfully!'),
            backgroundColor: Colors.green),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to update username: $error'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- New Function to show change password dialog ---
  void _showChangePasswordDialog() {
    // This check is important before showing a dialog that needs the user
    if (_currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not found. Please re-login.'), backgroundColor: Colors.red),
      );
      return;
    }

    final GlobalKey<FormState> passwordFormKey = GlobalKey<FormState>();
    final TextEditingController currentPasswordController =
        TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();

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
                Navigator.of(context).pop();
                currentPasswordController.dispose();
                newPasswordController.dispose();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async { // Make this async
                if (passwordFormKey.currentState?.validate() == true) {
                  final String currentPasswordVal = currentPasswordController.text;
                  final String newPasswordVal = newPasswordController.text;

                  final NavigatorState dialogNavigator = Navigator.of(context); // context here is the dialog's context

                  // Optional: Add a local loading state for the dialog button itself
                  // For now, _changePassword handles its own _isLoading for the screen

                  await _changePassword( // ****** CRITICAL: await this call ******
                    currentPasswordVal,
                    newPasswordVal,
                  );

                  if (!mounted) return; // Refers to _ProfileScreenState.mounted

                  if (dialogNavigator.canPop()) {
                    dialogNavigator.pop();
                  }
                  // Disposing controllers is already handled by .then() on showDialog
                }
              },
              child: const Text('Update Password'),
            )
          ],
        );
      },
    ).then((_) {
      currentPasswordController.dispose();
      newPasswordController.dispose();
    });
  }

  // Handles the logic for changing the user's password.
  Future<void> _changePassword(
      String currentPassword, String newPassword) async {
    final user = _currentUser;
    if (user == null || user.email == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('User not found. Please re-login.'),
            backgroundColor: Colors.red));
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final cred = EmailAuthProvider.credential(
          email: user.email!, password: currentPassword);
      await user.reauthenticateWithCredential(cred);

      await user.updatePassword(newPassword);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Password updated successfully!'),
              backgroundColor: Colors.green),
        );
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        String errorMessage = 'An error occurred during password change.';
        if (error.code == 'wrong-password') {
          errorMessage = 'The current password you entered is incorrect.';
        } else if (error.code == 'weak-password') {
          errorMessage = 'The new password is too weak.';
        } else {
          errorMessage = error.message ?? errorMessage;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(errorMessage),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('An unexpected error occurred: $e'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Signs out the current user.
  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  // --- Delete Account Functionality ---
  void _showDeleteAccountConfirmationDialog() {
     if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not found. Please re-login.'), backgroundColor: Colors.red));
      return;
    }
    _deleteConfirmController.clear();
    final ValueNotifier<bool> confirmButtonEnabledNotifier =
        ValueNotifier<bool>(false);

    void updateConfirmButtonState() {
      confirmButtonEnabledNotifier.value =
          _deleteConfirmController.text == "DELETE";
    }

    _deleteConfirmController.addListener(updateConfirmButtonState);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Delete Account Permanently?'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    const Text(
                        'This action is irreversible. All your data (tasks, notes, etc.) associated with this account will be removed.'),
                    const SizedBox(height: 16),
                    const Text(
                        'To confirm, please type "DELETE" (all uppercase) in the box below:'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _deleteConfirmController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'DELETE',
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                    child: const Text('Cancel'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    }),
                ValueListenableBuilder<bool>(
                    valueListenable: confirmButtonEnabledNotifier,
                    builder: (context, isEnabled, child) {
                      return ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isEnabled
                              ? Theme.of(context).colorScheme.error
                              : Colors.grey.shade400,
                        ),
                        onPressed: isEnabled
                            ? () {
                                Navigator.of(context).pop();
                                _deleteAccount();
                              }
                            : null,
                        child: const Text('Confirm Delete',
                            style: TextStyle(color: Colors.white)),
                      );
                    }),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      _deleteConfirmController.removeListener(updateConfirmButtonState);
      confirmButtonEnabledNotifier.dispose();
    });
  }

  Future<void> _deleteAccount() async {
    final user = _currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('User not found. Please re-login.'),
            backgroundColor: Colors.red));
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to delete account. Please try again.';
        if (e.code == 'requires-recent-login') {
          errorMessage =
              'This operation is sensitive and requires recent authentication. Please sign out, sign back in, and then try to delete your account again.';
        } else {
          errorMessage = e.message ?? errorMessage;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(errorMessage),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 6)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'An unexpected error occurred while deleting your account: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 6)),
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
    _usernameController.dispose();
    _deleteConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If for some reason this screen is built without a user, show a message.
    if (_currentUser == null) {
      return const Center(
        child: Text("No user logged in. Please restart the app."),
      );
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
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.camera_alt,
                            color: Colors.white, size: 20),
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
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.grey.shade600),
          ),
        ),
        const SizedBox(height: 32),
        Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.lock_reset_rounded),
                title: const Text('Change Password'),
                subtitle: const Text('Update your password'),
                onTap: _showChangePasswordDialog,
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading:
                    Icon(Icons.delete_forever, color: Colors.red.shade700),
                title: Text('Delete Account',
                    style: TextStyle(color: Colors.red.shade700)),
                subtitle:
                    const Text('Permanently remove your account and data'),
                onTap: _showDeleteAccountConfirmationDialog,
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.red.shade700),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading:
                    Icon(Icons.logout, color: Colors.blue.shade700),
                title: Text('Sign Out',
                    style: TextStyle(color: Colors.blue.shade700)),
                onTap: _signOut,
              ),
            ],
          ),
        )
      ],
    );
  }
}
