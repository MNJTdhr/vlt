import 'package:flutter/material.dart';
import 'data/notifiers.dart';
import 'pages/home_page.dart';
import 'pages/browser_page.dart';
import 'pages/settings_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: selectedThemeNotifier,
      builder: (context, isDarkMode, child) {
        return MaterialApp(
          title: 'Vault App',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: isDarkMode ? Brightness.dark : Brightness.light,
            ),
          ),
          home: const MainScreen(),
        );
      },
    );
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  final List<Widget> pages = const [HomePage(), BrowserPage(), SettingsPage()];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: selectedPageNotifier,
      builder: (context, selectedIndex, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Vault',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
            ),
            centerTitle: true,
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            elevation: 2,
            actions: [
              ValueListenableBuilder(
                valueListenable: selectedThemeNotifier,
                builder: (context, isDarkMode, child) {
                  return IconButton(
                    onPressed: () {
                      selectedThemeNotifier.value =
                          !selectedThemeNotifier.value;
                    },
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        isDarkMode ? Icons.light_mode : Icons.dark_mode,
                        key: ValueKey(isDarkMode),
                      ),
                    ),
                    tooltip: isDarkMode
                        ? 'Switch to Light Mode'
                        : 'Switch to Dark Mode',
                  );
                },
              ),
              const SizedBox(width: 10),
            ],
          ),
          body: IndexedStack(index: selectedIndex, children: pages),
          bottomNavigationBar: ValueListenableBuilder(
            valueListenable: selectedPageNotifier,
            builder: (context, selectedIndex, child) {
              return NavigationBar(
                selectedIndex: selectedIndex,
                onDestinationSelected: (index) {
                  selectedPageNotifier.value = index;
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.explore_outlined),
                    selectedIcon: Icon(Icons.explore),
                    label: 'Browser',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: 'Settings',
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
