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
  // ✨ ADDED: Load saved sort preference on startup.
  await loadHomeSortPreference();

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
            backgroundColor: selectedColorNotifier.value,
            foregroundColor: Colors.white,
            elevation: 2,
            actions: [
              // ✨ MODIFIED: Nested the builders to listen to both notifiers.
              ValueListenableBuilder(
                valueListenable: homeSortNotifier,
                builder: (context, sortValue, child) {
                  // This inner builder ensures the menu rebuilds when the theme changes.
                  return ValueListenableBuilder(
                    valueListenable: selectedThemeNotifier,
                    builder: (context, isDarkMode, child) {
                      return PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) {
                          if (value == 'toggle_theme') {
                            saveThemePreference(
                              isDarkMode: !isDarkMode,
                              color: selectedColorNotifier.value,
                            );
                          } else if (value.startsWith('sort_')) {
                            // This part remains the same.
                            final optionName = value.replaceFirst('sort_', '');
                            final option = HomeSortOption.values.firstWhere(
                                (e) => e.name == optionName);
                            saveHomeSortPreference(option);
                          }
                        },
                        itemBuilder: (context) => [
                          // --- Theme Toggle Option ---
                          PopupMenuItem<String>(
                            value: 'toggle_theme',
                            child: Row(
                              children: [
                                Icon(
                                  isDarkMode
                                      ? Icons.light_mode_outlined
                                      : Icons.dark_mode_outlined,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Text(isDarkMode
                                    ? 'Switch to Light Mode'
                                    : 'Switch to Dark Mode'),
                              ],
                            ),
                          ),
                          // --- Sort Sub-menu ---
                          PopupMenuItem<String>(
                            padding: EdgeInsets.zero,
                            child: PopupMenuButton<String>(
                              tooltip: 'Sort folders',
                              child: const Padding(
                                padding: EdgeInsets.only(
                                    left: 16.0,
                                    right: 8.0,
                                    top: 12.0,
                                    bottom: 12.0),
                                child: Row(
                                  children: [
                                    Icon(Icons.sort),
                                    SizedBox(width: 12),
                                    Text('Sort by'),
                                    Spacer(),
                                    Icon(Icons.arrow_right),
                                  ],
                                ),
                              ),
                              onSelected: (value) {
                                final optionName =
                                    value.replaceFirst('sort_', '');
                                final option = HomeSortOption.values
                                    .firstWhere((e) => e.name == optionName);
                                saveHomeSortPreference(option);
                              },
                              itemBuilder: (context) => [
                                // ✨ ADDED: Manual sort option.
                                CheckedPopupMenuItem<String>(
                                  value: 'sort_manual',
                                  checked:
                                      sortValue == HomeSortOption.manual,
                                  child: const Text('Manual'),
                                ),
                                CheckedPopupMenuItem<String>(
                                  value: 'sort_dateNewest',
                                  checked:
                                      sortValue == HomeSortOption.dateNewest,
                                  child: const Text('Newest first'),
                                ),
                                CheckedPopupMenuItem<String>(
                                  value: 'sort_dateOldest',
                                  checked:
                                      sortValue == HomeSortOption.dateOldest,
                                  child: const Text('Oldest first'),
                                ),
                                CheckedPopupMenuItem<String>(
                                  value: 'sort_nameAZ',
                                  checked: sortValue == HomeSortOption.nameAZ,
                                  child: const Text('Name (A-Z)'),
                                ),
                                CheckedPopupMenuItem<String>(
                                  value: 'sort_nameZA',
                                  checked: sortValue == HomeSortOption.nameZA,
                                  child: const Text('Name (Z-A)'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
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