import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final _taskController = TextEditingController();
  final _currentUser = FirebaseAuth.instance.currentUser;

  // Get a reference to the user's personal 'tasks' collection in Firestore.
  CollectionReference get _tasksCollection {
    if (_currentUser == null) {
      // This should not happen if the user is logged in, but it's a good safeguard.
      throw Exception('User not logged in!');
    }
    // We create a unique collection for each user based on their UID.
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser.uid)
        .collection('tasks');
  }

  // --- Functions to interact with Firestore ---

  // Add a new task
  void _addTask() {
    if (_taskController.text.trim().isEmpty) return;

    _tasksCollection.add({
      'text': _taskController.text.trim(),
      'isDone': false,
      'createdAt': Timestamp.now(), // Helps with sorting
    });
    _taskController.clear(); // Clear the input field
    Navigator.of(context).pop(); // Close the dialog
  }

  // Update a task's 'isDone' status
  void _toggleTaskStatus(DocumentSnapshot task) {
    _tasksCollection.doc(task.id).update({'isDone': !task['isDone']});
  }

  // Delete a task
  void _deleteTask(String taskId) {
    _tasksCollection.doc(taskId).delete();
  }

  // --- UI ---

  // Show the dialog for adding a new task
  void _showAddTaskDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Task'),
        content: TextField(
          controller: _taskController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'What do you need to do?',
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(onPressed: _addTask, child: const Text('Add')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My To-Do List')),
      // Use a StreamBuilder to listen for real-time updates from Firestore.
      body: StreamBuilder<QuerySnapshot>(
        // Sort tasks by creation time to show newest first.
        stream: _tasksCollection
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // Show a loading spinner while waiting for data.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // Show an error message if something goes wrong.
          if (snapshot.hasError) {
            return Center(
              child: Text('Something went wrong: ${snapshot.error}'),
            );
          }
          // If there's no data, show a message.
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No tasks yet. Add one!'));
          }

          final tasks = snapshot.data!.docs;

          // Display the list of tasks.
          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              final taskData = task.data() as Map<String, dynamic>;
              final bool isDone = taskData['isDone'];

              return ListTile(
                // The checkbox to toggle the task's status.
                leading: Checkbox(
                  value: isDone,
                  onChanged: (_) => _toggleTaskStatus(task),
                ),
                // The task text, with a line-through if it's done.
                title: Text(
                  taskData['text'],
                  style: TextStyle(
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    color: isDone ? Colors.grey : null,
                  ),
                ),
                // The button to delete the task.
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteTask(task.id),
                ),
              );
            },
          );
        },
      ),
      // Floating Action Button to add a new task.
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
