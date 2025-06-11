import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single note item.
class Note {
  final String id;
  final String title;
  final String content;
  final Timestamp createdAt;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  /// Creates a Note instance from a Firestore document.
  factory Note.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Note(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }
}
