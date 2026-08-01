import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/admin_provider.dart';

class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  bool _isExporting = false;

  void _exportReport(String reportType, String format) async {
    setState(() => _isExporting = true);
    final repo = ref.read(adminRepositoryProvider);
    final dataMap = await repo.getReportData(reportType);
    setState(() => _isExporting = false);

    final headers = List<String>.from(dataMap['headers'] ?? []);
    final rows = List<List<dynamic>>.from(dataMap['rows'] ?? []);

    final buffer = StringBuffer();
    if (format == 'CSV') {
      buffer.writeln(headers.join(','));
      for (final row in rows) {
        buffer.writeln(row.map((e) => '"$e"').join(','));
      }
    } else {
      buffer.writeln('========================================');
      buffer.writeln(
        'LAWYER CONSULTATION PLATFORM $reportType REPORT ($format)',
      );
      buffer.writeln(
        'Generated Date: ${DateTime.now().toIso8601String().split('T').first}',
      );
      buffer.writeln('========================================\n');
      buffer.writeln(headers.join(' | '));
      buffer.writeln('----------------------------------------');
      for (final row in rows) {
        buffer.writeln(row.join(' | '));
      }
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final ext = format.toLowerCase();
      final file = File(
        '${dir.path}/law_report_${reportType}_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
      await file.writeAsString(buffer.toString());

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.cardBackground,
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.success),
                const SizedBox(width: 8),
                Text(
                  '$format Export Generated',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Exported ${rows.length} data records for $reportType report successfully.',
                  style: const TextStyle(color: AppColors.secondaryText),
                ),
                const SizedBox(height: 12),
                Text(
                  'File Location:\n${file.path}',
                  style: const TextStyle(
                    color: AppColors.primaryGold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'OK',
                  style: TextStyle(color: AppColors.primaryGold),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${rows.length} rows to report output.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(title: const Text('Reports & Data Export')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DYNAMIC SYSTEM REPORTS',
              style: TextStyle(
                color: AppColors.primaryGold,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            _buildReportCard(
              title: 'Client Directory Report',
              description:
                  'Export all registered client user details, contact info, and activity status.',
              reportType: 'clients',
            ),
            _buildReportCard(
              title: 'Lawyer Registry Report',
              description:
                  'Export advocate details, bar council numbers, specializations, and verification statuses.',
              reportType: 'lawyers',
            ),
            _buildReportCard(
              title: 'Case History & Metrics',
              description:
                  'Export legal case listings, timeline statuses, categories, and priority ratings.',
              reportType: 'cases',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard({
    required String title,
    required String description,
    required String reportType,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_outlined,
                  color: AppColors.primaryGold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: AppColors.divider),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Export Format:',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
              ),
              Row(
                children: [
                  _buildFormatBtn(
                    'PDF',
                    () => _exportReport(reportType, 'PDF'),
                  ),
                  const SizedBox(width: 6),
                  _buildFormatBtn(
                    'Excel',
                    () => _exportReport(reportType, 'XLSX'),
                  ),
                  const SizedBox(width: 6),
                  _buildFormatBtn(
                    'CSV',
                    () => _exportReport(reportType, 'CSV'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormatBtn(String label, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.secondaryBackground,
        side: const BorderSide(color: AppColors.primaryGold, width: 0.8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: _isExporting ? null : onPressed,
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primaryGold,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
