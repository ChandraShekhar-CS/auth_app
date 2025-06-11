import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single to-do item.
class Todo {
  final String id;
  final String title;
  final bool isDone;
  final bool isImportant;
  final Timestamp createdAt;
  final Timestamp? dueDate;

  Todo({
    required this.id,
    required this.title,
    required this.isDone,
    required this.isImportant,
    required this.createdAt,
    this.dueDate,
  });

  /// Creates a Todo instance from a Firestore document.
  factory Todo.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Todo(
      id: doc.id,
      title: data['title'] ?? '',
      isDone: data['isDone'] ?? false,
      isImportant: data['isImportant'] ?? false,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      dueDate: data['dueDate'], // Can be null
    );
  }
}
