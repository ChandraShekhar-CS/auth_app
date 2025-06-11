// notes_screen.dart
import 'dart:math'; // For String.substring and min function.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'models/note_model.dart'; // Import the Note model.
import 'note_detail_screen.dart'; // Import NoteDetailScreen for viewing.

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Provides a reference to the current user's 'notes' collection.
  CollectionReference get _notesCollection {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      debugPrint("Error: Current user is null in _notesCollection getter.");
      throw Exception("User is not logged in. Cannot access notes.");
    }
    return _firestore.collection('users').doc(userId).collection('notes');
  }

  // Adds a new note to Firestore.
  Future<void> _addNote(String title, String content) async {
    if (title.isEmpty && content.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot save an empty note.')),
        );
      }
      return;
    }
    try {
      await _notesCollection.add({
        'title': title,
        'content': content,
        'createdAt': Timestamp.now(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note added successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add note: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  // Updates an existing note in Firestore.
  Future<void> _updateNote(Note note, String newTitle, String newContent) async {
    if (newTitle.isEmpty && newContent.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot save an empty note. Delete it instead?')),
        );
      }
      return;
    }
    try {
      await _notesCollection.doc(note.id).update({
        'title': newTitle,
        'content': newContent,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note updated successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update note: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  // Deletes a note from Firestore after confirmation.
  Future<void> _deleteNote(String noteId) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this note? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Delete'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        await _notesCollection.doc(noteId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Note deleted successfully!'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete note: $e'), backgroundColor: Theme.of(context).colorScheme.error),
          );
        }
      }
    }
  }

  // Shows a dialog for adding a new note or editing an existing one.
  void _showAddEditNoteDialog({Note? note}) {
    final titleController = TextEditingController(text: note?.title ?? '');
    final contentController = TextEditingController(text: note?.content ?? '');
    final isSavingNotifier = ValueNotifier<bool>(false);

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing while saving
      builder: (dialogContext) {
        return ValueListenableBuilder<bool>(
          valueListenable: isSavingNotifier,
          builder: (context, isSaving, child) {
            return AlertDialog(
              title: Text(note == null ? 'Add New Note' : 'Edit Note'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'Enter note title',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      readOnly: isSaving,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: contentController,
                      decoration: const InputDecoration(
                        labelText: 'Content',
                        hintText: 'Enter note content...',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 8,
                      textCapitalization: TextCapitalization.sentences,
                      readOnly: isSaving,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    isSavingNotifier.value = true;
                    final title = titleController.text.trim();
                    final content = contentController.text.trim();
                    // Capture navigator before the await to avoid using context across async gaps.
                    final navigator = Navigator.of(dialogContext);

                    if (note == null) {
                      await _addNote(title, content);
                    } else {
                      await _updateNote(note, title, content);
                    }

                    if (!mounted) return;

                    // Apply post-frame callback for popping
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && navigator.canPop()) {
                        navigator.pop();
                      }
                    });
                  },
                  child: isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(note == null ? 'Add Note' : 'Save Changes'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      titleController.dispose();
      contentController.dispose();
      isSavingNotifier.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: _notesCollection.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            debugPrint("Error fetching notes: ${snapshot.error}");
            return const Center(child: Text('An error occurred while loading notes.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(); // Shows a message when there are no notes.
          }

          final notes = snapshot.data!.docs
              .map((doc) => Note.fromFirestore(doc))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              return _buildNoteItem(note);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddEditNoteDialog();
        },
        tooltip: 'Add Note',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildNoteItem(Note note) {
    String contentSnippet = note.content.length > 50
        ? '${note.content.substring(0, min(note.content.length, 50))}...'
        : note.content;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        title: Text(
          note.title.isEmpty ? "Untitled Note" : note.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (contentSnippet.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                contentSnippet,
                style: TextStyle(color: Colors.grey.shade600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Created: ${DateFormat.yMMMd().add_jm().format(note.createdAt.toDate())}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit_outlined, color: Colors.grey.shade700),
              onPressed: () {
                _showAddEditNoteDialog(note: note);
              },
              tooltip: 'Edit Note',
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.error),
              onPressed: () {
                _deleteNote(note.id);
              },
              tooltip: 'Delete Note',
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => NoteDetailScreen(note: note)),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_add_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No notes yet!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the \'+\' button to add your first note.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
