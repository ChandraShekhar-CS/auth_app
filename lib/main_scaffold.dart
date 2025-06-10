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
  int _selectedIndex = 0; // Current selected index for the bottom navigation bar.

  // List of Widgets representing the different screens accessible via BottomNavigationBar.
  // Order must correspond to the BottomNavigationBarItem order.
  static const List<Widget> _pages = <Widget>[
    HomeScreen(),
    TodoListScreen(),
    NotesScreen(),
    ProfileScreen(),
  ];

  // Callback function when a BottomNavigationBarItem is tapped.
  // Updates the selected index to change the displayed page.
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // List of titles for the AppBar, corresponding to each page in [_pages].
  // Order must correspond to the BottomNavigationBarItem order.
  static const List<String> _titles = <String>[
    'Dashboard', // Title for HomeScreen
    'My To-Do List', // Title for TodoListScreen
    'My Notes', // Title for NotesScreen
    'Profile & Settings', // Title for ProfileScreen
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]), // AppBar title updates based on the selected page.
        backgroundColor: Theme.of(context).colorScheme.primaryContainer, // Consistent AppBar color
      ),
      body: IndexedStack( // Using IndexedStack to preserve state of pages when switching
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        // type: BottomNavigationBarType.fixed, // Ensures all labels are visible
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
        currentIndex: _selectedIndex, // Highlights the current active item.
        selectedItemColor: Theme.of(context).colorScheme.primary, // Color for the selected item.
        unselectedItemColor: Colors.grey.shade600, // Color for unselected items.
        showUnselectedLabels: true, // Ensures labels for unselected items are also visible.
        onTap: _onItemTapped, // Callback for when an item is tapped.
      ),
    );
  }
}
