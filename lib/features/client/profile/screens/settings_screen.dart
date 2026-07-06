import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_drawer.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _pushNotifications = true;
  bool _emailAlerts = true;
  bool _darkMode = false;
  String _selectedLanguage = "English";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.navyBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Push notifications
          _buildSectionHeader("Notifications"),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.grey200)),
            child: Column(
              children: [
                SwitchListTile(
                  value: _pushNotifications,
                  activeColor: AppColors.navyBlue,
                  title: const Text("Push Notifications", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text("Receive alerts about consultations, alerts and updates", style: TextStyle(fontSize: 11)),
                  onChanged: (val) => setState(() => _pushNotifications = val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _emailAlerts,
                  activeColor: AppColors.navyBlue,
                  title: const Text("Email Notifications", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text("Receive updates regarding reports and files directly", style: TextStyle(fontSize: 11)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.grey200)),
            child: Column(
              children: [
                SwitchListTile(
                  value: _darkMode,
                  activeColor: AppColors.navyBlue,
                  title: const Text("Dark Theme Mode", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text("Switch to dark color schemes (Simulated)", style: TextStyle(fontSize: 11)),
                  onChanged: (val) => setState(() => _darkMode = val),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text("Language Selection", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text("Current: $_selectedLanguage", style: const TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.grey200)),
            child: Column(
              children: [
                ListTile(
                  title: const Text("Privacy Guidelines", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  leading: const Icon(Icons.security, color: AppColors.navyBlue),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text("Customer Help Support", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  leading: const Icon(Icons.help_outline, color: AppColors.navyBlue),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text("Delete Account Permanently", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red)),
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.red),
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
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navyBlue),
      ),
    );
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ["English", "Hindi", "Telugu", "Kannada"].map((lang) {
            return ListTile(
              title: Text(lang),
              trailing: _selectedLanguage == lang ? const Icon(Icons.check, color: AppColors.navyBlue) : null,
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
        title: const Text("Delete Account", style: TextStyle(color: Colors.red)),
        content: const Text("Deleting your account is permanent. All case progress, consultation history, and uploaded documents will be erased. Proceed?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete Account", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account deletion simulated successfully.")));
    }
  }
}
