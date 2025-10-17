// lib/pages/theme_settings_page.dart
import 'package:flutter/material.dart';
import '../data/notifiers.dart';

/// A page for users to change theme settings like dark/light mode and primary color.
class ThemeSettingsPage extends StatefulWidget {
  const ThemeSettingsPage({super.key});

  @override
  State<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends State<ThemeSettingsPage> {
  // Local state to hold temporary selections.
  // Initialized with the current global theme values.
  late bool _isDarkMode;
  late Color _selectedColor;

  // A predefined list of Material Design colors for the user to choose from.
  final List<Color> _availableMaterialColors = [
    Colors.blue,
    Colors.lightBlue,
    Colors.lightBlueAccent,
    Colors.blueAccent,
    Colors.red,
    Colors.redAccent,
    Colors.green,
    Colors.greenAccent,
    Colors.lightGreen,
    Colors.lightGreenAccent,
    Colors.purple,
    Colors.purpleAccent,
    Colors.deepPurple,
    Colors.deepPurpleAccent,
    Colors.orange,
    Colors.orangeAccent,
    Colors.deepOrange,
    Colors.deepOrangeAccent,
    Colors.teal,
    Colors.tealAccent,
    Colors.pink,
    Colors.pinkAccent,
    Colors.indigo,
    Colors.indigoAccent,
    Colors.cyan,
    Colors.cyanAccent,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
  ];

  @override
  void initState() {
    super.initState();
    // Initialize local state from the global notifiers when the page is first opened.
    _isDarkMode = selectedThemeNotifier.value;
    _selectedColor = selectedColorNotifier.value;
  }

  /// Saves the selected theme settings to SharedPreferences and updates global state.
  Future<void> _saveSettings() async {
    // Call the central function to save both preferences.
    await saveThemePreference(
      isDarkMode: _isDarkMode,
      color: _selectedColor,
    );

    // Pop the page to return to the main settings screen.
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // To show temporary changes, we build the page theme with the local selections.
    final tempTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _selectedColor,
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
      ),
    );

    return Theme(
      data: tempTheme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Theme Settings'),
          // The AppBar color reflects the temporary color selection.
          backgroundColor: tempTheme.colorScheme.inversePrimary,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // --- Dark/Light Mode Switch ---
            SwitchListTile(
              title: const Text('Dark Mode'),
              secondary: Icon(
                _isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              ),
              value: _isDarkMode,
              onChanged: (bool value) {
                // Update the local state to reflect the change immediately on this page.
                setState(() {
                  _isDarkMode = value;
                });
              },
            ),

            const Divider(height: 32),

            // --- Theme Color Picker ---
            Padding(
              padding: const EdgeInsets.only(left: 8.0, bottom: 16),
              child: Text(
                'Theme Color',
                style: tempTheme.textTheme.titleLarge,
              ),
            ),
            Wrap(
              spacing: 12.0,
              runSpacing: 12.0,
              alignment: WrapAlignment.center,
              children: _availableMaterialColors.map((color) {
                final isSelected = color.value == _selectedColor.value;
                return GestureDetector(
                  onTap: () {
                    // Update the local color state to show the temporary selection.
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: tempTheme.colorScheme.onSurface,
                              width: 3.0,
                            )
                          : Border.all(
                              color: tempTheme.colorScheme.outline.withOpacity(0.5),
                              width: 1.0,
                            ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        // --- Bottom Action Buttons ---
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: _saveSettings,
                  child: const Text('Save'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}