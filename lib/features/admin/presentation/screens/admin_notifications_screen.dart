import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/admin_provider.dart';

class AdminNotificationsScreen extends ConsumerStatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  ConsumerState<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends ConsumerState<AdminNotificationsScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _targetRole = 'all';
  bool _isSending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _sendNotification() async {
    if (_titleController.text.isEmpty || _messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both title and message text')),
      );
      return;
    }

    setState(() => _isSending = true);
    final repo = ref.read(adminRepositoryProvider);
    final success = await repo.broadcastNotification(
      _titleController.text,
      _messageController.text,
      _targetRole,
    );
    setState(() => _isSending = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Broadcast Notification sent successfully! 🚀')),
      );
      _titleController.clear();
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        title: const Text('Broadcast Push Notifications'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Compose Announcement / Broadcast', style: TextStyle(color: AppColors.primaryText, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(color: AppColors.primaryText),
                    decoration: const InputDecoration(
                      hintText: 'Notification Title',
                      labelText: 'Title',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _messageController,
                    style: const TextStyle(color: AppColors.primaryText),
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Enter push message details to broadcast to active users...',
                      labelText: 'Message Body',
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Target Audience / Role:', style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildTargetRadio('All Users', 'all'),
                      const SizedBox(width: 8),
                      _buildTargetRadio('Clients Only', 'client'),
                      const SizedBox(width: 8),
                      _buildTargetRadio('Lawyers Only', 'lawyer'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: _isSending
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onGold))
                          : const Icon(Icons.send, color: AppColors.onGold),
                      label: Text(_isSending ? 'Sending...' : 'Send Broadcast Push Notification'),
                      onPressed: _isSending ? null : _sendNotification,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetRadio(String label, String value) {
    final isSelected = _targetRole == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (sel) {
        if (sel) setState(() => _targetRole = value);
      },
      selectedColor: AppColors.primaryGold,
      backgroundColor: AppColors.secondaryBackground,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.onGold : AppColors.primaryGold,
        fontWeight: FontWeight.bold,
        fontSize: 11,
      ),
    );
  }
}
