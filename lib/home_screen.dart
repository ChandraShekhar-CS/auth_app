// home_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
// NEW: Import the Todo model from your todo_list_screen.
// Make sure the path is correct for your project structure.
import 'todo_list_screen.dart'; 

// MODIFIED: Converted from StatelessWidget to StatefulWidget to handle real-time data.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _currentUser = FirebaseAuth.instance.currentUser;
  
  // NEW: Getter for the todos collection to avoid repetition.
  CollectionReference get _todosCollection {
    if (_currentUser == null) throw Exception("User is not logged in.");
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('todos');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // NEW: Using a StreamBuilder to listen for real-time updates from Firestore.
      body: StreamBuilder<QuerySnapshot>(
        stream: _todosCollection.snapshots(),
        builder: (context, snapshot) {
          // Show a loading indicator while data is being fetched.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // Handle potential errors.
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          // If there's no data, it might be an empty list or an issue.
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildWelcomeMessage(); // Show only the welcome message.
          }

          // Convert the Firestore documents into a list of Todo objects.
          final allTasks = snapshot.data!.docs
              .map((doc) => Todo.fromFirestore(doc))
              .toList();
          
          // --- NEW: Calculate Statistics ---
          final pendingTasks = allTasks.where((task) => !task.isDone).length;
          final importantTasks = allTasks.where((task) => task.isImportant && !task.isDone).length;
          final dueTodayTasks = allTasks.where((task) {
            if (task.dueDate == null || task.isDone) return false;
            final now = DateTime.now();
            final dueDate = task.dueDate!.toDate();
            return now.year == dueDate.year && now.month == dueDate.month && now.day == dueDate.day;
          }).length;
          
          // --- NEW: Filter for important tasks list ---
          final importantTasksList = allTasks.where((task) => task.isImportant && !task.isDone).toList();


          // The main layout for the dashboard.
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

                  // --- NEW: Statistics Section ---
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
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.star_rounded,
                          label: 'Important',
                          count: importantTasks.toString(),
                          color: Colors.amber.shade800,
                        ),
                      ),
                       const SizedBox(width: 16),
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

                  // --- NEW: Important Tasks List Section ---
                  Text(
                    'Your Important Tasks',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),

                  importantTasksList.isEmpty 
                    ? _buildEmptyImportantList() 
                    : _buildImportantTasksList(importantTasksList),

                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // NEW: A simple welcome message for when there's no data.
  Widget _buildWelcomeMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
          const SizedBox(height: 16),
          const Text('Your dashboard will appear here.'),
        ],
      ),
    );
  }
  
  // NEW: A widget for the list of important tasks.
  Widget _buildImportantTasksList(List<Todo> tasks) {
    return ListView.builder(
      shrinkWrap: true, // Important to use inside a SingleChildScrollView
      physics: const NeverScrollableScrollPhysics(), // Disables scrolling for the inner list
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Card(
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            title: Text(task.title),
            subtitle: task.dueDate != null 
              ? Text('Due: ${DateFormat.yMMMd().format(task.dueDate!.toDate())}')
              : null,
            leading: Icon(Icons.label_important, color: Colors.amber.shade700),
          ),
        );
      },
    );
  }

  // NEW: A placeholder widget for when the important tasks list is empty.
  Widget _buildEmptyImportantList() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.star_outline_rounded, size: 40, color: Colors.grey.shade600),
            const SizedBox(height: 8),
            Text(
              'No important tasks right now!',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

// NEW: A reusable widget for the statistic cards.
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