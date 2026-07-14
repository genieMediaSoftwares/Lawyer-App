import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/env.dart';
import '../../../../models/case_model.dart';
import '../../../../providers/case_provider.dart';
import '../../../../providers/auth_provider.dart';

// ─── Design tokens (matching reference image exactly) ───────────────────────
const _bg = Color(0xFF0A0A0A);          // pure black background
const _card = Color(0xFF1A1A1A);        // dark card surface
const _gold = Color(0xFFD4A32A);        // gold accent
const _goldBg = Color(0xFF2A1F05);      // gold tint bg for "New" badge
const _divider = Color(0xFF2A2A2A);     // subtle divider
const _matchGreen = Color(0xFF4CE064);  // match % text
const _matchBg = Color(0xFF0D2010);     // match % bg
const _grey = Color(0xFF8A8A8A);        // secondary text
const _tabActive = Color(0xFFD4A32A);   // active tab text
const _tabInactive = Color(0xFF707070); // inactive tab text
const _badgeBg = Color(0xFF2A1E05);     // number badge bg (inactive)

class LawyerLeadsScreen extends ConsumerStatefulWidget {
  const LawyerLeadsScreen({super.key});

  @override
  ConsumerState<LawyerLeadsScreen> createState() => _LawyerLeadsScreenState();
}

class _LawyerLeadsScreenState extends ConsumerState<LawyerLeadsScreen>
    with SingleTickerProviderStateMixin {
  int _tab = 0; // 0=New Leads, 1=Accepted, 2=History
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── match % from case ID hash ──────────────────────────────────────────────
  int _match(String id) {
    const percents = [90, 85, 80, 88, 82, 86, 84, 87, 83, 81];
    return percents[id.hashCode.abs() % percents.length];
  }

  // ── resolve image URL ──────────────────────────────────────────────────────
  ImageProvider? _img(String url) {
    if (url.isEmpty) return null;
    return NetworkImage(Environment.getAttachmentUrl(url));
  }

  // ── filter lists ──────────────────────────────────────────────────────────
  List<CaseModel> _newLeads(List<CaseModel> all, String uid) =>
      all.where((c) {
        final direct = c.selectedLawyerId == uid &&
            (c.status == 'Pending Lawyer Response' ||
                c.status == 'Awaiting Lawyer Acceptance');
        final open = c.status == 'Submitted' && c.selectedLawyerId == null;
        return direct || open;
      }).toList();

  List<CaseModel> _accepted(List<CaseModel> all, String uid) =>
      all.where((c) =>
          c.assignedLawyerId == uid &&
          (c.status == 'Accepted' ||
              c.status == 'In Progress' ||
              c.status == 'Awaiting Client')).toList();

  List<CaseModel> _history(List<CaseModel> all, String uid) =>
      all.where((c) =>
          c.assignedLawyerId == uid &&
          (c.status == 'Completed' ||
              c.status == 'resolved' ||
              c.status == 'Closed' ||
              c.status == 'Rejected' ||
              c.status == 'Expired')).toList();

  List<CaseModel> _filter(List<CaseModel> list) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((c) =>
        c.title.toLowerCase().contains(q) ||
        c.clientName.toLowerCase().contains(q) ||
        c.category.toLowerCase().contains(q) ||
        c.location.toLowerCase().contains(q)).toList();
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authProvider).userId ?? '';
    final async = ref.watch(casesProvider);

    return Container(
      color: _bg,
      child: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_gold),
            strokeWidth: 2.5,
          ),
        ),
        error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () => ref.read(casesProvider.notifier).fetchCases(),
        ),
        data: (all) {
          final newList = _newLeads(all, uid);
          final accList = _accepted(all, uid);
          final hisList = _history(all, uid);
          final active = [newList, accList, hisList][_tab];
          final shown = _filter(active);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Tab row ──────────────────────────────────────────────────
              _TabRow(
                tab: _tab,
                newCount: newList.length,
                accCount: accList.length,
                hisCount: hisList.length,
                onTap: (i) => setState(() => _tab = i),
              ),

              // ── Search + Filter ──────────────────────────────────────────
              _SearchFilterRow(ctrl: _searchCtrl, tab: _tab),

              // ── Section header ───────────────────────────────────────────
              _SectionHeader(tab: _tab),

              // ── Cards ────────────────────────────────────────────────────
              Expanded(
                child: shown.isEmpty
                    ? _EmptyState(tab: _tab)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                        itemCount: shown.length,
                        itemBuilder: (_, i) => _LeadCard(
                          key: ValueKey(shown[i].id),
                          lead: shown[i],
                          tab: _tab,
                          match: _match(shown[i].id),
                          imgProvider: _img(shown[i].clientImage),
                          onAccept: () => _accept(shown[i]),
                          onReject: () => _reject(shown[i]),
                          onComplete: () => _complete(shown[i]),
                          onDetails: () => _details(shown[i]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────
  Future<void> _accept(CaseModel c) async {
    final ok = await _confirm('Accept Case?', 'Accept this case request?', 'Accept');
    if (ok != true || !mounted) return;
    final success = await ref.read(casesProvider.notifier).acceptCaseRequest(c.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'Case accepted! Moved to Accepted.' : 'Failed to accept. Try again.'),
        backgroundColor: success ? const Color(0xFF1B3A1B) : Colors.red.shade900,
      ));
    }
  }

  Future<void> _reject(CaseModel c) async {
    final ok = await _confirm('Reject Lead?', 'Reject this case lead?', 'Reject');
    if (ok != true || !mounted) return;
    final success = await ref.read(casesProvider.notifier).rejectCaseRequest(c.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'Lead rejected.' : 'Failed to reject. Try again.'),
        backgroundColor: success ? const Color(0xFF2A0A0A) : Colors.red.shade900,
      ));
    }
  }

  Future<void> _complete(CaseModel c) async {
    final ok = await _confirm('Complete Case?', 'Mark this case as completed?', 'Complete');
    if (ok != true || !mounted) return;
    final success = await ref.read(casesProvider.notifier).markCaseCompleted(c.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'Case completed!' : 'Failed. Try again.'),
        backgroundColor: success ? const Color(0xFF1B3A1B) : Colors.red.shade900,
      ));
    }
  }

  void _details(CaseModel c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DetailsSheet(lead: c, tab: _tab, onAccept: () {
        Navigator.pop(context);
        _accept(c);
      }),
    );
  }

  Future<bool?> _confirm(String title, String body, String action) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(body, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action, style: const TextStyle(color: _gold, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab Row — matches reference image (gold text + number badge + gold underline)
// ─────────────────────────────────────────────────────────────────────────────
class _TabRow extends StatelessWidget {
  final int tab;
  final int newCount, accCount, hisCount;
  final ValueChanged<int> onTap;

  const _TabRow({
    required this.tab,
    required this.newCount,
    required this.accCount,
    required this.hisCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          _Tab(label: 'New Leads', count: newCount, active: tab == 0, onTap: () => onTap(0)),
          _Tab(label: 'Accepted', count: accCount, active: tab == 1, onTap: () => onTap(1)),
          _Tab(label: 'History', count: hisCount, active: tab == 2, onTap: () => onTap(2)),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  const _Tab({required this.label, required this.count, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: active ? _tabActive : _tabInactive,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: active ? _gold : _badgeBg,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: active ? Colors.black : _gold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                height: 1.5,
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: active ? _gold : Colors.transparent,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search Row (without Filter button, premium clean look)
// ─────────────────────────────────────────────────────────────────────────────
class _SearchFilterRow extends StatelessWidget {
  final TextEditingController ctrl;
  final int tab;

  const _SearchFilterRow({required this.ctrl, required this.tab});

  @override
  Widget build(BuildContext context) {
    final hints = ['Search new leads...', 'Search accepted...', 'Search history...'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _divider, width: 1),
        ),
        child: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hints[tab],
            hintStyle: const TextStyle(color: Color(0xFF555555), fontSize: 14),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Icon(Icons.search, color: _gold, size: 20),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 46),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header (without View All action)
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final int tab;
  const _SectionHeader({required this.tab});

  @override
  Widget build(BuildContext context) {
    const titles = ['New Leads', 'Accepted', 'History'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Text(
        titles[tab],
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lead Card — pixel-perfect match to reference image
// ─────────────────────────────────────────────────────────────────────────────
class _LeadCard extends StatelessWidget {
  final CaseModel lead;
  final int tab;
  final int match;
  final ImageProvider? imgProvider;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onComplete;
  final VoidCallback onDetails;

  const _LeadCard({
    super.key,
    required this.lead,
    required this.tab,
    required this.match,
    required this.imgProvider,
    required this.onAccept,
    required this.onReject,
    required this.onComplete,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _divider, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onDetails,
          borderRadius: BorderRadius.circular(16),
          splashColor: _gold.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Row 1: Avatar | Name+Case | Match badge | ⋮ ──────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar + New pill below
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: const Color(0xFF2A2A2A),
                          backgroundImage: imgProvider,
                          child: imgProvider == null
                              ? Text(
                                  (lead.clientName.isNotEmpty
                                      ? lead.clientName[0].toUpperCase()
                                      : 'C'),
                                  style: const TextStyle(
                                    color: _gold,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                )
                              : null,
                        ),
                        if (tab == 0) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _goldBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _gold.withValues(alpha: 0.6), width: 1),
                            ),
                            child: const Text(
                              'New',
                              style: TextStyle(
                                color: _gold,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(width: 12),

                    // Name + case title
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            lead.clientName.isNotEmpty ? lead.clientName : 'Client',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Case: ${lead.title}',
                            style: const TextStyle(
                              color: Color(0xFF9A9A9A),
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Match badge + more menu
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (tab == 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _matchBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$match% Match',
                              style: const TextStyle(
                                color: _matchGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else
                          _statusBadge(lead.status),
                        _OverflowMenu(
                          tab: tab,
                          status: lead.status,
                          onReject: onReject,
                          onComplete: onComplete,
                          onDetails: onDetails,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Row 2: Location | Category ───────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _InfoChip(
                        icon: Icons.location_on_outlined,
                        text: lead.location.isNotEmpty ? lead.location : 'Any Location',
                      ),
                    ),
                    Expanded(
                      child: _InfoChip(
                        icon: Icons.gavel_rounded,
                        text: lead.category,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ── Row 3: Urgency | Docs ────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _InfoChip(
                        icon: Icons.access_time_rounded,
                        text: 'Urgency: ${lead.urgency}',
                      ),
                    ),
                    Expanded(
                      child: _InfoChip(
                        icon: Icons.insert_drive_file_outlined,
                        text: '${lead.documents.length} '
                            '${lead.documents.length == 1 ? 'doc' : 'docs'} uploaded',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── Date line ────────────────────────────────────────────
                Text(
                  _dateLine(tab, lead),
                  style: const TextStyle(color: Color(0xFF666666), fontSize: 12),
                ),
                const SizedBox(height: 14),

                // ── Action Buttons ───────────────────────────────────────
                if (tab == 0)
                  Row(
                    children: [
                      Expanded(
                        child: _OutlinedBtn(label: 'View Details', onTap: onDetails),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SolidBtn(label: 'Accept Case', onTap: onAccept),
                      ),
                    ],
                  )
                else if (tab == 1)
                  _OutlinedBtn(label: 'View Case', onTap: onDetails, fullWidth: true)
                else
                  _OutlinedBtn(label: 'View Details', onTap: onDetails, fullWidth: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'In Progress':
        bg = const Color(0xFF2A1A05);
        fg = Colors.orange;
        break;
      case 'Accepted':
        bg = const Color(0xFF0D2010);
        fg = _matchGreen;
        break;
      case 'Completed':
      case 'resolved':
        bg = const Color(0xFF0D2010);
        fg = _matchGreen;
        break;
      case 'Rejected':
      case 'Expired':
      case 'Closed':
        bg = const Color(0xFF2A0A0A);
        fg = Colors.redAccent;
        break;
      default:
        bg = const Color(0xFF1A1A2A);
        fg = Colors.blueAccent;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _dateLine(int tab, CaseModel c) {
    final fmt = DateFormat('dd MMM yyyy, hh:mm a');
    final fmtShort = DateFormat('dd MMM yyyy');
    if (tab == 0) return 'Posted on: ${fmt.format(c.createdAt)}';
    if (tab == 1) return 'Accepted on: ${fmt.format(c.acceptedAt ?? c.createdAt)}';
    return 'Completed on: ${fmtShort.format(c.completedAt ?? c.closedDate ?? c.createdAt)}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info chip (icon + text)
// ─────────────────────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: _grey),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: _grey, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overflow menu (three-dot)
// ─────────────────────────────────────────────────────────────────────────────
class _OverflowMenu extends StatelessWidget {
  final int tab;
  final String status;
  final VoidCallback onReject;
  final VoidCallback onComplete;
  final VoidCallback onDetails;

  const _OverflowMenu({
    required this.tab,
    required this.status,
    required this.onReject,
    required this.onComplete,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_vert, color: Color(0xFF888888), size: 20),
      color: const Color(0xFF222222),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        _menuItem('details', Icons.info_outline, 'View Details', Colors.white70),
        if (tab == 0)
          _menuItem('reject', Icons.close, 'Reject Lead', Colors.redAccent),
        if (tab == 1 && status != 'Completed' && status != 'Closed')
          _menuItem('complete', Icons.check_circle_outline, 'Mark Completed', _matchGreen),
      ],
      onSelected: (v) {
        if (v == 'details') onDetails();
        if (v == 'reject') onReject();
        if (v == 'complete') onComplete();
      },
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label, Color color) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: color, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Buttons
// ─────────────────────────────────────────────────────────────────────────────
class _OutlinedBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool fullWidth;
  const _OutlinedBtn({required this.label, required this.onTap, this.fullWidth = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: 44,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _gold, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          foregroundColor: _gold,
          minimumSize: const Size(0, 44),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _gold,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _SolidBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SolidBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _gold,
          foregroundColor: Colors.black,
          minimumSize: const Size(0, 44),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final int tab;
  const _EmptyState({required this.tab});

  @override
  Widget build(BuildContext context) {
    const msgs = [
      'No new case leads.\nCheck back later!',
      'No accepted cases yet.',
      'No case history found.',
    ];
    const icons = [
      Icons.gavel_outlined,
      Icons.assignment_turned_in_outlined,
      Icons.history_outlined,
    ];
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icons[tab], color: const Color(0xFF333333), size: 60),
          const SizedBox(height: 16),
          Text(
            msgs[tab],
            style: const TextStyle(color: Color(0xFF555555), fontSize: 14, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error State
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Color(0xFF555555), size: 60),
            const SizedBox(height: 16),
            const Text(
              'Failed to load leads.',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: Color(0xFF666666), fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _gold),
                foregroundColor: _gold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Details bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _DetailsSheet extends StatelessWidget {
  final CaseModel lead;
  final int tab;
  final VoidCallback onAccept;

  const _DetailsSheet({required this.lead, required this.tab, required this.onAccept});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, ctrl) => SingleChildScrollView(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF333333),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(lead.title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 4),
            Text('Client: ${lead.clientName}',
                style: const TextStyle(color: _grey, fontSize: 13)),
            const SizedBox(height: 14),
            const Divider(color: Color(0xFF2A2A2A)),
            const SizedBox(height: 12),
            _row('Category', lead.category),
            _row('Location', lead.location),
            _row('Urgency', lead.urgency),
            _row('Status', lead.status),
            _row('Budget', lead.budgetRange),
            if (lead.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Description',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(height: 6),
              Text(lead.description,
                  style: const TextStyle(color: _grey, fontSize: 13, height: 1.6)),
            ],
            const SizedBox(height: 24),
            if (tab == 0)
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _gold),
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Close', style: TextStyle(color: _gold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              child: Text(label, style: const TextStyle(color: Color(0xFF666666), fontSize: 12)),
            ),
            Expanded(
              child: Text(
                value.isNotEmpty ? value : '—',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      );
}
