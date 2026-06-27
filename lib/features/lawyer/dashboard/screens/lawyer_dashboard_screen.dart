import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../routes/route_names.dart';

// ─── COLORS ──────────────────────────────────────────────────
const Color _navy = Color(0xFF0B1F3A);
const Color _navyL = Color(0xFF142D52);
const Color _gold = Color(0xFFD4AF37);
const Color _bg = Color(0xFFF5F7FB);
const Color _green = Color(0xFF2ECC71);
const Color _orange = Color(0xFFF39C12);
const Color _blue = Color(0xFF4A90E2);
const Color _purple = Color(0xFF8E44AD);
const Color _td = Color(0xFF1A1A2E);
const Color _tm = Color(0xFF6B7280);
const Color _bdr = Color(0xFFE8ECF0);

final lawyerTabProvider = StateProvider<int>((ref) => 0);

class LawyerDashboardScreen extends ConsumerStatefulWidget {
  const LawyerDashboardScreen({super.key});
  @override
  ConsumerState<LawyerDashboardScreen> createState() => _LawyerDashboardScreenState();
}

class _LawyerDashboardScreenState extends ConsumerState<LawyerDashboardScreen> {
  final List<bool> _checks = [false, false, false];

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final name = auth.userName ?? "Rahul Sharma";
    final email = auth.userEmail ?? "rahul@casemitra.com";
    final tab = ref.watch(lawyerTabProvider);

    return Scaffold(
      backgroundColor: _bg,
      drawer: _drawer(name, email),
      body: PopScope(
        canPop: false,
        child: Column(
          children: [
            _appBar(name),
            Expanded(
              child: tab == 0 ? _dashboard() : _placeholder(tab),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _bottomNav(tab),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // APP BAR
  // ═══════════════════════════════════════════════════════════
  Widget _appBar(String name) {
    final h = DateTime.now().hour;
    final g = h < 12 ? "Good morning," : (h < 17 ? "Good afternoon," : "Good evening,");
    return Container(
      color: _navy,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 6, left: 8, right: 8, bottom: 10),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.menu, color: Colors.white, size: 24), onPressed: () => Scaffold.of(context).openDrawer()),
          const SizedBox(width: 4),
          const CircleAvatar(radius: 18, backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white, size: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(g, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                Row(children: [
                  Flexible(child: Text("Adv. $name", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 4),
                  const Icon(Icons.verified, color: _blue, size: 14),
                ]),
              ],
            ),
          ),
          Stack(children: [
            IconButton(icon: const Icon(Icons.notifications_none, color: Colors.white, size: 22), onPressed: () {}, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36)),
            Positioned(top: 2, right: 2, child: Container(padding: const EdgeInsets.all(3), decoration: const BoxDecoration(color: _orange, shape: BoxShape.circle), child: const Text("3", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)))),
          ]),
          IconButton(icon: const Icon(Icons.settings, color: Colors.white, size: 22), onPressed: () {}, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DASHBOARD BODY
  // ═══════════════════════════════════════════════════════════
  Widget _dashboard() {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        _overviewCard(),
        const SizedBox(height: 18),
        _statsRow(),
        const SizedBox(height: 18),
        _appointmentsSection(),
        const SizedBox(height: 18),
        _hearingsSection(),
        const SizedBox(height: 18),
        _quickActions(),
        const SizedBox(height: 18),
        _tasksCard(),
        const SizedBox(height: 18),
        _revenueCard(),
        const SizedBox(height: 18),
        _logoutButton(),
        const SizedBox(height: 30),
      ],
    );
  }

  // ─── 1. OVERVIEW CARD ─────────────────────────────────────
  Widget _overviewCard() {
    final now = DateTime.now();
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final mons = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final d = "${days[now.weekday - 1]}, ${now.day} ${mons[now.month - 1]} ${now.year}";
    final hr = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final t = "${hr.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}";

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_navy, _navyL], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: _navy.withAlpha(50), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Today's Overview", style: TextStyle(color: _gold, fontSize: 14, fontWeight: FontWeight.bold)),
              SizedBox(
                height: 30,
                child: ElevatedButton.icon(
                  onPressed: () => ref.read(lawyerTabProvider.notifier).state = 3,
                  icon: const Icon(Icons.calendar_today, size: 12),
                  label: const Text("View Calendar", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: _gold, foregroundColor: _navy, padding: const EdgeInsets.symmetric(horizontal: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.calendar_month, color: Colors.white54, size: 12),
            const SizedBox(width: 4),
            Text(d, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(width: 14),
            const Icon(Icons.access_time, color: Colors.white54, size: 12),
            const SizedBox(width: 4),
            Text(t, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            _ovItem(Icons.work_outline, "12", "Cases\nToday", _blue),
            Container(width: 1, height: 40, color: Colors.white12),
            _ovItem(Icons.event_available, "06", "Appoint-\nments", _green),
            Container(width: 1, height: 40, color: Colors.white12),
            _ovItem(Icons.gavel, "02", "Hear-\nings", _orange),
            Container(width: 1, height: 40, color: Colors.white12),
            _ovItem(Icons.assignment, "05", "Tasks\nPending", _purple),
          ]),
        ],
      ),
    );
  }

  Widget _ovItem(IconData ic, String v, String l, Color c) {
    return Expanded(child: Column(children: [
      Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: c.withAlpha(35), shape: BoxShape.circle), child: Icon(ic, color: c, size: 16)),
      const SizedBox(height: 6),
      Text(v, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(l, style: const TextStyle(color: Colors.white54, fontSize: 9), textAlign: TextAlign.center),
    ]));
  }

  // ─── 2. STATISTICS ROW ────────────────────────────────────
  Widget _statsRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("Statistics", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _td)),
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Text("This Month", style: TextStyle(fontSize: 11, color: _tm)),
            const Icon(Icons.keyboard_arrow_down, size: 14, color: _tm),
          ]),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 80,
          child: ListView(scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), children: [
            _sCard(Icons.work_outline, "28", "Active Cases", "↑ 12%", _blue, _green),
            const SizedBox(width: 10),
            _sCard(Icons.people_outline, "48", "Clients", "↑ 18%", _green, _green),
            const SizedBox(width: 10),
            _sCard(Icons.event_available, "26", "Appointments", "↑ 8%", _orange, _green),
            const SizedBox(width: 10),
            _sCard(Icons.payments_outlined, "₹1,48,500", "Pending", "↓ 5%", _purple, Colors.red),
          ]),
        ),
      ],
    );
  }

  Widget _sCard(IconData ic, String v, String title, String trend, Color c, Color tc) {
    return Container(
      width: 130, padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: c.withAlpha(25), shape: BoxShape.circle), child: Icon(ic, color: c, size: 14)),
          const SizedBox(width: 6),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _td), overflow: TextOverflow.ellipsis)),
        ]),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(child: Text(title, style: const TextStyle(fontSize: 9, color: _tm), overflow: TextOverflow.ellipsis)),
          Text(trend, style: TextStyle(fontSize: 9, color: tc, fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }

  // ─── 3. APPOINTMENTS ──────────────────────────────────────
  Widget _appointmentsSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Today's Appointments", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _td)),
      const SizedBox(height: 10),
      _apptCard("Priya Mehta", "Divorce Case", "11:00 AM", "Online Meeting", "Confirmed", "Start Meeting"),
      const SizedBox(height: 8),
      _apptCard("Amit Verma", "Cheque Bounce Case", "03:30 PM", "Chamber", "Confirmed", "View Details"),
      const SizedBox(height: 8),
      _vAllBtn("View All Appointments"),
    ]);
  }

  Widget _apptCard(String name, String caseType, String time, String mode, String status, String btn) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Column(children: [
        Row(children: [
          CircleAvatar(radius: 18, backgroundColor: _navy.withAlpha(18), child: const Icon(Icons.person, color: _navy, size: 20)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _td)),
            Text(caseType, style: const TextStyle(fontSize: 11, color: _tm)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _green.withAlpha(20), borderRadius: BorderRadius.circular(10)),
            child: Text(status, style: const TextStyle(fontSize: 9, color: _green, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.more_horiz, size: 16, color: _tm),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.access_time, size: 12, color: _tm), const SizedBox(width: 3),
          Text(time, style: const TextStyle(fontSize: 10, color: _tm)),
          const SizedBox(width: 8),
          Container(width: 1, height: 12, color: _bdr),
          const SizedBox(width: 8),
          const Icon(Icons.videocam_outlined, size: 12, color: _tm), const SizedBox(width: 3),
          Flexible(child: Text(mode, style: const TextStyle(fontSize: 10, color: _tm))),
          const Spacer(),
          SizedBox(height: 26, child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), elevation: 0, textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            child: Text(btn),
          )),
        ]),
      ]),
    );
  }

  // ─── 4. HEARINGS ──────────────────────────────────────────
  Widget _hearingsSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Upcoming Hearings", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _td)),
      const SizedBox(height: 10),
      _hItem("State vs Ramesh Kumar", "Criminal Case No. 245/2024", "20 May 2025, 10:30 AM", "High Court, Delhi", false),
      _hItem("Sunita vs Rajesh Sharma", "Civil Case No. 567/2024", "22 May 2025, 02:00 PM", "District Court, Delhi", false),
      _hItem("ICICI Bank vs Mohan Lal", "Recovery Case No. 891/2024", "24 May 2025, 11:00 AM", "Debt Recovery Tribunal", true),
      _vAllBtn("View All Hearings"),
    ]);
  }

  Widget _hItem(String title, String caseNo, String date, String court, bool isLast) {
    return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 20, child: Column(children: [
        Container(margin: const EdgeInsets.only(top: 4), width: 8, height: 8, decoration: const BoxDecoration(color: _orange, shape: BoxShape.circle)),
        if (!isLast) Expanded(child: Container(width: 1.5, color: _orange.withAlpha(35))),
      ])),
      Expanded(child: Container(
        margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 6, offset: const Offset(0, 2))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Flexible(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _td))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _orange.withAlpha(18), borderRadius: BorderRadius.circular(6)), child: const Text("Upcoming", style: TextStyle(color: _orange, fontSize: 8, fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 3),
          Text(caseNo, style: const TextStyle(fontSize: 10, color: _tm)),
          const SizedBox(height: 4),
          Row(children: [const Icon(Icons.calendar_today, size: 10, color: _tm), const SizedBox(width: 3), Text(date, style: const TextStyle(fontSize: 9, color: _tm))]),
          const SizedBox(height: 2),
          Row(children: [const Icon(Icons.location_on_outlined, size: 10, color: _tm), const SizedBox(width: 3), Flexible(child: Text(court, style: const TextStyle(fontSize: 9, color: _tm)))]),
        ]),
      )),
    ]));
  }

  // ─── 5. QUICK ACTIONS ─────────────────────────────────────
  Widget _quickActions() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Quick Actions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _td)),
      const SizedBox(height: 10),
      SizedBox(
        height: 76,
        child: ListView(scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), children: [
          _qaItem(Icons.note_add_outlined, "New Case", _blue),
          _qaItem(Icons.person_add_outlined, "Add Client", _green),
          _qaItem(Icons.calendar_today_outlined, "Calendar", _orange),
          _qaItem(Icons.description_outlined, "Documents", _purple),
          _qaItem(Icons.chat_bubble_outline, "Messages", _blue),
          _qaItem(Icons.payments_outlined, "Payments", _green),
          _qaItem(Icons.bar_chart_outlined, "Reports", _orange),
          _qaItem(Icons.grid_view_rounded, "More", _navy),
        ]),
      ),
    ]);
  }

  Widget _qaItem(IconData ic, String label, Color c) {
    return Container(
      width: 68, margin: const EdgeInsets.only(right: 10),
      child: Material(
        color: Colors.white, borderRadius: BorderRadius.circular(14), elevation: 0.5,
        child: InkWell(borderRadius: BorderRadius.circular(14), onTap: () {},
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: c.withAlpha(18), borderRadius: BorderRadius.circular(10)), child: Icon(ic, color: c, size: 18)),
            const SizedBox(height: 5),
            Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: _td), textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }

  // ─── 6. TASKS ─────────────────────────────────────────────
  Widget _tasksCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Pending Tasks", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _td)),
        const SizedBox(height: 10),
        _tRow("File reply in Sharma case", "Due Today", Colors.red, 0),
        const SizedBox(height: 6),
        _tRow("Review documents - Mehta case", "Due Tomorrow", _orange, 1),
        const SizedBox(height: 6),
        _tRow("Prepare for hearing - 20 May", "Due In 2 Days", _blue, 2),
        const SizedBox(height: 8),
        _vAllBtn("View All Tasks"),
      ]),
    );
  }

  Widget _tRow(String title, String due, Color dc, int idx) {
    return Row(children: [
      SizedBox(width: 20, height: 20, child: Checkbox(
        value: _checks[idx],
        onChanged: (v) => setState(() => _checks[idx] = v ?? false),
        activeColor: _navy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        side: const BorderSide(color: _bdr, width: 1.5),
      )),
      const SizedBox(width: 8),
      Expanded(child: Text(title, style: TextStyle(fontSize: 11, color: _checks[idx] ? _tm : _td, decoration: _checks[idx] ? TextDecoration.lineThrough : null))),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: dc.withAlpha(15), borderRadius: BorderRadius.circular(6)),
        child: Text(due, style: TextStyle(fontSize: 8, color: dc, fontWeight: FontWeight.bold)),
      ),
    ]);
  }

  // ─── 7. REVENUE ───────────────────────────────────────────
  Widget _revenueCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("Revenue Summary", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _td)),
          Row(mainAxisSize: MainAxisSize.min, children: [const Text("This Month", style: TextStyle(fontSize: 10, color: _tm)), const Icon(Icons.keyboard_arrow_down, size: 12, color: _tm)]),
        ]),
        const SizedBox(height: 4),
        const Text("Total Earnings", style: TextStyle(fontSize: 10, color: _tm)),
        const Text("₹2,48,500", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _td)),
        const SizedBox(height: 10),
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Container(width: 7, height: 7, decoration: const BoxDecoration(color: _green, shape: BoxShape.circle)), const SizedBox(width: 4), const Text("Paid", style: TextStyle(fontSize: 10, color: _tm))]),
            const Text("₹1,80,000", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _green)),
            const SizedBox(height: 6),
            Row(children: [Container(width: 7, height: 7, decoration: const BoxDecoration(color: _orange, shape: BoxShape.circle)), const SizedBox(width: 4), const Text("Pending", style: TextStyle(fontSize: 10, color: _tm))]),
            const Text("₹68,500", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _orange)),
          ]),
          const Spacer(),
          SizedBox(width: 70, height: 70, child: CustomPaint(
            painter: _ChartPainter(),
            child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text("72%", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _green)),
              Text("Received", style: TextStyle(fontSize: 7, color: _tm)),
            ])),
          )),
        ]),
        const SizedBox(height: 8),
        _vAllBtn("View Detailed Report"),
      ]),
    );
  }

  // ─── 8. LOGOUT ────────────────────────────────────────────
  Widget _logoutButton() {
    return SizedBox(
      width: double.infinity, height: 48,
      child: ElevatedButton.icon(
        onPressed: () => _doLogout(),
        icon: const Icon(Icons.logout, size: 18, color: Colors.white),
        label: const Text("Logout", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 2),
      ),
    );
  }

  // ─── VIEW ALL ─────────────────────────────────────────────
  Widget _vAllBtn(String label) {
    return Align(alignment: Alignment.centerRight, child: TextButton.icon(
      onPressed: () {}, style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 28)),
      icon: Text(label, style: const TextStyle(fontSize: 11, color: _navy, fontWeight: FontWeight.w600)),
      label: const Icon(Icons.arrow_forward, size: 12, color: _navy),
    ));
  }

  // ─── PLACEHOLDER ──────────────────────────────────────────
  Widget _placeholder(int tab) {
    final labels = ['Dashboard', 'Cases', 'Clients', 'Calendar', 'Profile'];
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _navy.withAlpha(12), shape: BoxShape.circle), child: const Icon(Icons.construction_outlined, size: 40, color: _navy)),
      const SizedBox(height: 14),
      Text(labels[tab], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _navy)),
      const SizedBox(height: 4),
      const Text("Coming Soon", style: TextStyle(fontSize: 13, color: _tm)),
    ]));
  }

  // ═══════════════════════════════════════════════════════════
  // BOTTOM NAV
  // ═══════════════════════════════════════════════════════════
  Widget _bottomNav(int sel) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, -2))]),
      child: SafeArea(top: false, child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _navItem(Icons.dashboard_outlined, Icons.dashboard, "Dashboard", 0, sel),
          _navItem(Icons.folder_open_outlined, Icons.folder, "Cases", 1, sel),
          _navItem(Icons.people_outline, Icons.people, "Clients", 2, sel),
          _navItem(Icons.calendar_today_outlined, Icons.calendar_today, "Calendar", 3, sel),
          _navItem(Icons.person_outline, Icons.person, "Profile", 4, sel),
        ]),
      )),
    );
  }

  Widget _navItem(IconData ic, IconData aic, String l, int i, int sel) {
    final s = sel == i;
    return InkWell(
      onTap: () => ref.read(lawyerTabProvider.notifier).state = i,
      borderRadius: BorderRadius.circular(10),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(s ? aic : ic, color: s ? _navy : _tm, size: 20),
        const SizedBox(height: 2),
        Text(l, style: TextStyle(fontSize: 9, fontWeight: s ? FontWeight.bold : FontWeight.normal, color: s ? _navy : _tm)),
        AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.only(top: 2), width: s ? 14 : 0, height: 2, decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(1))),
      ])),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DRAWER
  // ═══════════════════════════════════════════════════════════
  Widget _drawer(String name, String email) {
    return Drawer(backgroundColor: _bg, child: Column(children: [
      Container(
        width: double.infinity,
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16, left: 20, right: 20, bottom: 16),
        decoration: const BoxDecoration(color: _navy, borderRadius: BorderRadius.only(bottomRight: Radius.circular(24))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const CircleAvatar(radius: 26, backgroundColor: Colors.white24, child: Icon(Icons.person, size: 30, color: Colors.white)),
          const SizedBox(height: 10),
          Row(children: [Text("Adv. $name", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(width: 4), const Icon(Icons.verified, color: _blue, size: 14)]),
          const SizedBox(height: 2),
          Text(email, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
      ),
      Expanded(child: ListView(padding: const EdgeInsets.symmetric(vertical: 6), children: [
        _dTile(Icons.dashboard_outlined, "Dashboard"),
        _dTile(Icons.folder_outlined, "Cases"),
        _dTile(Icons.people_outline, "Clients"),
        _dTile(Icons.event_outlined, "Appointments"),
        _dTile(Icons.calendar_today_outlined, "Calendar"),
        _dTile(Icons.description_outlined, "Documents"),
        _dTile(Icons.chat_bubble_outline, "Messages"),
        _dTile(Icons.payments_outlined, "Payments"),
        _dTile(Icons.analytics_outlined, "Analytics"),
        const Divider(indent: 16, endIndent: 16, height: 20),
        _dTile(Icons.settings_outlined, "Settings"),
        _dTile(Icons.help_outline, "Help"),
        _dTile(Icons.privacy_tip_outlined, "Privacy Policy"),
        _dTile(Icons.gavel_outlined, "Terms & Conditions"),
        _dTile(Icons.info_outline, "About"),
      ])),
      SafeArea(top: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: SizedBox(width: double.infinity, height: 44, child: ElevatedButton.icon(
          onPressed: () { Navigator.pop(context); _doLogout(); },
          icon: const Icon(Icons.logout, color: Colors.white, size: 16),
          label: const Text("Logout", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        )),
      )),
    ]));
  }

  Widget _dTile(IconData ic, String l) {
    return ListTile(leading: Icon(ic, color: _tm, size: 20), title: Text(l, style: const TextStyle(fontSize: 13, color: _td)), contentPadding: const EdgeInsets.symmetric(horizontal: 20), dense: true, onTap: () {});
  }

  // ═══════════════════════════════════════════════════════════
  // LOGOUT LOGIC
  // ═══════════════════════════════════════════════════════════
  Future<void> _doLogout() async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text("Logout", style: TextStyle(fontWeight: FontWeight.bold)),
      content: const Text("Are you sure you want to logout?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text("Logout")),
      ],
    ));
    if (ok != true || !mounted) return;
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authProvider.notifier).logout();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (_) {}
    messenger.showSnackBar(const SnackBar(content: Text("Logged out successfully"), backgroundColor: _green));
    router.go(RouteNames.login);
  }
}

// ─── CHART PAINTER ───────────────────────────────────────────
class _ChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 5;
    canvas.drawCircle(c, r, Paint()..color = _bdr..style = PaintingStyle.stroke..strokeWidth = 7..strokeCap = StrokeCap.round);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -pi / 2, 2 * pi * 0.72, false, Paint()..color = _green..style = PaintingStyle.stroke..strokeWidth = 7..strokeCap = StrokeCap.round);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -pi / 2 + 2 * pi * 0.72, 2 * pi * 0.28, false, Paint()..color = _orange..style = PaintingStyle.stroke..strokeWidth = 7..strokeCap = StrokeCap.round);
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
