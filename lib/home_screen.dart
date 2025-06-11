// home_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting

// *** IMPORTANT FIX: Import the new todo_model.dart file directly ***
import 'models/todo_model.dart'; // Contains the Todo model

// HomeScreen is a StatefulWidget to handle real-time data from Firestore.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance; // Store FirebaseAuth instance
  User? _currentUser; // Store current user

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser; // Get current user in initState
  }
  
  // Getter for the todos collection for the current user.
  CollectionReference get _todosCollection {
    if (_currentUser == null) {
      // This case should ideally be handled by AuthGate, preventing HomeScreen from being shown.
      // However, as a fallback:
      debugPrint("Error: Current user is null in _todosCollection getter.");
      throw Exception("User is not logged in. Cannot access todos.");
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('todos');
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      // If user becomes null (e.g. signed out in background), show a loading or error state.
      // This prevents errors if _todosCollection is accessed.
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("User session expired. Please restart the app."),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      // StreamBuilder listens for real-time updates from the user's todos collection.
      body: StreamBuilder<QuerySnapshot>(
        stream: _todosCollection.snapshots(), // Simplified initial query, sorting is done client-side for priority list
        builder: (context, snapshot) {
          // Show a loading indicator while data is being fetched.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // Handle potential errors from the stream.
          if (snapshot.hasError) {
            debugPrint("Error in HomeScreen StreamBuilder: ${snapshot.error}");
            return Center(child: Text('Error loading tasks: ${snapshot.error}'));
          }
          // If there's no data, show the welcome message or an empty tasks state.
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            // Pass specific stats for empty case if needed, or just show generic welcome.
            return _buildDashboardContent(context, [], 0, 0, 0);
          }

          // Convert Firestore documents into a list of Todo objects.
          final allTasks = snapshot.data!.docs
              .map((doc) => Todo.fromFirestore(doc))
              .toList();
          
          // --- Calculate Statistics ---
          final pendingTasks = allTasks.where((task) => !task.isDone).length;
          final completedTasks = allTasks.where((task) => task.isDone).length;
          final dueTodayTasks = allTasks.where((task) {
            if (task.dueDate == null || task.isDone) return false;
            final now = DateTime.now();
            final dueDate = task.dueDate!.toDate();
            // Check if the due date is today (ignoring time component).
            return DateTime(now.year, now.month, now.day) == DateTime(dueDate.year, dueDate.month, dueDate.day);
          }).length;
          
          // --- Filter and Sort for Priority Tasks List ---
          // This list includes tasks that are important (and not done) OR due in the next 7 days (and not done).
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final sevenDaysFromNow = today.add(const Duration(days: 7));

          List<Todo> priorityTasksList = allTasks.where((task) {
            // Condition 1: Task is important and not done.
            bool isImportantAndPending = task.isImportant && !task.isDone;

            // Condition 2: Task is due within the next 7 days (inclusive of today) and not done.
            bool isUpcomingAndPending = false;
            if (task.dueDate != null && !task.isDone) {
              final taskDueDate = task.dueDate!.toDate();
              final taskDueDateOnly = DateTime(taskDueDate.year, taskDueDate.month, taskDueDate.day);
              isUpcomingAndPending =
                  (taskDueDateOnly.isAfter(today) || taskDueDateOnly.isAtSameMomentAs(today)) &&
                  taskDueDateOnly.isBefore(sevenDaysFromNow);
            }
            return isImportantAndPending || isUpcomingAndPending;
          }).toList();

          // Sort the priority tasks:
          // 1. Important tasks come before non-important tasks.
          // 2. For tasks with the same importance, sort by due date (earlier first).
          // 3. If due dates are the same or null, sort by creation date (newer first).
          priorityTasksList.sort((a, b) {
            if (a.isImportant && !b.isImportant) return -1; // a comes first
            if (!a.isImportant && b.isImportant) return 1;  // b comes first

            // If importance is the same, sort by due date
            if (a.dueDate != null && b.dueDate == null) return -1; // a (has due date) comes first
            if (a.dueDate == null && b.dueDate != null) return 1;  // b (has due date) comes first
            if (a.dueDate != null && b.dueDate != null) {
              final dateCompare = a.dueDate!.compareTo(b.dueDate!);
              if (dateCompare != 0) return dateCompare; // Sort by due date
            }
            // If due dates are also the same (or both null), sort by creation date (newer first)
            return b.createdAt.compareTo(a.createdAt);
          });

          // Limit the list to the top 5 priority tasks.
          final limitedPriorityTasks = priorityTasksList.take(5).toList();

          return _buildDashboardContent(context, limitedPriorityTasks, pendingTasks, completedTasks, dueTodayTasks);
        },
      ),
    );
  }

  // Builds the main content of the dashboard.
  Widget _buildDashboardContent(BuildContext context, List<Todo> priorityTasks, int pendingTasks, int completedTasks, int dueTodayTasks) {
    // If there are no tasks at all, show a generic welcome message.
    if (priorityTasks.isEmpty && pendingTasks == 0 && completedTasks == 0 && dueTodayTasks == 0) {
        return _buildWelcomeMessage();
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Welcome Message ---
            Text(
              'Welcome,',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              _currentUser?.displayName ?? _currentUser?.email ?? 'User',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 24),

            // --- Statistics Section ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.pending_actions_rounded,
                    label: 'Pending',
                    count: pendingTasks.toString(),
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.check_circle_rounded,
                    label: 'Completed',
                    count: completedTasks.toString(),
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                 Expanded(
                  child: _StatCard(
                    icon: Icons.today_rounded,
                    label: 'Due Today',
                    count: dueTodayTasks.toString(),
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32), // Increased spacing after stats

            // --- Priority Tasks List Section ---
            Text(
              'Priority Tasks',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12), // Increased spacing before list

            priorityTasks.isEmpty
              ? _buildEmptyPriorityList()
              : _buildPriorityTasksList(priorityTasks),
          ],
        ),
      ),
    );
  }

  // Builds a simple welcome message for when there's no task data at all.
  Widget _buildWelcomeMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dashboard_customize_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 20),
            Text(
              'Welcome, ${(_currentUser?.displayName ?? _currentUser?.email ?? 'User')}!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Your tasks and notes will appear here once you add them.\nLet\'s get organized!',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  // Builds the list widget for displaying priority tasks.
  Widget _buildPriorityTasksList(List<Todo> tasks) {
    return ListView.builder(
      shrinkWrap: true, // Essential for ListView inside SingleChildScrollView.
      physics: const NeverScrollableScrollPhysics(), // Disables scrolling for this inner list.
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final isOverdue = task.dueDate != null && !task.isDone && task.dueDate!.toDate().isBefore(DateTime.now().subtract(const Duration(days: 1)));

        return Card(
          elevation: 1.5, // Slightly more elevation for priority tasks
          margin: const EdgeInsets.symmetric(vertical: 6.0), // More vertical spacing
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: task.isImportant
                ? Icon(Icons.star_rounded, color: Colors.amber.shade700, size: 26)
                : Icon(Icons.radio_button_unchecked_rounded, color: Colors.grey.shade400, size: 22), // Changed icon for non-important upcoming
            title: Text(
              task.title,
              style: TextStyle(
                decoration: task.isDone ? TextDecoration.lineThrough : null,
                fontWeight: task.isImportant && !task.isDone ? FontWeight.bold : FontWeight.normal,
                color: task.isDone ? Colors.grey : Theme.of(context).textTheme.bodyLarge?.color,
              )
            ),
            subtitle: task.dueDate != null 
              ? Text(
                  'Due: ${DateFormat.yMMMd().format(task.dueDate!.toDate())}',
                  style: TextStyle(
                    color: isOverdue ? Colors.red.shade700 : Colors.grey.shade600,
                    fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal, // Slightly bolder if overdue
                  ),
                )
              : null,
            trailing: task.isDone
              ? Icon(Icons.check_circle_outline_rounded, color: Colors.green.shade600, size: 26)
              : (task.isImportant ? null : const SizedBox(width: 26)), // Ensure consistent spacing if no icon for non-important
          ),
        );
      },
    );
  }

  // Builds a placeholder widget for when the priority tasks list is empty, but other tasks might exist.
  Widget _buildEmptyPriorityList() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40), // More padding
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50, // Softer background color
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade100)
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.space_dashboard_outlined, size: 52, color: Colors.blueGrey.shade400), // Updated icon
            const SizedBox(height: 16),
            Text(
              'No Priority Tasks Right Now', // Updated message
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.blueGrey.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              'Important tasks or those due soon will appear here.', // Clarifying text
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

// Reusable widget for displaying individual statistics in cards.
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String count;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1), // Light background color based on the provided color.
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)) // Subtle border.
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28), // Icon for the stat.
          const SizedBox(height: 8),
          Text(
            count, // The actual statistic value (e.g., "5").
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(color: Colors.grey.shade700)), // Label for the stat (e.g., "Pending").
        ],
      ),
    );
  }
}
