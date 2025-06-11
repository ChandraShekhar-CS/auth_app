import 'package:flutter/material.dart';
import 'home_screen.dart'; // Screen for the main dashboard.
import 'profile_screen.dart'; // Screen for user profile settings.
import 'todo_list_screen.dart'; // Screen for managing to-do tasks.
import 'notes_screen.dart'; // Screen for managing notes.

/// MainScaffold is the primary UI structure after user authentication.
/// It includes an AppBar and a BottomNavigationBar to switch between different screens.
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // This function is called when a navigation bar item is tapped.
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  // The list of titles for the AppBar.
  static const List<String> _titles = <String>[
    'Dashboard',
    'My To-Do List',
    'My Notes',
    'Profile & Settings',
  ];

  @override
  Widget build(BuildContext context) {
    // Build pages on demand to avoid context issues
    final List<Widget> pages = [
      HomeScreen(),
      TodoListScreen(),
      NotesScreen(),
      ProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        // Ensure the type is fixed to prevent the bottom bar from changing behavior
        // when more or fewer items are selected. This can also help with stability.
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_rounded),
            label: 'To-Dos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.note_alt_rounded),
            label: 'Notes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey.shade600,
        showUnselectedLabels: true,
        onTap: _onItemTapped,
      ),
    );
  }
}
