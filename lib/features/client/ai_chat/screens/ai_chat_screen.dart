import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants/ai_suggestions.dart';

import '../../dashboard/widgets/ai_legal_assistant_card.dart';
import '../../../../core/network/api_client.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen>
    with SingleTickerProviderStateMixin {
  final List<Map<String, dynamic>> _messages = [
    {
      "isMe": false,
      "text":
          "Hello! I am **GenieLaw AI**, your intelligent AI Legal Assistant. ⚖️🤖\n\nI can help you understand legal concepts, explain Indian legal procedures, suggest next steps, list required documents, and guide you through legal topics.\n\n*Disclaimer: Responses are provided for informational purposes only and should not be considered professional legal advice. For case-specific advice, please consult a qualified advocate.*",
      "time": "Just now",
    },
  ];

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isThinking = false;
  late AnimationController _thinkingAnimController;

  // Persistent Conversation History State
  String? _currentConversationId;
  List<Map<String, dynamic>> _userConversations = [];
  bool _isLoadingHistory = false;
  bool _isFetchingConversation = false;

  @override
  void initState() {
    super.initState();
    _thinkingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _loadHistoryAndRestoreLastSession();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _thinkingAnimController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _loadHistoryAndRestoreLastSession() async {
    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final response = await ApiClient.get('/ai/conversations');
      if (!mounted) return;

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['success'] == true &&
            data['data'] != null &&
            data['data']['conversations'] != null) {
          final List convs = data['data']['conversations'];
          setState(() {
            _userConversations = List<Map<String, dynamic>>.from(convs);
          });

          // If user has past active conversations, auto-restore the most recent one
          if (_userConversations.isNotEmpty) {
            final latestId = _userConversations.first['id'];
            await _loadConversationById(latestId, showLoading: false);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading chat history: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    }
  }

  Future<void> _refreshConversationsList() async {
    try {
      final response = await ApiClient.get('/ai/conversations');
      if (!mounted) return;
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['success'] == true &&
            data['data'] != null &&
            data['data']['conversations'] != null) {
          final List convs = data['data']['conversations'];
          setState(() {
            _userConversations = List<Map<String, dynamic>>.from(convs);
          });
        }
      }
    } catch (e) {
      debugPrint('Error refreshing conversations list: $e');
    }
  }

  Future<void> _loadConversationById(
    String conversationId, {
    bool showLoading = true,
  }) async {
    if (showLoading) {
      setState(() {
        _isFetchingConversation = true;
      });
    }

    try {
      final response = await ApiClient.get('/ai/conversations/$conversationId');
      if (!mounted) return;

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['success'] == true &&
            data['data'] != null &&
            data['data']['conversation'] != null) {
          final conv = data['data']['conversation'];
          final List msgList = conv['messages'] ?? [];

          final List<Map<String, dynamic>> formattedMsgs = [];

          // Add default welcome header at top
          formattedMsgs.add({
            "isMe": false,
            "text":
                "Hello! I am **GenieLaw AI**, your intelligent AI Legal Assistant. ⚖️🤖\n\nI can help you understand legal concepts, explain Indian legal procedures, suggest next steps, list required documents, and guide you through legal topics.\n\n*Disclaimer: Responses are provided for informational purposes only and should not be considered professional legal advice. For case-specific advice, please consult a qualified advocate.*",
            "time": "Just now",
          });

          for (final item in msgList) {
            final role = item['role'];
            final isMe = role == 'user';
            formattedMsgs.add({
              "isMe": isMe,
              "text": item['text'] ?? "",
              "time": item['timestamp'] != null
                  ? _formatTimestamp(
                      DateTime.tryParse(item['timestamp'].toString()),
                    )
                  : "Just now",
            });
          }

          setState(() {
            _currentConversationId = conversationId;
            _messages.clear();
            _messages.addAll(formattedMsgs);
          });

          Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
        }
      }
    } catch (e) {
      debugPrint('Error fetching conversation details: $e');
    } finally {
      if (mounted && showLoading) {
        setState(() {
          _isFetchingConversation = false;
        });
      }
    }
  }

  void _startNewChat() {
    setState(() {
      _currentConversationId = null;
      _messages.clear();
      _messages.add({
        "isMe": false,
        "text":
            "Hello! I am **GenieLaw AI**, your intelligent AI Legal Assistant. ⚖️🤖\n\nI can help you understand legal concepts, explain Indian legal procedures, suggest next steps, list required documents, and guide you through legal topics.\n\n*Disclaimer: Responses are provided for informational purposes only and should not be considered professional legal advice. For case-specific advice, please consult a qualified advocate.*",
        "time": "Just now",
      });
    });
  }

  Future<void> _sendQuery(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _messages.add({"isMe": true, "text": query, "time": "Just now"});
      _isThinking = true;
    });
    _messageController.clear();
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);

    try {
      final response = await ApiClient.post('/ai/chat', {
        'message': query,
        if (_currentConversationId != null)
          'conversationId': _currentConversationId,
      });

      if (!mounted) return;

      if (response.statusCode == 200 && response.data != null) {
        final responseData = response.data;
        if (responseData['success'] == true && responseData['data'] != null) {
          final replyText = responseData['data']['response'] as String;
          final convId = responseData['data']['conversationId'] as String?;

          setState(() {
            _isThinking = false;
            if (convId != null) {
              _currentConversationId = convId;
            }
            _messages.add({
              "isMe": false,
              "text": replyText,
              "time": "Just now",
            });
          });

          _refreshConversationsList();
          Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
          return;
        }
      }

      throw Exception(response.data?['message'] ?? 'Failed to get a response');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isThinking = false;
        _messages.add({
          "isMe": false,
          "text":
              "### ⚠️ Error Connecting to AI Assistant\n\n"
              "I encountered an issue trying to connect to the Gemini API service. Please ensure that the **GEMINI_API_KEY** is configured correctly in the backend environment.\n\n"
              "*(Falling back to offline helper analysis)*\n\n"
              "${_getProfessionalLegalResponse(query)}",
          "time": "Just now",
        });
      });
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    }
  }

  Future<void> _deleteSingleConversation(String id) async {
    try {
      final response = await ApiClient.delete('/ai/conversations/$id');
      if (response.statusCode == 200 && response.data?['success'] == true) {
        setState(() {
          _userConversations.removeWhere((c) => c['id'] == id);
          if (_currentConversationId == id) {
            _startNewChat();
          }
        });
      }
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
    }
  }

  Future<void> _deleteAllConversations() async {
    try {
      final response = await ApiClient.delete('/ai/conversations');
      if (response.statusCode == 200 && response.data?['success'] == true) {
        setState(() {
          _userConversations.clear();
          _startNewChat();
        });
      }
    } catch (e) {
      debugPrint('Error clearing all conversations: $e');
    }
  }

  void _openHistoryBottomSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              height: MediaQuery.of(context).size.height * 0.65,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Chat History",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (_userConversations.isNotEmpty)
                        TextButton.icon(
                          icon: const Icon(
                            Icons.delete_sweep_outlined,
                            size: 18,
                            color: Colors.redAccent,
                          ),
                          label: const Text(
                            "Clear All",
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                            ),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text("Clear All Chat History?"),
                                content: const Text(
                                  "This action will permanently delete all your AI chat history.",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(),
                                    child: const Text("Cancel"),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.of(ctx).pop();
                                      await _deleteAllConversations();
                                      setSheetState(() {});
                                      if (context.mounted)
                                        Navigator.of(context).pop();
                                    },
                                    child: const Text(
                                      "Delete All",
                                      style: TextStyle(color: Colors.redAccent),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  if (_userConversations.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          "No previous conversations found.",
                          style: TextStyle(
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: _userConversations.length,
                        separatorBuilder: (c, i) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final conv = _userConversations[index];
                          final id = conv['id'] as String;
                          final title = conv['title'] ?? 'Legal Discussion';
                          final lastMsg = conv['lastMessage'] ?? '';
                          final isSelected = id == _currentConversationId;
                          final updatedAt = conv['updatedAt'] != null
                              ? _formatTimestamp(
                                  DateTime.tryParse(
                                    conv['updatedAt'].toString(),
                                  ),
                                )
                              : '';

                          return ListTile(
                            selected: isSelected,
                            selectedTileColor: theme.colorScheme.primary
                                .withValues(alpha: 0.12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            leading: CircleAvatar(
                              backgroundColor: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.surface,
                              child: Icon(
                                Icons.chat_bubble_outline,
                                size: 18,
                                color: isSelected
                                    ? Colors.black
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                            title: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                fontSize: 14,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (lastMsg.isNotEmpty)
                                  Text(
                                    lastMsg,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.textTheme.bodySmall?.color,
                                    ),
                                  ),
                                if (updatedAt.isNotEmpty)
                                  Text(
                                    updatedAt,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: theme.textTheme.bodySmall?.color
                                          ?.withValues(alpha: 0.7),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: Colors.grey,
                              ),
                              onPressed: () async {
                                await _deleteSingleConversation(id);
                                setSheetState(() {});
                              },
                            ),
                            onTap: () async {
                              Navigator.of(context).pop();
                              await _loadConversationById(id);
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatTimestamp(DateTime? dt) {
    if (dt == null) return 'Just now';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _getProfessionalLegalResponse(String query) {
    query = query.toLowerCase();

    if (query.contains("rent") ||
        query.contains("draft") ||
        query.contains("agreement")) {
      return """
### 📄 Residential Rent Agreement Outline
Here is the standard structure for a legally binding residential lease agreement under Indian Law:

1. **Parties Involved**: Complete names and permanent addresses of the Landlord (Lessor) and Tenant (Lessee).
2. **Property Description**: Detailed address, carpet area, and list of fittings or fixtures provided.
3. **Term of Lease**: Typically 11 months to avoid compulsory registration laws.
4. **Rent & Security Deposit**: Propose the monthly rate, due date, and refundable interest-free deposit.
5. **Maintenance & Utility Bills**: Specify who pays water, electricity, and society maintenance bills.
6. **Termination & Notice Period**: Outline how many months' notice (usually 1 or 2 months) is mandatory before vacant possession.

> 💡 **Tip**: We recommend getting the agreement stamped on non-judicial stamp paper of suitable value and registered at the Sub-Registrar office for statutory security.
""";
    }

    if (query.contains("divorce") || query.contains("family")) {
      return """
### ⚖️ Mutual Consent Divorce Procedure (Section 13B)
Under Section 13B of the Hindu Marriage Act, 1955, couples can seek divorce by mutual consent:

* **Step 1: Joint Petition**: Both parties file a joint petition detailing separation periods (minimum 1 year living separately).
* **Step 2: Statements Recorded**: First motion statements are recorded by the family court judge.
* **Step 3: Cooling-off Period**: A cooling period of 6 months is standard (can be waived by supreme court directive in extreme cases).
* **Step 4: Second Motion**: Filed within 18 months of joint petition if settlement terms remain valid.
* **Step 5: Decree Granted**: The court passes the dissolution decree after verifying free consent.
""";
    }

    if (query.contains("fee") || query.contains("cost")) {
      return """
### 💳 Fee Ranges & Consultation Structures
GenieLaw verified advocates charge based on professional standing:

* **Basic Consultation**: ₹1,000 - ₹2,500 per online session.
* **Agreement Drafting**: ₹3,000 - ₹8,000 depending on complexity.
* **Representation & Litigation**: Subject to direct quotes based on court sessions.

> 🔒 **Payment Safety**: All bookings on GenieLaw are processed securely. Invoices are automatically generated on checkout.
""";
    }

    if (query.contains("consumer") || query.contains("complaint")) {
      return """
### 🛍️ Steps to File a Consumer Complaint (RERA / Consumer Forum)
To seek compensation for deficient goods or services:

1. **Send Legal Notice**: Give the merchant 15 days to resolve the defect.
2. **Draft Complaint**: State the facts, date of transaction, deficiency details, and sought relief amount.
3. **File Petition**: Submit on the online *e-Daakhil* portal or physically at the District Commission (cases up to ₹50 Lakhs).
4. **Verify Timeline**: Complaints must be filed within **2 years** from the date the cause of action arose.
""";
    }

    return """
### 🤖 GenieLaw AI Legal Advisor Response
Thank you for your legal inquiry. Based on your inputs, here are the general recommendation steps:

1. **Post your case**: Use the "+" button to post details to our panel.
2. **Review matches**: Find lawyers specializing in this domain.
3. **Schedule Call**: Book an appointment for a detailed legal advice.

Please let me know if you would like me to draft outlines for agreements or explain litigation procedures in detail!
""";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(3),
              child: SvgPicture.string(robotBodySvg, fit: BoxFit.contain),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "AI Legal Assistant",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "Online Legal Advisor",
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: "New Chat",
            onPressed: _startNewChat,
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: "Chat History",
            onPressed: _openHistoryBottomSheet,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_isLoadingHistory || _isFetchingConversation)
              const LinearProgressIndicator(minHeight: 2),

            // Chat Message List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isMe = msg["isMe"] == true;
                  return _buildChatBubble(msg["text"], isMe);
                },
              ),
            ),

            // Shimmer Thinking Indicator
            if (_isThinking) _buildThinkingShimmer(),

            // Suggestions Carousel
            if (_messages.length <= 2 && !_isThinking) _buildSuggestions(),

            // Input Bar
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isMe) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          decoration: BoxDecoration(
            color: isMe ? theme.colorScheme.primary : theme.colorScheme.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isMe
                  ? const Radius.circular(16)
                  : const Radius.circular(0),
              bottomRight: isMe
                  ? const Radius.circular(0)
                  : const Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
            border: isMe ? null : Border.all(color: theme.colorScheme.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_parseMarkdownText(text, isMe)],
          ),
        ),
      ),
    );
  }

  Widget _parseMarkdownText(String text, bool isMe) {
    final theme = Theme.of(context);
    final textStyle = TextStyle(
      color: isMe ? Colors.black : theme.colorScheme.onSurface,
      fontSize: 13.5,
      height: 1.5,
    );

    final lines = text.split('\n');
    List<Widget> children = [];

    for (var line in lines) {
      if (line.trim().isEmpty) {
        children.add(const SizedBox(height: 6));
        continue;
      }

      if (line.startsWith('###')) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              line.replaceAll('###', '').trim(),
              style: TextStyle(
                color: isMe ? Colors.black : theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        );
      } else if (line.startsWith('>')) {
        children.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.only(
              left: 10,
              top: 6,
              bottom: 6,
              right: 6,
            ),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: isMe ? Colors.black : theme.colorScheme.primary,
                  width: 3,
                ),
              ),
              color: (isMe
                  ? Colors.black.withOpacity(0.12)
                  : theme.colorScheme.primary.withOpacity(0.08)),
            ),
            child: Text(
              line.replaceAll('>', '').trim(),
              style: textStyle.copyWith(
                fontStyle: FontStyle.italic,
                fontSize: 13,
              ),
            ),
          ),
        );
      } else if (line.startsWith('*') || line.startsWith('-')) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "• ",
                  style: textStyle.copyWith(fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: Text(line.substring(1).trim(), style: textStyle),
                ),
              ],
            ),
          ),
        );
      } else {
        children.add(Text(line, style: textStyle));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildThinkingShimmer() {
    final theme = Theme.of(context);
    return FadeTransition(
      opacity: _thinkingAnimController,
      child: Container(
        margin: const EdgeInsets.only(left: 16, bottom: 12),
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: SvgPicture.string(
                  robotBodySvg,
                  colorFilter: ColorFilter.mode(
                    theme.colorScheme.primary,
                    BlendMode.srcIn,
                  ),
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "Legal assistant is thinking...",
                style: TextStyle(
                  color: theme.textTheme.bodySmall?.color,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 6),
          child: Text(
            AiSuggestions.popularLegalQuestionsTitle,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodySmall?.color ?? Colors.grey,
            ),
          ),
        ),
        Container(
          height: 48,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: AiSuggestions.popularLegalQuestions.length,
            separatorBuilder: (c, i) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final sug = AiSuggestions.popularLegalQuestions[index];
              return ActionChip(
                label: Text(sug),
                onPressed: () => _sendQuery(sug),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInputBar() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: "Ask me a legal question...",
                fillColor: theme.inputDecorationTheme.fillColor,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              onSubmitted: _sendQuery,
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: theme.colorScheme.primary,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.black, size: 18),
              onPressed: () => _sendQuery(_messageController.text),
            ),
          ),
        ],
      ),
    );
  }
}
