import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/practice_widgets.dart';

/// One turn in a research thread.
class _ResearchMessage {
  const _ResearchMessage({required this.text, required this.fromUser});

  final String text;
  final bool fromUser;
}

/// A summary row in the history sheet.
class _ResearchThread {
  const _ResearchThread({
    required this.id,
    required this.title,
    required this.lastMessage,
  });

  final String id;
  final String title;
  final String lastMessage;
}

/// The advocate-facing research assistant.
///
/// Runs on the AI infrastructure the app already has — the same `/ai/chat`
/// endpoint, the same Gemini client, the same AiConversation storage — with
/// `mode: research`, which switches the server to a persona written for a
/// practising advocate and keeps these threads out of the client-facing AI
/// chat's history.
///
/// What this is NOT: a case-law database. Lawfly has no judgment index, no
/// reporter subscription and no statutory lookup, so nothing here is presented
/// as a verified authority. The banner says so on every screen, and the server
/// prompt instructs the model at length never to manufacture a citation. That
/// restraint is the feature — a fabricated citation handed to an advocate could
/// end up in front of a court.
class LawyerResearchScreen extends ConsumerStatefulWidget {
  const LawyerResearchScreen({super.key});

  @override
  ConsumerState<LawyerResearchScreen> createState() =>
      _LawyerResearchScreenState();
}

class _LawyerResearchScreenState extends ConsumerState<LawyerResearchScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<_ResearchMessage> _messages = [];
  String? _conversationId;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final question = _inputController.text.trim();
    if (question.isEmpty || _sending) return;

    setState(() {
      _messages.add(_ResearchMessage(text: question, fromUser: true));
      _inputController.clear();
      _sending = true;
      _error = null;
    });
    _scrollToEnd();

    try {
      final response = await ApiClient.post('/ai/chat', {
        'message': question,
        'mode': 'research',
        // Absent on the first turn; the server creates the thread and hands
        // back its id, which every later turn carries so the history is kept
        // server-side rather than re-sent from here.
        if (_conversationId != null) 'conversationId': _conversationId,
      });

      if (!mounted) return;

      final data = response.data;
      if (data != null && data['success'] == true) {
        final payload = data['data'];
        // The server returns the answer as `response` and the thread it was
        // stored in as `conversationId`.
        final reply = payload is Map ? payload['response']?.toString() : null;
        final threadId = payload is Map
            ? payload['conversationId']?.toString()
            : null;

        setState(() {
          _sending = false;
          _conversationId = threadId ?? _conversationId;
          if (reply != null && reply.trim().isNotEmpty) {
            _messages.add(_ResearchMessage(text: reply, fromUser: false));
          } else {
            _error = AppLocalizations.of(context)!.research_failed;
          }
        });
      } else {
        setState(() {
          _sending = false;
          _error =
              data?['message']?.toString() ??
              AppLocalizations.of(context)!.research_failed;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = AppLocalizations.of(context)!.research_failed;
      });
    }

    _scrollToEnd();
  }

  void _startNew() {
    setState(() {
      _messages.clear();
      _conversationId = null;
      _error = null;
    });
  }

  Future<void> _openHistory() async {
    final loc = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    List<_ResearchThread> threads = const [];
    try {
      // The mode filter is what keeps a lawyer's research separate from the
      // client-facing assistant's conversations, which share this collection.
      final response = await ApiClient.get('/ai/conversations?mode=research');
      final data = response.data;
      if (data != null && data['success'] == true) {
        final raw = data['data'] is Map
            ? data['data']['conversations']
            : null;
        final list = raw is List ? raw : const [];
        threads = list.map((item) {
          final map = item is Map
              ? Map<String, dynamic>.from(item)
              : <String, dynamic>{};
          return _ResearchThread(
            id: map['id']?.toString() ?? '',
            title: map['title']?.toString() ?? '',
            lastMessage: map['lastMessage']?.toString() ?? '',
          );
        }).toList();
      }
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(loc.something_went_wrong)),
      );
      return;
    }

    if (!mounted) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _HistorySheet(threads: threads),
    );

    if (selected != null && mounted) {
      await _loadThread(selected);
    }
  }

  Future<void> _loadThread(String id) async {
    final loc = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _sending = true);

    try {
      final response = await ApiClient.get('/ai/conversations/$id');
      final data = response.data;

      if (!mounted) return;

      if (data != null && data['success'] == true) {
        final conversation = data['data'] is Map
            ? data['data']['conversation']
            : null;
        final rawMessages = conversation is Map
            ? conversation['messages']
            : null;
        final list = rawMessages is List ? rawMessages : const [];

        setState(() {
          _sending = false;
          _conversationId = id;
          _messages
            ..clear()
            ..addAll(
              list.map((item) {
                final map = item is Map
                    ? Map<String, dynamic>.from(item)
                    : <String, dynamic>{};
                return _ResearchMessage(
                  text: map['text']?.toString() ?? '',
                  fromUser: map['role']?.toString() == 'user',
                );
              }),
            );
        });
        _scrollToEnd();
        return;
      }
    } catch (_) {
      // Falls through to the message below.
    }

    if (!mounted) return;
    setState(() => _sending = false);
    messenger.showSnackBar(SnackBar(content: Text(loc.something_went_wrong)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          loc.research_title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: loc.research_history,
            onPressed: _sending ? null : _openHistory,
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: loc.research_new,
            onPressed: _messages.isEmpty || _sending ? null : _startNew,
          ),
        ],
      ),
      body: SafeArea(
        child: PracticeContentWidth(
          child: Column(
            children: [
              _DisclaimerBanner(text: loc.research_disclaimer),
              Expanded(
                child: _messages.isEmpty && !_sending
                    ? PracticeEmptyState(
                        icon: Icons.travel_explore_outlined,
                        title: loc.research_intro_title,
                        message: loc.research_intro_desc,
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        itemCount: _messages.length + (_sending ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= _messages.length) {
                            return _ThinkingBubble(label: loc.research_thinking);
                          }
                          return _MessageBubble(message: _messages[index]);
                        },
                      ),
              ),

              if (_error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: AppColors.error.withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 14,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              _Composer(
                controller: _inputController,
                enabled: !_sending,
                hintText: loc.research_hint,
                onSend: _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisclaimerBanner extends StatelessWidget {
  const _DisclaimerBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 14,
            color: AppColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.warning,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ResearchMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fromUser = message.fromUser;

    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: fromUser ? theme.colorScheme.primary : theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: fromUser
              ? null
              : Border.all(color: theme.colorScheme.outline),
        ),
        child: fromUser
            ? Text(
                message.text,
                style: const TextStyle(
                  color: AppColors.onGold,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              )
            // Selectable so an advocate can lift a passage straight into a
            // pleading or a note without retyping it.
            : SelectionArea(child: _ResearchMarkdown(text: message.text)),
      ),
    );
  }
}

/// Renders the small subset of markdown the assistant is asked to produce:
/// `###` headings, `-`/`*` bullets, and `**bold**` runs.
///
/// Written here rather than pulling in a markdown package for one screen — the
/// client AI chat already renders its replies the same way, so this keeps the
/// two looking alike without either depending on the other.
class _ResearchMarkdown extends StatelessWidget {
  const _ResearchMarkdown({required this.text});

  final String text;

  /// Splits a line on `**bold**` into styled spans.
  List<TextSpan> _spans(String line, TextStyle base) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    var index = 0;

    for (final match in pattern.allMatches(line)) {
      if (match.start > index) {
        spans.add(TextSpan(text: line.substring(index, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
      index = match.end;
    }

    if (index < line.length) {
      spans.add(TextSpan(text: line.substring(index)));
    }
    return spans.isEmpty ? [TextSpan(text: line)] : spans;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = TextStyle(
      color: theme.colorScheme.onSurface,
      fontSize: 13.5,
      height: 1.5,
    );

    final children = <Widget>[];

    for (final line in text.split('\n')) {
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        children.add(const SizedBox(height: 6));
        continue;
      }

      if (trimmed.startsWith('#')) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              trimmed.replaceAll('#', '').trim(),
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        );
        continue;
      }

      if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: base.copyWith(fontWeight: FontWeight.bold)),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: _spans(trimmed.substring(2), base)),
                    style: base,
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      children.add(
        Text.rich(TextSpan(children: _spans(line, base)), style: base),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.hintText,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final String hintText;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(hintText: hintText, isDense: true),
            ),
          ),
          const SizedBox(width: 8),
          // Rebuilt from the controller so the send button is only live once
          // there is something to send.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              final canSend = enabled && value.text.trim().isNotEmpty;
              return IconButton.filled(
                onPressed: canSend ? onSend : null,
                icon: const Icon(Icons.send, size: 18),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HistorySheet extends StatelessWidget {
  const _HistorySheet({required this.threads});

  final List<_ResearchThread> threads;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              loc.research_history,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (threads.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: Text(
                  loc.no_research_yet_desc,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedText,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: threads.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final thread = threads[index];
                    return PracticeCard(
                      onTap: () => Navigator.of(context).pop(thread.id),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            thread.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          if (thread.lastMessage.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              thread.lastMessage,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.mutedText,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
