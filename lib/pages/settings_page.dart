// lib/pages/settings_page.dart
import 'package:flutter/material.dart';
import '../utils/storage_helper.dart'; // ✅ Needed for rebuild function
import '../data/notifiers.dart';       // ✅ To refresh UI after rebuild
import 'recycle_bin_page.dart';        // ✨ Recycle bin import

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  // Show a simple snackbar message for other "coming soon" buttons
  void _showComingSoon(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title – Coming soon!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Reusable styled setting button
  Widget _buildSettingButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Future<void> _confirmAndRebuildDatabase(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rebuild Database'),
        content: const Text(
          'This will rescan your vault folder on disk and restore any missing folders or files to the database.\n\n'
          'It will NOT delete anything.\n\nProceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rebuild'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rebuilding database... Please wait.')),
    );

    try {
      await StorageHelper.rebuildDatabaseFromDisk();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Database successfully rebuilt and refreshed!'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to rebuild database: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // The Scaffold's AppBar was removed because the MainScreen already provides one.
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // 🗑️ Recycle Bin (always first)
        _buildSettingButton(
          context: context,
          icon: Icons.delete_outline,
          label: 'Recycle Bin',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RecycleBinPage()),
            );
          },
        ),

        const Divider(),

        // 🧰 Rebuild Database (NEW FEATURE)
        _buildSettingButton(
          context: context,
          icon: Icons.build,
          label: 'Rebuild Database',
          onTap: () => _confirmAndRebuildDatabase(context),
        ),

        const Divider(),

        // 🌓 Change Theme
        _buildSettingButton(
          context: context,
          icon: Icons.brightness_6,
          label: 'Change Theme',
          onTap: () => _showComingSoon(context, 'Change Theme'),
        ),

        // 🎭 Icon Disguise
        _buildSettingButton(
          context: context,
          icon: Icons.shield,
          label: 'Icon Disguise',
          onTap: () => _showComingSoon(context, 'Icon Disguise'),
        ),

        // 🔑 Fake Password
        _buildSettingButton(
          context: context,
          icon: Icons.lock_outline,
          label: 'Fake Password',
          onTap: () => _showComingSoon(context, 'Fake Password'),
        ),

        // 📱 Device Migration
        _buildSettingButton(
          context: context,
          icon: Icons.sync_alt,
          label: 'Device Migration',
          onTap: () => _showComingSoon(context, 'Device Migration'),
        ),

        // 🔁 Backup & Restore
        _buildSettingButton(
          context: context,
          icon: Icons.backup,
          label: 'Backup & Restore',
          onTap: () => _showComingSoon(context, 'Backup & Restore'),
        ),
      ],
    );
  }
}
