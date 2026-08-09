import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'finance_provider.dart';
import 'customer_loan_modules.dart';
import 'customers_view.dart';
import 'collections_view.dart';
import 'reports_view.dart';
import 'navigation_shell.dart';

// ═══════════════════════════════════════════════════════════════
//  DASHBOARD
// ═══════════════════════════════════════════════════════════════

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});
  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // navigate to a named bottom-nav tab by popping to root + index
  void _goTab(BuildContext context, int index) {
    final shell = context.findAncestorStateOfType<NavigationShellState>();
    shell?.goTo(index);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceProvider>(builder: (ctx, fp, _) {
      final s = fp.stats;
      return Scaffold(
        body: RefreshIndicator(
          onRefresh: () => fp.loadAll(),
          color: const Color(0xFF00E5A0),
          backgroundColor: const Color(0xFF141E2E),
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _appBar(ctx, fp),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _heroCard(s),
                        const SizedBox(height: 16),
                        _statsRow(s),
                        const SizedBox(height: 20),
                        _quickActions(ctx),
                        const SizedBox(height: 20),
                        _chart(s),
                        const SizedBox(height: 20),
                        _todaySection(ctx, fp),
                        const SizedBox(height: 20),
                        _overdueSection(ctx, fp),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  // ── APP BAR ────────────────────────────────────────────────

  SliverAppBar _appBar(BuildContext context, FinanceProvider fp) {
    final h = DateTime.now().hour;
    final greeting =
    h < 12 ? 'Good Morning 👋' : h < 17 ? 'Good Afternoon ☀️' : 'Good Evening 🌙';
    return SliverAppBar(
      floating: true,
      snap: true,
      expandedHeight: 64,
      backgroundColor: const Color(0xFF070B14),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        title: Row(children: [

          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Image.asset(
              'assets/logo.png',
              width: 34,
              height: 34,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 34, height: 34,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF00E5A0), Color(0xFF6C63FF)]),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.black, size: 18),
              ),
            ),
          ),

          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Erramala', // 👈 Updated
                    style: TextStyle(
                        color: Color(0xFF00E5A0),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
                Text(greeting,
                    style: const TextStyle(
                        color: Color(0xFF7B8FAD),
                        fontSize: 9,
                        fontWeight: FontWeight.w400),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (fp.overdueInstallments.isNotEmpty)
            GestureDetector(
              onTap: () => _goTab(context, 2),
              child: Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: const Color(0xFF141E2E),
                      borderRadius: BorderRadius.circular(9)),
                  child: const Icon(Icons.notifications_outlined,
                      color: Color(0xFF7B8FAD), size: 18),
                ),
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B6B),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF070B14), width: 1.5),
                    ),
                  ),
                ),
              ]),
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _showSearch(context),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: const Color(0xFF141E2E),
                  borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.search_rounded,
                  color: Color(0xFF7B8FAD), size: 18),
            ),
          ),
        ]),
      ),
    );
  }

  // ── HERO CARD ──────────────────────────────────────────────

  Widget _heroCard(Map<String, dynamic> s) {
    final double todayTotal = (s['todayTotalAmount'] ??
        ((s['todayCollection'] ?? 0.0) + (s['todayDueAmount'] ?? 0.0))) as double;
    final double monthGiven =
    (s['monthDisbursed'] ?? s['monthGiven'] ?? 0.0) as double;
    final double outstanding = (s['outstanding'] ?? 0.0) as double;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D2A20), Color(0xFF131830)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFF00E5A0).withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Today's Total Target",
            style: TextStyle(
                color: Color(0xFF7B8FAD),
                fontSize: 12,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        _AnimCounter(
          value: todayTotal,
          prefix: '₹',
          style: const TextStyle(
              color: Color(0xFF00E5A0),
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -1),
        ),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(children: [
            Expanded(
                child: _HeroStat('Due Today',
                    '${s['todayDue'] ?? 0} acc',
                    const Color(0xFFFFB800))),
            const VerticalDivider(
                color: Color(0xFF1A2540), thickness: 1, width: 20),
            Expanded(
                child: _HeroStat('Outstanding',
                    '₹${_fmtExact(outstanding)}',
                    const Color(0xFFFF6B6B))),
            const VerticalDivider(
                color: Color(0xFF1A2540), thickness: 1, width: 20),
            Expanded(
                child: _HeroStat('This Month Given',
                    '₹${_fmtExact(monthGiven)}',
                    const Color(0xFF6C63FF))),
          ]),
        ),
      ]),
    );
  }

  // ── STATS ROW ──────────────────────────────────────────────

  Widget _statsRow(Map<String, dynamic> s) {
    return Row(children: [
      Expanded(
          child: _SC('Customers',
              '${s['activeCustomers'] ?? 0}',
              Icons.people_alt_rounded,
              const Color(0xFF00E5A0))),
      const SizedBox(width: 10),
      Expanded(
          child: _SC('Active Loans',
              '${s['activeLoans'] ?? 0}',
              Icons.credit_score_rounded,
              const Color(0xFF6C63FF))),
      const SizedBox(width: 10),
      Expanded(
          child: _SC('Overdue',
              '${s['overdueCount'] ?? 0}',
              Icons.warning_rounded,
              const Color(0xFFFF6B6B))),
    ]);
  }

  // ── QUICK ACTIONS ──────────────────────────────────────────

  Widget _quickActions(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SLabel('Quick Actions'),
      const SizedBox(height: 12),
      Row(children: [
        _QA('Add Customer', Icons.person_add_rounded,
            const Color(0xFF00E5A0), () {
              Navigator.push(context, _sr(const AddCustomerScreen()));
            }),
        const SizedBox(width: 8),
        _QA('New Loan', Icons.add_card_rounded,
            const Color(0xFF6C63FF), () {
              _pickCustomerForLoan(context);
            }),
        const SizedBox(width: 8),
        _QA('Collections', Icons.payments_rounded,
            const Color(0xFF4FC3F7), () {
              _goTab(context, 2);
            }),
        const SizedBox(width: 8),
        _QA('Calendar', Icons.calendar_month_rounded,
            const Color(0xFFFFB800), () {
              _goTab(context, 2);
            }),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        _QA('Reports', Icons.bar_chart_rounded,
            const Color(0xFF00E5A0), () {
              _goTab(context, 3);
            }),
        const SizedBox(width: 8),
        _QA('Customers', Icons.people_rounded,
            const Color(0xFF6C63FF), () {
              _goTab(context, 1);
            }),
        const SizedBox(width: 8),
        _QA('Search', Icons.manage_search_rounded,
            const Color(0xFFFF6B6B), () {
              _showSearch(context);
            }),
        const SizedBox(width: 8),
        _QA('Settings', Icons.settings_rounded,
            const Color(0xFF7B8FAD), () {
              _goTab(context, 4);
            }),
      ]),
    ]);
  }

  // ── CHART (SHOWS AMOUNT GIVEN PER MONTH) ───────────────────

  Widget _chart(Map<String, dynamic> s) {
    final series = (s['monthlyDisbursedSeries'] as List<dynamic>?) ??
        (s['monthlySeries'] as List<dynamic>?) ??
        [];
    if (series.isEmpty) return const SizedBox.shrink();
    final maxVal = series.fold(
        0.0,
            (m, e) =>
        (e['amount'] as double) > m ? (e['amount'] as double) : m);
    const months = [
      'J','F','M','A','M','J','J','A','S','O','N','D'
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SLabel('Monthly Disbursed Trend (Amount Given)'),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF141E2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF243050)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: series.map((e) {
            final amt = (e['amount'] as double);
            final pct =
            maxVal > 0 ? (amt / maxVal).clamp(0.02, 1.0) : 0.02;
            final mStr = (e['month'] as String).substring(5);
            final mIdx = (int.tryParse(mStr) ?? 1) - 1;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('₹${_fmtExact(amt)}',
                        style: const TextStyle(
                            color: Color(0xFF7B8FAD), fontSize: 7),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: pct.toDouble()),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => Container(
                        height: 70 * v,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF6C63FF),
                              Color(0xFF00E5A0),
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(months[mIdx.clamp(0, 11)],
                        style: const TextStyle(
                            color: Color(0xFF3D4F6B), fontSize: 9)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ]);
  }

  // ── TODAY DUE ──────────────────────────────────────────────

  Widget _todaySection(BuildContext context, FinanceProvider fp) {
    if (fp.todayInstallments.isEmpty) return const SizedBox.shrink();

    final pendingToday = fp.todayInstallments.where((i) => i.status != 'Paid').toList();
    if (pendingToday.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const _SLabel('Due Today'),
        const Spacer(),
        GestureDetector(
          onTap: () => _goTab(context, 2),
          child: const Text('View all →',
              style: TextStyle(color: Color(0xFF00E5A0), fontSize: 12)),
        ),
      ]),
      const SizedBox(height: 10),
      ...pendingToday
          .take(4)
          .map((i) => _MiniTile(i, fp, const Color(0xFFFFB800))),
    ]);
  }

  // ── OVERDUE ────────────────────────────────────────────────

  Widget _overdueSection(BuildContext context, FinanceProvider fp) {
    if (fp.overdueInstallments.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const _SLabel('Overdue'),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
              color: const Color(0xFFFF6B6B).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8)),
          child: Text('${fp.overdueInstallments.length}',
              style: const TextStyle(
                  color: Color(0xFFFF6B6B),
                  fontWeight: FontWeight.w700,
                  fontSize: 11)),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => _goTab(context, 2),
          child: const Text('View all →',
              style: TextStyle(color: Color(0xFFFF6B6B), fontSize: 12)),
        ),
      ]),
      const SizedBox(height: 10),
      ...fp.overdueInstallments
          .take(3)
          .map((i) => _MiniTile(i, fp, const Color(0xFFFF6B6B))),
    ]);
  }

  // ── HELPERS ────────────────────────────────────────────────

  void _pickCustomerForLoan(BuildContext context) {
    final fp = context.read<FinanceProvider>();
    final customers = fp.customers;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141E2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scroll) => Column(children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFF243050),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Select Customer for New Loan',
                style: TextStyle(
                    color: Color(0xFFEDF2FF),
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
          ),
          if (customers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('No customers yet. Add a customer first.',
                  style: TextStyle(color: Color(0xFF7B8FAD)),
                  textAlign: TextAlign.center),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                itemCount: customers.length,
                itemBuilder: (_, i) {
                  final c = customers[i];
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                          context,
                          _sr(AddLoanScreen(customer: c)));
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2540),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF243050)),
                      ),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor:
                          const Color(0xFF00E5A0).withOpacity(0.15),
                          child: Text(c.initials,
                              style: const TextStyle(
                                  color: Color(0xFF00E5A0),
                                  fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.fullName,
                                    style: const TextStyle(
                                        color: Color(0xFFEDF2FF),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14),
                                    overflow: TextOverflow.ellipsis),
                                Text(c.mobile,
                                    style: const TextStyle(
                                        color: Color(0xFF7B8FAD),
                                        fontSize: 12)),
                              ]),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: Color(0xFF3D4F6B)),
                      ]),
                    ),
                  );
                },
              ),
            ),
        ]),
      ),
    );
  }

  void _showSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141E2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _GlobalSearch(),
    );
  }
}

// ── GLOBAL SEARCH SHEET ────────────────────────────────────────

class _GlobalSearch extends StatefulWidget {
  const _GlobalSearch();
  @override
  State<_GlobalSearch> createState() => _GlobalSearchState();
}

class _GlobalSearchState extends State<_GlobalSearch> {
  final _ctrl = TextEditingController();
  List<Customer> _results = [];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _search(String q) {
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    final fp = context.read<FinanceProvider>();
    final all = fp.customers;
    setState(() {
      _results = all
          .where((c) =>
      c.fullName.toLowerCase().contains(q.toLowerCase()) ||
          c.mobile.contains(q) ||
          (c.village?.toLowerCase().contains(q.toLowerCase()) ?? false) ||
          (c.aadhaar?.contains(q) ?? false))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scroll) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFF243050),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: _search,
              style: const TextStyle(color: Color(0xFFEDF2FF)),
              decoration: InputDecoration(
                hintText: 'Search customer name, mobile, village…',
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Color(0xFF7B8FAD)),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0xFF7B8FAD)),
                    onPressed: () {
                      _ctrl.clear();
                      _search('');
                    })
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _results.isEmpty
                ? Center(
              child: Text(
                _ctrl.text.isEmpty
                    ? 'Start typing to search'
                    : 'No results found',
                style: const TextStyle(color: Color(0xFF7B8FAD)),
              ),
            )
                : ListView.builder(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              itemCount: _results.length,
              itemBuilder: (_, i) {
                final c = _results[i];
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        _sr(CustomerDetailScreen(customer: c)));
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2540),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor:
                        const Color(0xFF00E5A0).withOpacity(0.15),
                        child: Text(c.initials,
                            style: const TextStyle(
                                color: Color(0xFF00E5A0),
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(c.fullName,
                                  style: const TextStyle(
                                      color: Color(0xFFEDF2FF),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14),
                                  overflow: TextOverflow.ellipsis),
                              Text(c.mobile,
                                  style: const TextStyle(
                                      color: Color(0xFF7B8FAD),
                                      fontSize: 12)),
                            ]),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: Color(0xFF3D4F6B), size: 18),
                    ]),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ── SHARED WIDGETS ────────────────────────────────────────────

class _SLabel extends StatelessWidget {
  final String text;
  const _SLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: Color(0xFFEDF2FF),
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3));
}

class _HeroStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _HeroStat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(value,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 13),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      const SizedBox(height: 2),
      Text(label,
          style: const TextStyle(
              color: Color(0xFF7B8FAD), fontSize: 9),
          textAlign: TextAlign.center,
          maxLines: 1),
    ],
  );
}

class _SC extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _SC(this.label, this.value, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF141E2E),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.15)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(height: 8),
      Text(value,
          style: TextStyle(
              color: color, fontSize: 20, fontWeight: FontWeight.w800)),
      Text(label,
          style: const TextStyle(
              color: Color(0xFF7B8FAD), fontSize: 10),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
    ]),
  );
}

class _QA extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QA(this.label, this.icon, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    ),
  );
}

class _MiniTile extends StatelessWidget {
  final Installment inst;
  final FinanceProvider fp;
  final Color color;
  const _MiniTile(this.inst, this.fp, this.color);
  @override
  Widget build(BuildContext context) {
    final c = fp.customerById(inst.customerId);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFF141E2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15))),
      child: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color.withOpacity(0.15),
          child: Text(c?.initials ?? '?',
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c?.fullName ?? 'Unknown',
                style: const TextStyle(
                    color: Color(0xFFEDF2FF),
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
            Text('Inst #${inst.installmentNumber} • ${inst.dueDate}',
                style: const TextStyle(
                    color: Color(0xFF7B8FAD), fontSize: 11)),
          ]),
        ),
        Text('₹${_fmtExact(inst.remainingAmount)}',
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 14)),
      ]),
    );
  }
}

class _AnimCounter extends StatefulWidget {
  final double value;
  final String prefix;
  final TextStyle style;
  const _AnimCounter(
      {required this.value, this.prefix = '', required this.style});
  @override
  State<_AnimCounter> createState() => _AnimCounterState();
}

class _AnimCounterState extends State<_AnimCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _a = Tween(begin: 0.0, end: widget.value)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _c.forward();
  }

  @override
  void didUpdateWidget(_AnimCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _a = Tween(begin: _a.value, end: widget.value)
          .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) => Text(
          '${widget.prefix}${_fmtExact(_a.value)}',
          style: widget.style),
    );
  }
}

// ── UTILS ─────────────────────────────────────────────────────

String _fmtExact(double v) {
  final str = v.toStringAsFixed(0);
  if (str.length <= 3) return str;
  final lastThree = str.substring(str.length - 3);
  final rest = str.substring(0, str.length - 3);
  final RegExp reg = RegExp(r'\B(?=(\d{2})+(?!\d))');
  return '${rest.replaceAll(reg, ',')},$lastThree';
}

Route _sr(Widget page) => PageRouteBuilder(
  pageBuilder: (_, a, __) => page,
  transitionsBuilder: (_, a, __, child) => SlideTransition(
    position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
    child: child,
  ),
  transitionDuration: const Duration(milliseconds: 320),
);