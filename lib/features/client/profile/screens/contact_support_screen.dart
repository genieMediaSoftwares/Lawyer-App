import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/document_provider.dart';
import '../../../../providers/issue_provider.dart';

class ContactSupportScreen extends ConsumerStatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  ConsumerState<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends ConsumerState<ContactSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCategory = "General Inquiry";

  /// The attachment actually uploaded to the server, if any.
  DocumentRecord? _attachment;
  bool _isAttaching = false;

  bool _isSubmitting = false;
  bool _isSuccess = false;
  String? _submitError;

  /// The id of the ticket the server created. Empty until it has.
  String _ticketId = "";

  String? get _attachedFileName => _attachment?.originalName;

  final List<String> _ticketCategories = [
    "General Inquiry",
    "Case Posting",
    "Consultations & Booking",
    "Billing & Payments",
    "Technical Issue",
    "Feedback",
  ];

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Picks a screenshot and uploads it.
  ///
  /// This used to invent a filename — `screenshot_bug_report_<random>.png` —
  /// and show it as attached, so a client reporting a bug believed they had
  /// sent an image that never existed.
  Future<void> _attachScreenshot() async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'pdf'],
        withData: kIsWeb,
      );
      if (picked == null || picked.files.isEmpty) return;

      final file = picked.files.first;
      if (file.size > 10 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Maximum attachment size is 10 MB.")),
        );
        return;
      }

      setState(() => _isAttaching = true);

      final record = await ref.read(documentsProvider.notifier).uploadDocument(
            kIsWeb ? null : file.path,
            file.name,
            bytes: file.bytes,
          );

      if (!mounted) return;
      setState(() {
        _attachment = record;
        _isAttaching = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            record == null
                ? "Could not upload the attachment. Please try again."
                : "Attached: ${record.originalName}",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAttaching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not attach the file: $e")),
      );
    }
  }

  void _removeScreenshot() {
    setState(() => _attachment = null);
  }

  /// Files the support ticket against the real `POST /issues/create` endpoint.
  ///
  /// This screen previously submitted nothing at all: it waited on a
  /// `Future.delayed`, generated `GL-<random>` locally, and reported success.
  /// Every ticket a client believed they had raised was discarded on the
  /// device, and the admin support queue never saw it.
  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final response = await DioClient.dio.post("/issues/create", data: {
        "title": _subjectController.text.trim(),
        "description": _descriptionController.text.trim(),
        "category": _selectedCategory,
        if (_attachment != null)
          "documents": [
            {
              "name": _attachment!.originalName,
              "url": _attachment!.filePath,
              "size": "${_attachment!.fileSize}",
            }
          ],
      });

      final body = response.data;
      if (body is! Map || body['success'] != true) {
        throw Exception(
          (body is Map ? body['message'] : null)?.toString() ??
              "Could not raise your ticket.",
        );
      }

      // The ticket id comes from the record the server created — the client
      // does not name it.
      final data = body['data'];
      final id = (data is Map ? (data['_id'] ?? data['ticketId']) : null)?.toString() ?? '';

      // Keep the client's own ticket list current.
      await ref.read(issuesProvider.notifier).fetchIssues();

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _isSuccess = true;
        _ticketId = id;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submitError = e.toString().replaceAll("Exception: ", "");
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_submitError!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Contact Support",
          style: TextStyle(
            color: AppColors.primaryText,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _isSuccess ? _buildSuccessView() : _buildFormView(),
      ),
    );
  }

  Widget _buildSuccessView() {
    return SingleChildScrollView(
      key: const ValueKey("success"),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primaryGold, width: 2),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              size: 72,
              color: AppColors.primaryGold,
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            "Ticket Submitted!",
            style: TextStyle(
              color: AppColors.primaryText,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Your ticket has been logged successfully. A support specialist will review your inquiry shortly.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.mutedText,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Ticket Reference ID:",
                  style: TextStyle(color: AppColors.mutedText, fontSize: 13),
                ),
                Flexible(
                  child: Text(
                    _ticketId,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.primaryGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                foregroundColor: AppColors.onGold,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Back to Support",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormView() {
    return SingleChildScrollView(
      key: const ValueKey("form"),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Direct Contact Channels Header
          const Text(
            "QUICK CHANNELS",
            style: TextStyle(
              color: AppColors.mutedText,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),

          // Cards for Channels
          LayoutBuilder(builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildChannelCard(
                  width: cardWidth,
                  icon: Icons.chat_bubble_outline_rounded,
                  title: "Live Chat",
                  subtitle: "Immediate response",
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Launching secure chat...")),
                    );
                  },
                ),
                _buildChannelCard(
                  width: cardWidth,
                  icon: Icons.email_outlined,
                  title: "Email Support",
                  subtitle: "support@genielaw.com",
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Opening email app...")),
                    );
                  },
                ),
                _buildChannelCard(
                  width: cardWidth,
                  icon: Icons.phone_outlined,
                  title: "Phone Support",
                  subtitle: "+1 (800) 555-0199",
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Dialing support line...")),
                    );
                  },
                ),
                _buildChannelCard(
                  width: cardWidth,
                  icon: Icons.message_outlined,
                  title: "WhatsApp",
                  subtitle: "Instant Messenger",
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Opening WhatsApp...")),
                    );
                  },
                ),
              ],
            );
          }),

          const SizedBox(height: 24),

          // 2. Form section
          const Text(
            "SUBMIT A SUPPORT TICKET",
            style: TextStyle(
              color: AppColors.mutedText,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subject
                  const Text(
                    "Subject",
                    style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _subjectController,
                    style: const TextStyle(color: AppColors.primaryText, fontSize: 14),
                    validator: (val) => val == null || val.trim().isEmpty ? "Subject is required" : null,
                    decoration: InputDecoration(
                      hintText: "Short summary of your issue",
                      hintStyle: const TextStyle(color: AppColors.mutedText, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.border,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.primaryGold),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.error),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.error),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category
                  const Text(
                    "Category",
                    style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: AppColors.primaryText, fontSize: 14),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedCategory = val);
                      }
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.border,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.primaryGold),
                      ),
                    ),
                    items: _ticketCategories.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text(cat),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  const Text(
                    "Description",
                    style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    style: const TextStyle(color: AppColors.primaryText, fontSize: 14),
                    maxLines: 4,
                    validator: (val) => val == null || val.trim().isEmpty ? "Description details are required" : null,
                    decoration: InputDecoration(
                      hintText: "Explain the details of your request or error...",
                      hintStyle: const TextStyle(color: AppColors.mutedText, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.border,
                      contentPadding: const EdgeInsets.all(14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.primaryGold),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.error),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.error),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Attach Screenshot
                  if (_attachedFileName == null)
                    OutlinedButton.icon(
                      onPressed: _isAttaching ? null : _attachScreenshot,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryGold,
                        side: const BorderSide(color: AppColors.primaryGold),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: _isAttaching
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.attach_file, size: 18),
                      label: Text(
                        _isAttaching ? "Uploading…" : "Attach Screenshot",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.image, color: AppColors.primaryGold, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _attachedFileName!,
                              style: const TextStyle(color: AppColors.primaryText, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.close, color: AppColors.error, size: 18),
                            onPressed: _removeScreenshot,
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitTicket,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGold,
                        foregroundColor: AppColors.onGold,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.onGold),
                              ),
                            )
                          : const Text(
                              "Submit Ticket",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 3. Business Hours & Response Time Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.schedule, color: AppColors.primaryGold, size: 18),
                    SizedBox(width: 8),
                    Text(
                      "Business Hours & SLA",
                      style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  "• Support Channels: Available 24/7 (Live Chat & Phone)\n"
                  "• Support Ticket Desk: 9:00 AM - 6:00 PM (Monday - Saturday)\n"
                  "• SLA Response SLA: Tickets are processed within 2 to 4 business hours.",
                  style: TextStyle(color: AppColors.mutedText, fontSize: 12.5, height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 4. Emergency Disclaimer Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.statWarningBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.statWarningBg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "EMERGENCY LEGAL DISCLAIMER",
                      style: TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  "This customer care desk handles application usage, account, and billing queries. If you are experiencing an urgent legal emergency, please contact local emergency authorities or consult a licensed advocate directly. Support representatives are not legal practitioners and cannot provide formal legal advice.",
                  style: TextStyle(
                    color: AppColors.disclaimerText,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildChannelCard({
    required double width,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primaryGold, size: 24),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.mutedText, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
