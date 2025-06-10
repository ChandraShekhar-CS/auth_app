// note_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single note item.
///
/// Each note has an [id], [title], [content], and a [createdAt] timestamp.
class Note {
  final String id;
  final String title;
  final String content;
  final Timestamp createdAt;

  /// Constructs a [Note].
  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  /// Creates a [Note] instance from a Firestore document snapshot.
  ///
  /// Provides default values for fields if they are missing in the document data
  /// to prevent runtime errors.
  factory Note.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {}; // Handle null data case
    return Note(
      id: doc.id,
      title: data['title'] as String? ?? '', // Safely cast and provide default
      content: data['content'] as String? ?? '', // Safely cast and provide default
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(), // Safely cast and provide default
    );
  }
}
