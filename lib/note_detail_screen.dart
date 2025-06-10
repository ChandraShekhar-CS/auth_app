// note_detail_screen.dart
import 'package:flutter/material.dart';
import 'models/note_model.dart'; // Import the Note model.
import 'package:intl/intl.dart'; // For date formatting.

/// A screen that displays the full details of a single [Note].
///
/// This screen is typically navigated to from the [NotesScreen] when a user
/// taps on a note item. It is a read-only view of the note.
class NoteDetailScreen extends StatelessWidget {
  final Note note;

  const NoteDetailScreen({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    // Use a fallback title if the note's title is empty.
    final String appBarTitle = note.title.isNotEmpty ? note.title : "Note Detail";

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display the note title, or "Untitled Note" if empty.
            Text(
              note.title.isNotEmpty ? note.title : "Untitled Note",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            // Display the formatted creation date of the note.
            Text(
              'Created: ${DateFormat.yMMMd().add_jm().format(note.createdAt.toDate())}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            // Display the full content of the note.
            SelectableText( // Use SelectableText for easier copying of note content.
              note.content,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.5, // Increased line height for better readability.
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
