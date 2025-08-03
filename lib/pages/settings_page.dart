import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  // Show a simple snackbar message for all "coming soon" buttons
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // 🗑️ Recycle Bin (always first)
          _buildSettingButton(
            context: context,
            icon: Icons.delete_outline,
            label: 'Recycle Bin',
            onTap: () => _showComingSoon(context, 'Recycle Bin'),
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
      ),
    );
  }
}
