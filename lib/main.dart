// main.dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vlt/utils/storage_helper.dart';
import 'data/notifiers.dart';
import 'pages/home_page.dart';
import 'pages/browser_page.dart';
import 'pages/settings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestStoragePermission();

  // ✨ STEP 1: Load folders from the database.
  final loadedFolders = await StorageHelper.getAllFolders();

  if (loadedFolders.isEmpty) {
    // ✨ If database is empty, rebuild from disk first.
    debugPrint('📂 No folders found in database. Attempting to rebuild from disk...');
    await StorageHelper.rebuildDatabaseFromDisk();

    // After rebuilding, check again for folders.
    final recoveredFolders = await StorageHelper.getAllFolders();
    if (recoveredFolders.isEmpty) {
      // If still empty, create default folders (first run).
      debugPrint('🆕 Database still empty after rebuild. Creating default folders.');
      final defaultFolders = getDefaultFolders();
      for (final folder in defaultFolders) {
        await StorageHelper.createFolder(folder);
      }
      foldersNotifier.value = defaultFolders;
    } else {
      debugPrint('✅ Recovered ${recoveredFolders.length} folders from disk.');
      foldersNotifier.value = recoveredFolders;
    }
  } else {
    foldersNotifier.value = loadedFolders;
  }

  // ✨ STEP 2: Ensure counts are up to date.
  await refreshItemCounts();

  // ✨ MODIFIED: Load both saved theme preferences on startup.
  await loadThemePreference();

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
    // ✨ MODIFIED: Nest builders to listen to both theme color and dark mode.
    return ValueListenableBuilder<Color>(
      valueListenable: selectedColorNotifier,
      builder: (context, color, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: selectedThemeNotifier,
          builder: (context, isDarkMode, child) {
            return MaterialApp(
              title: 'Vault App',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                useMaterial3: true,
                // ✨ MODIFIED: Theme now uses the dynamic color and brightness.
                colorScheme: ColorScheme.fromSeed(
                  seedColor: color,
                  brightness: isDarkMode ? Brightness.dark : Brightness.light,
                ),
              ),
              home: const MainScreen(),
            );
          },
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
                    // ✨ MODIFIED: This now calls the new save function to toggle theme.
                    onPressed: () {
                      saveThemePreference(
                        isDarkMode: !isDarkMode,
                        color: selectedColorNotifier.value,
                      );
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