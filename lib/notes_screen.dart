import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'models/note_model.dart';
import 'note_detail_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> with AutomaticKeepAliveClientMixin<NotesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _notesCollection {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception("User is not logged in. Cannot access notes.");
    }
    return _firestore.collection('users').doc(userId).collection('notes');
  }

  Future<void> _addNote(String title, String content) async {
    if (title.isEmpty && content.isEmpty) {
      // Avoid using context in async gaps if possible
      return;
    }
    try {
      await _notesCollection.add({
        'title': title,
        'content': content,
        'createdAt': Timestamp.now(),
      });
    } catch (e) {
      // Handle error, maybe log it
    }
  }

  Future<void> _updateNote(Note note, String newTitle, String newContent) async {
    if (newTitle.isEmpty && newContent.isEmpty) {
      return;
    }
    try {
      await _notesCollection.doc(note.id).update({
        'title': newTitle,
        'content': newContent,
      });
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _deleteNote(String noteId) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this note?'),
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
      } catch (e) {
        // Handle error
      }
    }
  }

  void _showAddEditNoteDialog({Note? note}) {
    final titleController = TextEditingController(text: note?.title ?? '');
    final contentController = TextEditingController(text: note?.content ?? '');
    final isSavingNotifier = ValueNotifier<bool>(false);

    showDialog(
      context: context,
      barrierDismissible: false,
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
                      decoration: const InputDecoration(labelText: 'Title'),
                      textCapitalization: TextCapitalization.sentences,
                      readOnly: isSaving,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: contentController,
                      decoration: const InputDecoration(labelText: 'Content'),
                      maxLines: 8,
                      textCapitalization: TextCapitalization.sentences,
                      readOnly: isSaving,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    isSavingNotifier.value = true;
                    final title = titleController.text.trim();
                    final content = contentController.text.trim();

                    if (note == null) {
                      await _addNote(title, content);
                    } else {
                      await _updateNote(note, title, content);
                    }
                    
                    // *** FIX: Pop the dialog's context directly after the await. ***
                    // This is more stable than using a post-frame callback.
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
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
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: _notesCollection.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('An error occurred.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
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
        onPressed: () => _showAddEditNoteDialog(),
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
      child: ListTile(
        title: Text(
          note.title.isEmpty ? "Untitled Note" : note.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (contentSnippet.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(contentSnippet),
            ],
            const SizedBox(height: 8),
            Text(
              'Created: ${DateFormat.yMMMd().format(note.createdAt.toDate())}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _showAddEditNoteDialog(note: note),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.error),
              onPressed: () => _deleteNote(note.id),
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
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.note_add_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('No notes yet!', style: TextStyle(fontSize: 22, color: Colors.grey)),
          SizedBox(height: 8),
          Text('Tap \'+\' to add your first note.', style: TextStyle(fontSize: 16, color: Colors.grey)),
        ],
      ),
    );
  }
}
