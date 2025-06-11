import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'models/todo_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin<HomeScreen> {
<<<<<<< HEAD
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;
=======
  final FirebaseAuth _auth = FirebaseAuth.instance; // Store FirebaseAuth instance
  User? _currentUser; // Store current user
>>>>>>> 770337839f3016115ede58c4cbe2b7bfa043cff5

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
  }

  @override
  bool get wantKeepAlive => true;
  
  CollectionReference get _todosCollection {
    if (_currentUser == null) {
      throw Exception("User is not logged in. Cannot access todos.");
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('todos');
  }

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    super.build(context);
=======
    super.build(context); // Call super.build for AutomaticKeepAliveClientMixin
>>>>>>> 770337839f3016115ede58c4cbe2b7bfa043cff5
    if (_currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text("User session expired. Please restart the app."),
        ),
      );
    }

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: _todosCollection.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading tasks: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildDashboardContent(context, [], 0, 0, 0);
          }

          final allTasks = snapshot.data!.docs
              .map((doc) => Todo.fromFirestore(doc))
              .toList();
          
          final pendingTasks = allTasks.where((task) => !task.isDone).length;
          final completedTasks = allTasks.where((task) => task.isDone).length;
          final dueTodayTasks = allTasks.where((task) {
            if (task.dueDate == null || task.isDone) return false;
            final now = DateTime.now();
            final dueDate = task.dueDate!.toDate();
            return DateTime(now.year, now.month, now.day) == DateTime(dueDate.year, dueDate.month, dueDate.day);
          }).length;
          
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final sevenDaysFromNow = today.add(const Duration(days: 7));

          List<Todo> priorityTasksList = allTasks.where((task) {
            bool isImportantAndPending = task.isImportant && !task.isDone;
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

          priorityTasksList.sort((a, b) {
            if (a.isImportant && !b.isImportant) return -1;
            if (!a.isImportant && b.isImportant) return 1;
            if (a.dueDate != null && b.dueDate == null) return -1;
            if (a.dueDate == null && b.dueDate != null) return 1;
            if (a.dueDate != null && b.dueDate != null) {
              final dateCompare = a.dueDate!.compareTo(b.dueDate!);
              if (dateCompare != 0) return dateCompare;
            }
            return b.createdAt.compareTo(a.createdAt);
          });

          final limitedPriorityTasks = priorityTasksList.take(5).toList();

          return _buildDashboardContent(context, limitedPriorityTasks, pendingTasks, completedTasks, dueTodayTasks);
        },
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context, List<Todo> priorityTasks, int pendingTasks, int completedTasks, int dueTodayTasks) {
    if (priorityTasks.isEmpty && pendingTasks == 0 && completedTasks == 0 && dueTodayTasks == 0) {
        return _buildWelcomeMessage();
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Row(
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
            const SizedBox(height: 32),
            Text(
              'Priority Tasks',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            priorityTasks.isEmpty
              ? _buildEmptyPriorityList()
              : _buildPriorityTasksList(priorityTasks),
          ],
        ),
      ),
    );
  }

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
              'Your tasks and notes will appear here once you add them.',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPriorityTasksList(List<Todo> tasks) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final isOverdue = task.dueDate != null && !task.isDone && task.dueDate!.toDate().isBefore(DateTime.now().subtract(const Duration(days: 1)));

        return Card(
          elevation: 1.5,
          margin: const EdgeInsets.symmetric(vertical: 6.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: task.isImportant
                ? Icon(Icons.star_rounded, color: Colors.amber.shade700, size: 26)
                : Icon(Icons.radio_button_unchecked_rounded, color: Colors.grey.shade400, size: 22),
            title: Text(
              task.title,
              style: TextStyle(
                decoration: task.isDone ? TextDecoration.lineThrough : null,
                fontWeight: task.isImportant && !task.isDone ? FontWeight.bold : FontWeight.normal,
              )
            ),
            subtitle: task.dueDate != null 
              ? Text(
                  'Due: ${DateFormat.yMMMd().format(task.dueDate!.toDate())}',
                  style: TextStyle(
                    color: isOverdue ? Colors.red.shade700 : Colors.grey.shade600,
                    fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                  ),
                )
              : null,
          ),
        );
      },
    );
  }

  Widget _buildEmptyPriorityList() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade100)
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.space_dashboard_outlined, size: 52, color: Colors.blueGrey.shade400),
            const SizedBox(height: 16),
            Text(
              'No Priority Tasks Right Now',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.blueGrey.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              'Important tasks or those due soon will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3))
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}
