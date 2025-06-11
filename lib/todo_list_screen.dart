import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'models/todo_model.dart'; // Import the Todo model

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _todosCollection {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception("User is not logged in.");
    }
    return _firestore.collection('users').doc(userId).collection('todos');
  }

  Future<void> _addOrUpdateTodo({
    Todo? todo,
    required String title,
    required bool isImportant,
    DateTime? dueDate,
  }) {
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title cannot be empty.')),
      );
      return Future.value();
    }

    final data = {
      'title': title,
      'isImportant': isImportant,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
      'createdAt': todo?.createdAt ?? Timestamp.now(),
      'isDone': todo?.isDone ?? false,
    };

    if (todo == null) {
      // Add new todo
      return _todosCollection.add(data);
    } else {
      // Update existing todo
      return _todosCollection.doc(todo.id).update(data);
    }
  }

  Future<void> _toggleDoneStatus(Todo todo) async {
    try {
      await _todosCollection.doc(todo.id).update({'isDone': !todo.isDone});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to update task status: $e'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  Future<void> _deleteTodo(String todoId) async {
     try {
        await _todosCollection.doc(todoId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task deleted successfully!'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete task: $e'), backgroundColor: Theme.of(context).colorScheme.error),
          );
        }
      }
  }

  void _showAddEditTodoDialog({Todo? todo}) {
    final titleController = TextEditingController(text: todo?.title ?? '');
    final isImportantNotifier = ValueNotifier<bool>(todo?.isImportant ?? false);
    final dueDateNotifier = ValueNotifier<DateTime?>(todo?.dueDate?.toDate());
    final isSavingNotifier = ValueNotifier<bool>(false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return ValueListenableBuilder<bool>(
          valueListenable: isSavingNotifier,
          builder: (context, isSaving, child) {
            return AlertDialog(
              title: Text(todo == null ? 'Add New Task' : 'Edit Task'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'Task Title'),
                      textCapitalization: TextCapitalization.sentences,
                      readOnly: isSaving,
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: isImportantNotifier,
                      builder: (context, isImportant, child) {
                        return SwitchListTile(
                          title: const Text('Important'),
                          value: isImportant,
                          onChanged: isSaving ? null : (value) => isImportantNotifier.value = value,
                          secondary: Icon(Icons.star, color: isImportant ? Colors.amber : Colors.grey),
                        );
                      },
                    ),
                    ValueListenableBuilder<DateTime?>(
                      valueListenable: dueDateNotifier,
                      builder: (context, dueDate, child) {
                        return ListTile(
                          leading: const Icon(Icons.calendar_today),
                          title: Text(dueDate == null ? 'No due date' : DateFormat.yMMMd().format(dueDate)),
                          trailing: dueDate != null ? IconButton(icon: const Icon(Icons.clear), onPressed: isSaving ? null : () => dueDateNotifier.value = null) : null,
                          onTap: isSaving ? null : () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: dueDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2101),
                            );
                            if (pickedDate != null) {
                              dueDateNotifier.value = pickedDate;
                            }
                          },
                        );
                      },
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
                    final String title = titleController.text.trim();
                    final bool isImportant = isImportantNotifier.value;
                    final DateTime? dueDate = dueDateNotifier.value;

                    // Capture the Navigator instance using dialogContext BEFORE the await
                    final NavigatorState dialogNavigator = Navigator.of(dialogContext);

                    await _addOrUpdateTodo(
                      todo: todo,
                      title: title,
                      isImportant: isImportant,
                      dueDate: dueDate,
                    );

                    if (!mounted) return;

                    if (dialogNavigator.canPop()) {
                        dialogNavigator.pop();
                    }
                  },
                  child: isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      titleController.dispose();
      isImportantNotifier.dispose();
      dueDateNotifier.dispose();
      isSavingNotifier.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: _todosCollection.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading tasks.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_box_outline_blank, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('No tasks yet!', style: TextStyle(fontSize: 22, color: Colors.grey)),
                   const SizedBox(height: 8),
                  const Text('Tap \'+\' to add a new task.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            );
          }

          final todos = snapshot.data!.docs.map((doc) => Todo.fromFirestore(doc)).toList();

          return ListView.builder(
            itemCount: todos.length,
            itemBuilder: (context, index) {
              final todo = todos[index];
              return _buildTodoItem(todo);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditTodoDialog(),
        tooltip: 'Add Task',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTodoItem(Todo todo) {
    final isOverdue = todo.dueDate != null && !todo.isDone && todo.dueDate!.toDate().isBefore(DateTime.now().subtract(const Duration(days: 1)));
    return Dismissible(
      key: ValueKey(todo.id),
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        _deleteTodo(todo.id);
      },
      child: ListTile(
        leading: IconButton(
          icon: Icon(todo.isDone ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded),
          onPressed: () => _toggleDoneStatus(todo),
          color: todo.isDone ? Colors.green : Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          todo.title,
          style: TextStyle(decoration: todo.isDone ? TextDecoration.lineThrough : null),
        ),
        subtitle: todo.dueDate != null
            ? Text(
                'Due: ${DateFormat.yMMMd().format(todo.dueDate!.toDate())}',
                 style: TextStyle(color: isOverdue ? Colors.red : Colors.grey),
              )
            : null,
        trailing: todo.isImportant ? Icon(Icons.star_rounded, color: Colors.amber.shade600) : null,
        onTap: () => _showAddEditTodoDialog(todo: todo),
      ),
    );
  }
}
