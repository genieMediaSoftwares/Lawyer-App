import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';

class LawyerSettingsScreen extends ConsumerStatefulWidget {
  const LawyerSettingsScreen({super.key});

  @override
  ConsumerState<LawyerSettingsScreen> createState() => _LawyerSettingsScreenState();
}

class _LawyerSettingsScreenState extends ConsumerState<LawyerSettingsScreen> {
  bool _pushNotifications = true;
  bool _emailAlerts = true;
  bool _darkMode = true;
  String _selectedLanguage = "English";

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Settings",
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Push notifications
          _buildSectionHeader("Notifications"),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.outline),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  value: _pushNotifications,
                  activeColor: theme.colorScheme.primary,
                  title: const Text("Push Notifications", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text("Receive alerts about active cases, client requests, and chats", style: TextStyle(fontSize: 11)),
                  onChanged: (val) => setState(() => _pushNotifications = val),
                ),
                Divider(color: theme.colorScheme.outline, height: 1),
                SwitchListTile(
                  value: _emailAlerts,
                  activeColor: theme.colorScheme.primary,
                  title: const Text("Email Notifications", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text("Receive updates regarding weekly briefings and payout settlements", style: TextStyle(fontSize: 11)),
                  onChanged: (val) => setState(() => _emailAlerts = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Preferences
          _buildSectionHeader("Preferences"),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.outline),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  value: _darkMode,
                  activeColor: theme.colorScheme.primary,
                  title: const Text("Dark Theme Mode", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text("Switch to dark color schemes (Simulated)", style: TextStyle(fontSize: 11)),
                  onChanged: (val) => setState(() => _darkMode = val),
                ),
                Divider(color: theme.colorScheme.outline, height: 1),
                ListTile(
                  title: const Text("Language Selection", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text("Current: $_selectedLanguage", style: const TextStyle(fontSize: 11)),
                  trailing: Icon(Icons.arrow_forward_ios, size: 14, color: theme.colorScheme.primary),
                  onTap: _showLanguageSelector,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Security & Support
          _buildSectionHeader("Account & Support"),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.outline),
            ),
            child: Column(
              children: [
                ListTile(
                  title: const Text("Delete Account Permanently", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.error)),
                  leading: const Icon(Icons.delete_forever, color: AppColors.error),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.error),
                  onTap: _confirmDeleteAccount,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String label) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.primary),
      ),
    );
  }

  void _showLanguageSelector() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ["English", "Hindi", "Telugu", "Tamil", "Kannada"].map((lang) {
            return ListTile(
              title: Text(lang),
              trailing: _selectedLanguage == lang ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
              onTap: () {
                setState(() => _selectedLanguage = lang);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Account", style: TextStyle(color: AppColors.error)),
        content: const Text("Deleting your account is permanent. All cases, payout history, and certifications will be erased from Genie Law. Proceed?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete Account", style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account deletion simulated successfully.")));
    }
  }
}
