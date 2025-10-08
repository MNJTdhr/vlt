// main.dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vlt/utils/storage_helper.dart';
import 'data/notifiers.dart'; // ✨ FIX: This import defines 'selectedPageNotifier' and other notifiers.
import 'pages/home_page.dart';
import 'pages/browser_page.dart';
import 'pages/settings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestStoragePermission();

  // This logic now correctly loads folders from disk or creates the defaults physically
  final loadedFolders = await StorageHelper.loadAllFoldersFromDisk();
  if (loadedFolders.isEmpty) {
    final defaultFolders = getDefaultFolders();
    for (final folder in defaultFolders) {
      // This creates the physical folder and its .metadata.json file
      await StorageHelper.createFolder(folder);
    }
    foldersNotifier.value = defaultFolders;
  } else {
    foldersNotifier.value = loadedFolders;
  }

  runApp(const VaultApp());
}

Future<void> _requestStoragePermission() async {
  var status = await Permission.manageExternalStorage.request();
  if (status.isDenied) {
    debugPrint('Storage permission was denied.');
  } else if (status.isPermanentlyDenied) {
    debugPrint('Storage permission permanently denied. Opening app settings.');
    await openAppSettings();
  }
}

class VaultApp extends StatelessWidget {
  const VaultApp({super.key});

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
              seedColor: Colors.blue,
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

  final List<Widget> pages = const [
    HomePage(),
    BrowserPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: selectedPageNotifier,
      builder: (context, selectedIndex, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Vault',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
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
                      selectedThemeNotifier.value = !selectedThemeNotifier.value;
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
          body: IndexedStack(
            index: selectedIndex,
            children: pages,
          ),
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