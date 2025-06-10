// todo_list_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // NEW: Import for date formatting.

// MODIFIED: The Todo model is updated with dueDate and isImportant.
class Todo {
  final String id;
  final String title;
  final bool isDone;
  final Timestamp createdAt;
  final Timestamp? dueDate; // NEW: Nullable field for the due date.
  final bool isImportant; // NEW: Field for task priority.

  Todo({
    required this.id,
    required this.title,
    required this.isDone,
    required this.createdAt,
    this.dueDate, // MODIFIED: Added to constructor
    this.isImportant = false, // MODIFIED: Added to constructor with default
  });

  // MODIFIED: Factory constructor updated to handle the new fields.
  factory Todo.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Todo(
      id: doc.id,
      title: data['title'] ?? '',
      isDone: data['isDone'] ?? false,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      dueDate: data['dueDate'], // NEW: Can be null
      isImportant: data['isImportant'] ?? false, // NEW: Defaults to false
    );
  }
}

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Function to show a dialog for adding or editing a task.
  // MODIFIED: This function now handles both adding and editing.
  void _showTaskDialog({Todo? task}) {
    final TextEditingController taskController =
        TextEditingController(text: task?.title);
    // NEW: State for the due date
    DateTime? selectedDate = task?.dueDate?.toDate();

    showDialog(
      context: context,
      builder: (context) {
        // NEW: Using a StatefulWidget to manage the date state within the dialog.
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(task == null ? 'Add a new task' : 'Edit task'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: taskController,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Task Title'),
                  ),
                  const SizedBox(height: 16),
                  // NEW: Row for date picker
                  Row(
                    children: [
                      Text(
                        selectedDate == null
                            ? 'No due date'
                            : 'Due: ${DateFormat.yMMMd().format(selectedDate!)}',
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.calendar_month),
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2101),
                          );
                          if (pickedDate != null) {
                            setDialogState(() {
                              selectedDate = pickedDate;
                            });
                          }
                        },
                      )
                    ],
                  )
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: Text(task == null ? 'Add' : 'Save'),
                  onPressed: () {
                    final title = taskController.text.trim();
                    if (title.isNotEmpty) {
                      if (task == null) {
                        _addTask(title, selectedDate);
                      } else {
                        _updateTask(task.id, title, selectedDate);
                      }
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  CollectionReference get _todosCollection {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception("User is not logged in.");
    return _firestore.collection('users').doc(userId).collection('todos');
  }

  // MODIFIED: Add task function now accepts an optional due date.
  Future<void> _addTask(String title, DateTime? dueDate) async {
    await _todosCollection.add({
      'title': title,
      'isDone': false,
      'createdAt': Timestamp.now(),
      'isImportant': false, // Default importance
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
    });
  }
  
  // NEW: Function to update an existing task.
  Future<void> _updateTask(String taskId, String title, DateTime? dueDate) async {
    await _todosCollection.doc(taskId).update({
      'title': title,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
    });
  }

  Future<void> _toggleTaskStatus(Todo task) async {
    await _todosCollection.doc(task.id).update({'isDone': !task.isDone});
  }
  
  // NEW: Function to toggle a task's important status.
  Future<void> _toggleImportance(Todo task) async {
    await _todosCollection.doc(task.id).update({'isImportant': !task.isImportant});
  }

  Future<void> _deleteTask(String taskId) async {
    await _todosCollection.doc(taskId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        // MODIFIED: The query now sorts by importance first, then by creation date.
        stream: _todosCollection
          
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final tasks = snapshot.data!.docs
              .map((doc) => Todo.fromFirestore(doc))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return _buildTaskItem(task);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskDialog(), // Shows the new, unified dialog
        tooltip: 'Add Task',
        child: const Icon(Icons.add),
      ),
    );
  }

  // MODIFIED: The task item widget is updated to show all new information.
  Widget _buildTaskItem(Todo task) {
    // NEW: Check if task is overdue
    final isOverdue = task.dueDate != null && task.dueDate!.toDate().isBefore(DateTime.now()) && !task.isDone;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Checkbox(
          value: task.isDone,
          onChanged: (_) => _toggleTaskStatus(task),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isDone ? TextDecoration.lineThrough : null,
            color: task.isDone ? Colors.grey : null,
          ),
        ),
        // NEW: Subtitle to show the due date.
        subtitle: task.dueDate != null
            ? Text(
                'Due: ${DateFormat.yMMMd().format(task.dueDate!.toDate())}',
                style: TextStyle(
                  color: isOverdue ? Colors.red : Colors.grey.shade600,
                  fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal
                ),
              )
            : null,
        // MODIFIED: Trailing section now holds multiple icons.
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // NEW: Importance toggle button (star icon)
            IconButton(
              icon: Icon(
                task.isImportant ? Icons.star : Icons.star_border,
                color: task.isImportant ? Colors.amber : Colors.grey,
              ),
              onPressed: () => _toggleImportance(task),
              tooltip: 'Mark as important',
            ),
            // NEW: Edit button
            IconButton(
              icon: Icon(Icons.edit, color: Colors.grey.shade600),
              onPressed: () => _showTaskDialog(task: task),
              tooltip: 'Edit Task',
            ),
            // Delete button (from before)
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
              onPressed: () => _deleteTask(task.id),
              tooltip: 'Delete Task',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'All tasks are done!',
            style:
                Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the \'+\' button to add a new task.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}