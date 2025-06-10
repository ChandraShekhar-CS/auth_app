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
  // Controller for delete account confirmation text field
  final TextEditingController _deleteConfirmController = TextEditingController();
  final User? _currentUser = FirebaseAuth.instance.currentUser; // Made User nullable for robustness
  bool _isLoading = false; // General loading state for multiple operations
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
    final GlobalKey<FormState> passwordFormKey = GlobalKey<FormState>();
    final TextEditingController currentPasswordController = TextEditingController();
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
                const SizedBox(height: 16), // Increased spacing
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
                currentPasswordController.dispose(); // Dispose here
                newPasswordController.dispose();   // Dispose here
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (passwordFormKey.currentState?.validate() == true) {
                  _changePassword(
                    currentPasswordController.text,
                    newPasswordController.text,
                  );
                  Navigator.of(context).pop();
                }
                // Controllers are disposed in .then() for this path
              },
              child: const Text('Update Password'),
            )
          ],
        );
      },
    ).then((_) {
        // Ensure controllers are disposed even if dialog is dismissed by other means
        currentPasswordController.dispose();
        newPasswordController.dispose();
    });
  }

  // Handles the logic for changing the user's password.
  Future<void> _changePassword(String currentPassword, String newPassword) async {
    if (_currentUser == null || _currentUser!.email == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not found. Please re-login.'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final cred = EmailAuthProvider.credential(email: _currentUser!.email!, password: currentPassword);
      await _currentUser!.reauthenticateWithCredential(cred);
      
      await _currentUser!.updatePassword(newPassword);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully!'), backgroundColor: Colors.green),
        );
      }
    } on FirebaseAuthException catch (error) {
       if (mounted) {
         String errorMessage = 'An error occurred during password change.';
         if (error.code == 'wrong-password') {
           errorMessage = 'The current password you entered is incorrect.';
         } else if (error.code == 'weak-password'){
            errorMessage = 'The new password is too weak.';
         } else {
           errorMessage = error.message ?? errorMessage;
         }
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Theme.of(context).colorScheme.error),
        );
       }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
    finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Signs out the current user.
  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  // --- Delete Account Functionality ---
  void _showDeleteAccountConfirmationDialog() {
    _deleteConfirmController.clear(); // Clear previous input
    // Using a ValueNotifier to manage the enabled state of the confirm button.
    // This is created here and disposed in .whenComplete().
    final ValueNotifier<bool> confirmButtonEnabledNotifier = ValueNotifier<bool>(false);

    // Listener to update the button state based on text field content.
    void updateConfirmButtonState() {
      confirmButtonEnabledNotifier.value = _deleteConfirmController.text == "DELETE";
    }
    _deleteConfirmController.addListener(updateConfirmButtonState);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        // StatefulBuilder is used here to rebuild the dialog's actions (the button)
        // when the ValueNotifier changes, without rebuilding the whole ProfileScreen state.
        return StatefulBuilder(
          builder: (context, setDialogState) { // setDialogState for local dialog rebuilds
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
                      onChanged: (value) {
                        // No need to call setDialogState if ValueListenableBuilder is used for the button.
                        // The listener already updates the notifier.
                        // However, if other parts of dialog content depended on this, setDialogState would be useful.
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Listener and notifier are cleaned up in .whenComplete()
                  }
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: confirmButtonEnabledNotifier,
                  builder: (context, isEnabled, child) {
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isEnabled ? Theme.of(context).colorScheme.error : Colors.grey.shade400,
                      ),
                      onPressed: isEnabled
                        ? () {
                            Navigator.of(context).pop(); // Close dialog first
                            _deleteAccount();      // Proceed with deletion
                          }
                        : null, // Button is disabled if not confirmed
                      child: const Text('Confirm Delete', style: TextStyle(color: Colors.white)),
                    );
                  }
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      // Clean up the listener and notifier to prevent memory leaks.
      _deleteConfirmController.removeListener(updateConfirmButtonState);
      confirmButtonEnabledNotifier.dispose();
    });
  }

  // Handles the actual account deletion process.
  Future<void> _deleteAccount() async {
    if (_currentUser == null) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not found. Please re-login.'), backgroundColor: Colors.red));
      return;
    }

    if (!mounted) return; // Check mounted state before async operations
    setState(() => _isLoading = true);

    // IMPORTANT: Deleting a user account via `_currentUser.delete()` only removes the
    // Firebase Authentication user. All associated data in Firestore (like todos, notes under /users/{userId})
    // and Firebase Storage (if any user-specific files were stored) WILL NOT be automatically deleted.
    //
    // A Firebase Cloud Function triggered by `functions.auth.user().onDelete()` is ESSENTIAL
    // to ensure complete data removal and prevent orphaned data and associated costs.
    //
    // The Cloud Function should perform the following actions:
    // 1. Get the `uid` of the deleted user from the event context.
    // 2. Delete the user's main document from the `/users/{uid}` collection in Firestore.
    //    Example: `admin.firestore().collection('users').doc(uid).delete();`
    // 3. Recursively delete all documents within the user's `/todos` sub-collection (e.g., `/users/{uid}/todos`).
    //    This requires specific logic, often involving batch deletes or iterating through documents.
    //    Example: `const todosPath = `users/${uid}/todos`; // ...logic to delete all documents...`
    // 4. Recursively delete all documents within the user's `/notes` sub-collection (e.g., `/users/{uid}/notes`).
    //    Example: `const notesPath = `users/${uid}/notes`; // ...logic to delete all documents...`
    // 5. Delete any files associated with the user in Firebase Storage, such as their profile picture.
    //    Example: `admin.storage().bucket().file(`user_images/${uid}.jpg`).delete();`
    //
    // Without this Cloud Function, user data will remain in Firestore and Storage,
    // potentially leading to privacy concerns and unnecessary storage costs.

    try {
      await _currentUser!.delete();
      // If successful, AuthGate will handle navigation to AuthScreen due to user state change.
      // A SnackBar here might not be visible if navigation is too fast.
      if (mounted) {
         // Optionally, show a brief success message if navigation isn't immediate.
         // ScaffoldMessenger.of(context).showSnackBar(
         //   const SnackBar(content: Text('Account deleted successfully.'), backgroundColor: Colors.green),
         // );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to delete account. Please try again.';
        if (e.code == 'requires-recent-login') {
          errorMessage =
              'This operation is sensitive and requires recent authentication. Please sign out, sign back in, and then try to delete your account again.';
        } else {
          errorMessage = e.message ?? errorMessage; // Use Firebase's message if available
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Theme.of(context).colorScheme.error, duration: const Duration(seconds: 6)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('An unexpected error occurred while deleting your account: $e'), backgroundColor: Theme.of(context).colorScheme.error, duration: const Duration(seconds: 6)),
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
    // _deleteConfirmController listener and ValueNotifier are disposed in .whenComplete of showDialog.
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
                onTap: _showChangePasswordDialog,
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Icon(Icons.delete_forever, color: Colors.red.shade700),
                title: Text('Delete Account', style: TextStyle(color: Colors.red.shade700)),
                subtitle: const Text('Permanently remove your account and data'),
                onTap: _showDeleteAccountConfirmationDialog,
                trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red.shade700),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Icon(Icons.logout, color: Colors.blue.shade700), // Changed color for differentiation
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
