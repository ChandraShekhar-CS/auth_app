import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // For Quote of the day
import 'dart:convert'; // For Quote of the day
import 'package:auth_app/todo_list_screen.dart'; // Import the To-Do screen
import 'package:auth_app/profile_screen.dart'; // Import the Profile screen

// --- Quote of the Day Widget ---
class QuoteCard extends StatefulWidget {
  const QuoteCard({super.key});

  @override
  State<QuoteCard> createState() => _QuoteCardState();
}

class _QuoteCardState extends State<QuoteCard> {
  String _quote = 'Loading quote...';
  String _author = '';

  @override
  void initState() {
    super.initState();
    _fetchQuote();
  }

  // Fetches a random quote from an API.
  Future<void> _fetchQuote() async {
    try {
      final response = await http.get(Uri.parse('https://api.quotable.io/random'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _quote = data['content'];
            _author = data['author'];
          });
        }
      } else {
        throw Exception('Failed to load quote');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _quote = 'Could not fetch quote. Please try again later.';
          _author = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _quote,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            if (_author.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '- $_author',
                style: Theme.of(context).textTheme.titleSmall,
                textAlign: TextAlign.right,
              ),
            ],
            const SizedBox(height: 8),
            IconButton(
              onPressed: _fetchQuote,
              icon: const Icon(Icons.refresh),
              tooltip: 'New Quote',
            )
          ],
        ),
      ),
    );
  }
}


// --- Home Screen ---
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the current user from Firebase Auth.
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          // Sign Out Button
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              FirebaseAuth.instance.signOut();
            },
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Welcome message
              Text(
                'Welcome, ${user?.displayName ?? user?.email ?? 'User'}!',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
        
              // Quote of the Day Widget
              const QuoteCard(),
        
              // Button to To-Do List
              ElevatedButton.icon(
                icon: const Icon(Icons.list_alt),
                label: const Text('My To-Do List'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (ctx) => const TodoListScreen()),
                  );
                },
              ),
              const SizedBox(height: 16),
        
              // Button to Profile
              ElevatedButton.icon(
                icon: const Icon(Icons.person),
                label: const Text('Go to Profile'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (ctx) => const ProfileScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
