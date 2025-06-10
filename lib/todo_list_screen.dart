// todo_list_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // For date formatting.

// Defines the data structure for a To-Do item.
class Todo {
  final String id;
  final String title;
  final bool isDone;
  final Timestamp createdAt;
  final Timestamp? dueDate; // Nullable field for the due date.
  final bool isImportant; // Field for task priority.

  Todo({
    required this.id,
    required this.title,
    required this.isDone,
    required this.createdAt,
    this.dueDate,
    this.isImportant = false, // Default to not important.
  });

  // Creates a Todo instance from a Firestore document.
  factory Todo.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Todo(
      id: doc.id,
      title: data['title'] ?? '',
      isDone: data['isDone'] ?? false,
      createdAt: data['createdAt'] ?? Timestamp.now(), // Provide a default if null.
      dueDate: data['dueDate'],
      isImportant: data['isImportant'] ?? false, // Default to false if null.
    );
  }
}

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // TextEditingController for the task dialog needs to be managed.
  // This is tricky because it's created inside showDialog.
  // For a more robust solution, the dialog content could be its own StatefulWidget.
  // Here, we rely on the dialog's lifecycle, which is generally acceptable for simple cases.

  // Shows a dialog for adding or editing a task.
  void _showTaskDialog({Todo? task}) {
    final TextEditingController taskController = TextEditingController(text: task?.title);
    DateTime? selectedDate = task?.dueDate?.toDate();

    showDialog(
      context: context,
      builder: (context) {
        // Using StatefulBuilder to manage the date state within the dialog.
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(task == null ? 'Add New Task' : 'Edit Task'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: taskController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Task Title',
                      hintText: 'What do you need to do?',
                      border: OutlineInputBorder(),
                    ),
                     textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),
                  // Row for date picker
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedDate == null
                              ? 'No due date set'
                              : 'Due: ${DateFormat.yMMMd().format(selectedDate!)}',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_month_outlined),
                        tooltip: 'Select Due Date',
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate ?? DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 365)), // Allow past dates for flexibility
                            lastDate: DateTime(2101),
                          );
                          if (pickedDate != null) {
                            setDialogState(() { // Use the dialog's own state update
                              selectedDate = pickedDate;
                            });
                          }
                        },
                      )
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    taskController.dispose(); // Dispose controller on cancel
                  }
                ),
                ElevatedButton(
                  child: Text(task == null ? 'Add Task' : 'Save Changes'),
                  onPressed: () {
                    final title = taskController.text.trim();
                    if (title.isNotEmpty) {
                      if (task == null) {
                        _addTask(title, selectedDate);
                      } else {
                        _updateTask(task.id, title, selectedDate);
                      }
                      Navigator.of(context).pop();
                    } else {
                       ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Title cannot be empty.')),
                      );
                    }
                    taskController.dispose(); // Dispose controller on save/add
                  },
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      // Ensure controller is disposed if dialog is dismissed by tapping outside
      // This is a fallback, explicit disposal in actions is better.
      // taskController.dispose(); // This line would cause an error as taskController is not in this scope.
      // Proper disposal for dialogs like this is complex without making the dialog a StatefulWidget.
    });
  }

  // Provides a reference to the current user's 'todos' collection.
  CollectionReference get _todosCollection {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      // This should ideally not happen if AuthGate is working correctly.
      // Consider logging this error or showing a generic error to the user.
      throw Exception("User is not logged in. Cannot access todos.");
    }
    return _firestore.collection('users').doc(userId).collection('todos');
  }

  // Adds a new task to Firestore.
  Future<void> _addTask(String title, DateTime? dueDate) async {
    try {
      await _todosCollection.add({
        'title': title,
        'isDone': false,
        'createdAt': Timestamp.now(),
        'isImportant': false,
        'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task added!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add task: $e')));
    }
  }
  
  // Updates an existing task in Firestore.
  Future<void> _updateTask(String taskId, String title, DateTime? dueDate) async {
    try {
      await _todosCollection.doc(taskId).update({
        'title': title,
        'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task updated!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update task: $e')));
    }
  }

  // Toggles the 'isDone' status of a task.
  Future<void> _toggleTaskStatus(Todo task) async {
    try {
      await _todosCollection.doc(task.id).update({'isDone': !task.isDone});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update task status: $e')));
    }
  }
  
  // Toggles the 'isImportant' status of a task.
  Future<void> _toggleImportance(Todo task) async {
    try {
      await _todosCollection.doc(task.id).update({'isImportant': !task.isImportant});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update task importance: $e')));
    }
  }

  // Deletes a task from Firestore.
  Future<void> _deleteTask(String taskId) async {
     // Optional: Show confirmation dialog before deleting
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task?'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _todosCollection.doc(taskId).delete();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task deleted!')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete task: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: _todosCollection
            .orderBy('isImportant', descending: true)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            // Log error or show a more user-friendly message
            print("Error fetching todos: ${snapshot.error}");
            return const Center(child: Text('An error occurred while loading tasks.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(); // Shows a message when there are no tasks.
          }

          // Maps Firestore documents to Todo objects.
          final tasks = snapshot.data!.docs
              .map((doc) => Todo.fromFirestore(doc))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return _buildTaskItem(task); // Builds each task item widget.
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskDialog(),
        tooltip: 'Add Task',
        child: const Icon(Icons.add),
      ),
    );
  }

  // Builds the visual representation of a single task item.
  Widget _buildTaskItem(Todo task) {
    // Check if task is overdue
    final bool isOverdue = task.dueDate != null &&
                           !task.isDone &&
                           task.dueDate!.toDate().isBefore(DateTime.now().subtract(const Duration(days: 1))); // Overdue if due date is before today

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
          activeColor: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isDone ? TextDecoration.lineThrough : null,
            color: task.isDone ? Colors.grey : Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: task.isImportant && !task.isDone ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        // Subtitle to show the due date.
        subtitle: task.dueDate != null
            ? Text(
                'Due: ${DateFormat.yMMMd().format(task.dueDate!.toDate())}',
                style: TextStyle(
                  color: isOverdue ? Colors.red.shade700 : Colors.grey.shade600,
                  fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                ),
              )
            : null,
        // Trailing section now holds multiple icons.
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Importance toggle button (star icon)
            IconButton(
              icon: Icon(
                task.isImportant ? Icons.star_rounded : Icons.star_border_rounded,
                color: task.isImportant ? Colors.amber.shade700 : Colors.grey,
              ),
              onPressed: () => _toggleImportance(task),
              tooltip: task.isImportant ? 'Mark as not important' : 'Mark as important',
            ),
            // Edit button
            IconButton(
              icon: Icon(Icons.edit_outlined, color: Colors.grey.shade600),
              onPressed: () => _showTaskDialog(task: task),
              tooltip: 'Edit Task',
            ),
            // Delete button
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400),
              onPressed: () => _deleteTask(task.id),
              tooltip: 'Delete Task',
            ),
          ],
        ),
      ),
    );
  }

  // Builds a widget to display when the task list is empty.
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline_rounded, // Consider a more generic icon if "All tasks done" isn't always true.
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No tasks yet!', // Changed from "All tasks are done!"
            style:
                Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the \'+\' button to add a new task.',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}