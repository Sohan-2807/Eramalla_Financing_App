import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'finance_provider.dart';
import 'customer_loan_modules.dart';
import 'database_helper.dart';

// ═══════════════════════════════════════════════════════════════
//  COLLECTIONS ROOT
// ═══════════════════════════════════════════════════════════════

class CollectionsView extends StatefulWidget {
  const CollectionsView({super.key});
  @override
  State<CollectionsView> createState() => _CollectionsViewState();
}

class _CollectionsViewState extends State<CollectionsView>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceProvider>(builder: (ctx, fp, _) {
      final todayCount   = fp.todayInstallments.where((i) => i.status != 'Paid').length;
      final overdueCount = fp.overdueInstallments.length;

      return Scaffold(
        appBar: AppBar(
          title: const Text('Collections'),
          bottom: TabBar(
            controller: _tab,
            labelColor: const Color(0xFF00E5A0),
            unselectedLabelColor: const Color(0xFF7B8FAD),
            indicatorColor: const Color(0xFF00E5A0),
            tabs: [
              Tab(child: _TabLabel('Today', todayCount, const Color(0xFF00E5A0))),
              const Tab(text: 'Calendar'),
              Tab(child: _TabLabel('Overdue', overdueCount, const Color(0xFFFF6B6B))),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tab,
          children: [
            _TodayTab(fp: fp),
            const _CalendarTab(),
            _OverdueTab(fp: fp),
          ],
        ),
      );
    });
  }
}

class _TabLabel extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _TabLabel(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label),
      if (count > 0) ...[
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: color.withOpacity(0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w700)),
        ),
      ],
    ],
  );
}

// ═══════════════════════════════════════════════════════════════
//  TODAY TAB
// ═══════════════════════════════════════════════════════════════

class _TodayTab extends StatelessWidget {
  final FinanceProvider fp;
  const _TodayTab({required this.fp});

  @override
  Widget build(BuildContext context) {
    final list      = fp.todayInstallments;
    final expected  = list.fold(0.0, (s, i) => s + i.amount);
    final collected = list.fold(0.0, (s, i) => s + i.paidAmount);
    final paid      = list.where((i) => i.status == 'Paid').length;
    final pending   = list.where((i) => i.status != 'Paid').length;

    return Column(children: [
      _SummaryBar(
          expected: expected,
          collected: collected,
          total: list.length,
          paid: paid,
          pending: pending),

      // Success Banner when everything is paid!
      if (list.isNotEmpty && pending == 0)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: const Color(0xFF00E5A0).withOpacity(0.1),
          width: double.infinity,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_rounded, color: Color(0xFF00E5A0), size: 18),
              SizedBox(width: 8),
              Text('All collections done for today 🎉', style: TextStyle(color: Color(0xFF00E5A0), fontWeight: FontWeight.w600)),
            ],
          ),
        ),

      Expanded(
        child: list.isEmpty
            ? const _EmptyMsg(
            icon: Icons.event_busy_rounded,
            msg: 'No collections scheduled for today')
            : RefreshIndicator(
          color: const Color(0xFF00E5A0),
          onRefresh: () => fp.loadAll(),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: list.length,
            itemBuilder: (_, i) => _CollCard(
              inst: list[i],
              fp: fp,
              onDone: fp.loadAll,
            ),
          ),
        ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════
//  CALENDAR TAB
// ═══════════════════════════════════════════════════════════════

class _CalendarTab extends StatefulWidget {
  const _CalendarTab();
  @override
  State<_CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<_CalendarTab> {
  DateTime _month   = DateTime.now();
  DateTime _selected = DateTime.now();
  List<Installment> _dayInsts = [];
  bool _loadingDay  = false;
  final Map<String, int> _counts = {}; // dateStr → count of UNPAID
  bool _loadingMonth = false;

  @override
  void initState() {
    super.initState();
    _loadDay(_selected);
    _loadMonthCounts();
  }

  Future<void> _loadDay(DateTime d) async {
    setState(() => _loadingDay = true);
    final fp = context.read<FinanceProvider>();
    final insts = await fp.installmentsForDate(d);
    if (mounted) setState(() { _dayInsts = insts; _loadingDay = false; });
  }

  Future<void> _loadMonthCounts() async {
    setState(() => _loadingMonth = true);
    final db = DatabaseHelper.instance;
    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    final newCounts   = <String, int>{};

    for (int d = 1; d <= daysInMonth; d++) {
      final date    = DateTime(_month.year, _month.month, d);
      final dateStr = date.toIso8601String().substring(0, 10);
      final insts   = await db.getInstallmentsByDate(dateStr);

      final unpaidCount = insts.where((i) => i.status != 'Paid').length;
      if (unpaidCount > 0) {
        newCounts[dateStr] = unpaidCount;
      }
    }

    if (mounted) {
      setState(() {
        _counts.clear();
        _counts.addAll(newCounts);
        _loadingMonth = false;
      });
    }
  }

  void _prevMonth() {
    setState(() => _month = DateTime(_month.year, _month.month - 1));
    _loadMonthCounts();
  }

  void _nextMonth() {
    setState(() => _month = DateTime(_month.year, _month.month + 1));
    _loadMonthCounts();
  }

  @override
  Widget build(BuildContext context) {
    final fp        = context.read<FinanceProvider>();
    final expected  = _dayInsts.fold(0.0, (s, i) => s + i.amount);
    final collected = _dayInsts.fold(0.0, (s, i) => s + i.paidAmount);

    return Column(children: [
      _Calendar(
        month: _month,
        selected: _selected,
        counts: _counts,
        onPrev: _prevMonth,
        onNext: _nextMonth,
        onToday: () {
          setState(() {
            _month    = DateTime.now();
            _selected = DateTime.now();
          });
          _loadDay(DateTime.now());
          _loadMonthCounts();
        },
        onDay: (d) {
          setState(() => _selected = d);
          _loadDay(d);
        },
      ),
      // Day summary strip
      Container(
        color: const Color(0xFF0F1621),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          _Pill2('Due',       '${_dayInsts.length}',                 const Color(0xFF7B8FAD)),
          const SizedBox(width: 8),
          _Pill2('Expected',  '₹${_fmtExact(expected)}',                const Color(0xFFFFB800)),
          const SizedBox(width: 8),
          _Pill2('Collected', '₹${_fmtExact(collected)}',               const Color(0xFF00E5A0)),
          const SizedBox(width: 8),
          _Pill2('Remaining', '₹${_fmtExact(expected - collected)}',    const Color(0xFFFF6B6B)),
        ]),
      ),
      Expanded(
        child: _loadingDay
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5A0)))
            : _dayInsts.isEmpty
            ? _EmptyMsg(
            icon: Icons.event_available_rounded,
            msg: 'No collections on ${_selected.toIso8601String().substring(0, 10)}')
            : ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: _dayInsts.length,
          itemBuilder: (_, i) => _CollCard(
            inst: _dayInsts[i],
            fp: fp,
            onDone: () async {
              await _loadDay(_selected);
              await _loadMonthCounts();
            },
          ),
        ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════
//  OVERDUE TAB
// ═══════════════════════════════════════════════════════════════

class _OverdueTab extends StatelessWidget {
  final FinanceProvider fp;
  const _OverdueTab({required this.fp});

  @override
  Widget build(BuildContext context) {
    final list    = fp.overdueInstallments;
    final totalDue = list.fold(0.0, (s, i) => s + i.remainingAmount);

    return Column(children: [
      if (list.isNotEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFFFF6B6B).withOpacity(0.08),
          child: Row(children: [
            const Icon(Icons.warning_rounded, color: Color(0xFFFF6B6B), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${list.length} overdue  •  Total: ₹${_fmtExact(totalDue)}',
                style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 13),
              ),
            ),
          ]),
        ),
      Expanded(
        child: list.isEmpty
            ? const _EmptyMsg(
            icon: Icons.verified_rounded,
            msg: 'No overdue installments 🎉')
            : RefreshIndicator(
          color: const Color(0xFF00E5A0),
          onRefresh: () => fp.loadAll(),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: list.length,
            itemBuilder: (_, i) => _CollCard(
              inst: list[i],
              fp: fp,
              isOverdue: true,
              onDone: fp.loadAll,
            ),
          ),
        ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════
//  CALENDAR WIDGET
// ═══════════════════════════════════════════════════════════════

class _Calendar extends StatelessWidget {
  final DateTime month, selected;
  final Map<String, int> counts;
  final VoidCallback onPrev, onNext, onToday;
  final ValueChanged<DateTime> onDay;

  const _Calendar({
    required this.month,
    required this.selected,
    required this.counts,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onDay,
  });

  static const _months = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December'
  ];
  static const _dow = ['Su','Mo','Tu','We','Th','Fr','Sa'];

  @override
  Widget build(BuildContext context) {
    final now  = DateTime.now();
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final off  = DateTime(month.year, month.month, 1).weekday % 7;

    return Container(
      color: const Color(0xFF0F1621),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Column(children: [
        // Nav row
        Row(children: [
          _CBtn(Icons.chevron_left_rounded, onPrev),
          Expanded(
            child: Text('${_months[month.month - 1]} ${month.year}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFFEDF2FF),
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
          ),
          _CBtn(Icons.today_rounded, onToday),
          _CBtn(Icons.chevron_right_rounded, onNext),
        ]),
        const SizedBox(height: 6),
        // DOW headers
        Row(
          children: _dow.map((d) => Expanded(
            child: Text(d,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF3D4F6B), fontSize: 11, fontWeight: FontWeight.w600)),
          )).toList(),
        ),
        const SizedBox(height: 4),
        // Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, mainAxisSpacing: 2, crossAxisSpacing: 2, childAspectRatio: 1.0),
          itemCount: off + days,
          itemBuilder: (_, idx) {
            if (idx < off) return const SizedBox.shrink();
            final day     = idx - off + 1;
            final date    = DateTime(month.year, month.month, day);
            final dateStr = date.toIso8601String().substring(0, 10);
            final isToday = DateUtils.isSameDay(date, now);
            final isSel   = DateUtils.isSameDay(date, selected);
            final cnt     = counts[dateStr];

            return GestureDetector(
              onTap: () => onDay(date),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                margin: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: isSel
                      ? const Color(0xFF00E5A0)
                      : isToday
                      ? const Color(0xFF00E5A0).withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$day',
                        style: TextStyle(
                            color: isSel
                                ? Colors.black
                                : isToday
                                ? const Color(0xFF00E5A0)
                                : const Color(0xFF7B8FAD),
                            fontWeight: isSel || isToday
                                ? FontWeight.w700
                                : FontWeight.w400,
                            fontSize: 13)),
                    if (cnt != null && cnt > 0)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        width: 16,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isSel
                              ? Colors.black.withOpacity(0.25)
                              : const Color(0xFF00E5A0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.center,
                        child: Text('$cnt',
                            style: TextStyle(
                                color: isSel ? Colors.black : Colors.black,
                                fontSize: 5,
                                fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ]),
    );
  }
}

class _CBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CBtn(this.icon, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32, height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: const Color(0xFF141E2E),
          borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: const Color(0xFF7B8FAD), size: 18),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════
//  COLLECTION CARD
// ═══════════════════════════════════════════════════════════════

class _CollCard extends StatelessWidget {
  final Installment inst;
  final FinanceProvider fp;
  final bool isOverdue;
  final Future<void> Function() onDone;

  const _CollCard({
    required this.inst,
    required this.fp,
    this.isOverdue = false,
    required this.onDone,
  });

  Color get _col {
    switch (inst.effectiveStatus) {
      case 'Paid':    return const Color(0xFF00E5A0);
      case 'Overdue': return const Color(0xFFFF6B6B);
      default:        return const Color(0xFF7B8FAD);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = fp.customerById(inst.customerId);
    final col      = _col;
    final isPaid   = inst.status == 'Paid';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: col.withOpacity(0.22)),
      ),
      child: Column(children: [
        // ── Main info row ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: col.withOpacity(0.15),
              child: Text(customer?.initials ?? '?',
                  style: TextStyle(
                      color: col, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(customer?.fullName ?? 'Unknown Customer',
                    style: const TextStyle(
                        color: Color(0xFFEDF2FF),
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(customer?.mobile ?? '—',
                    style: const TextStyle(
                        color: Color(0xFF7B8FAD), fontSize: 12)),
                const SizedBox(height: 4),
                Row(children: [
                  _Tag('Inst #${inst.installmentNumber}', const Color(0xFF6C63FF)),
                  const SizedBox(width: 6),
                  _Tag(inst.dueDate,
                      isOverdue ? const Color(0xFFFF6B6B) : const Color(0xFF7B8FAD)),
                ]),
              ]),
            ),
            // Amount + status
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₹${_fmtExact(inst.amount)}',
                  style: TextStyle(
                      color: col, fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: col.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6)),
                child: Row(
                  children: [
                    if(isPaid) ...[
                      Icon(Icons.check_circle_rounded, color: col, size: 10),
                      const SizedBox(width: 4),
                    ],
                    Text(inst.effectiveStatus,
                        style: TextStyle(
                            color: col, fontSize: 10, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ]),
          ]),
        ),

        // ── Action buttons (only when not paid) ────────────
        if (!isPaid)
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: col.withOpacity(0.1))),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(children: [
              // CALL
              _ActionBtn(
                icon: Icons.call_rounded,
                label: 'Call',
                color: const Color(0xFF00E5A0),
                onTap: () => _call(customer?.mobile ?? ''),
              ),
              // WHATSAPP
              _ActionBtn(
                icon: Icons.chat_rounded,
                label: 'WhatsApp',
                color: const Color(0xFF25D366),
                onTap: () => _sendWhatsApp(customer),
              ),
              // COLLECT
              _ActionBtn(
                icon: Icons.payments_rounded,
                label: 'Collect',
                color: const Color(0xFF6C63FF),
                onTap: () => _showCollectSheet(context, customer),
              ),
            ]),
          ),
      ]),
    );
  }

  // 👈 FIX: Consolidated WhatsApp Message & Direct Launch bypass
  Future<void> _sendWhatsApp(Customer? customer) async {
    final mobile = customer?.mobile ?? '';
    final customerId = customer?.id ?? '';
    if (mobile.isEmpty || customerId.isEmpty) return;

    // Gather ALL unpaid installments (Today + Overdue) for this specific customer
    final map = <String, Installment>{};

    for (var i in fp.todayInstallments) {
      if (i.customerId == customerId && i.status != 'Paid') map[i.id] = i;
    }
    for (var i in fp.overdueInstallments) {
      if (i.customerId == customerId && i.status != 'Paid') map[i.id] = i;
    }

    final pendingInsts = map.values.toList();
    pendingInsts.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    double totalDue = 0;
    String details = '';

    for (var pInst in pendingInsts) {
      totalDue += pInst.remainingAmount;

      final shortLoanId = pInst.loanId.length > 6
          ? pInst.loanId.substring(0, 6).toUpperCase()
          : pInst.loanId.toUpperCase();

      details += '🔹 *Inst #${pInst.installmentNumber}* (Loan: $shortLoanId)\n';
      details += '      Amount: ₹${pInst.remainingAmount.toStringAsFixed(0)}\n';
      details += '      Due Date: ${pInst.dueDate}\n\n';
    }

    // "Kindly" has been removed as requested
    final message =
        'This is a reminder from *Erramala Finance*.\n\n'
        'You have pending payment(s) to clear:\n\n'
        '$details'
        '🔴 *Total Amount Due: ₹${totalDue.toStringAsFixed(0)}*\n\n'
        'Please make your payment at the earliest to avoid any inconvenience.';

    final clean  = mobile.replaceAll(RegExp(r'\D'), '');
    final number = clean.startsWith('91') ? clean : '91$clean';
    final encoded = Uri.encodeComponent(message);
    final uri = Uri.parse('https://wa.me/$number?text=$encoded');

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch WhatsApp: $e');
    }
  }

  // ── COLLECT SHEET ───────────────────────────────────────────

  Future<void> _showCollectSheet(BuildContext context, Customer? customer) async {
    String method = 'Cash';

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141E2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (_, ss) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          left: 20, right: 20, top: 12,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFF243050), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 18),
          Row(children: [
            CircleAvatar(radius: 22,
                backgroundColor: const Color(0xFF00E5A0).withOpacity(0.15),
                child: Text(customer?.initials ?? '?',
                    style: const TextStyle(color: Color(0xFF00E5A0), fontWeight: FontWeight.w700))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(customer?.fullName ?? 'Unknown',
                  style: const TextStyle(color: Color(0xFFEDF2FF), fontWeight: FontWeight.w700, fontSize: 15),
                  overflow: TextOverflow.ellipsis),
              Text('Installment #${inst.installmentNumber}  •  Due ${inst.dueDate}',
                  style: const TextStyle(color: Color(0xFF7B8FAD), fontSize: 12)),
            ])),
          ]),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5A0).withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF00E5A0).withOpacity(0.3)),
            ),
            child: Column(children: [
              const Text('Collection Amount', style: TextStyle(color: Color(0xFF7B8FAD), fontSize: 11)),
              const SizedBox(height: 4),
              Text('₹${_fmtExact(inst.amount)}',
                  style: const TextStyle(color: Color(0xFF00E5A0), fontSize: 36, fontWeight: FontWeight.w800)),
            ]),
          ),
          const SizedBox(height: 18),
          const Text('Payment Method', style: TextStyle(color: Color(0xFF7B8FAD), fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8,
            children: ['Cash', 'UPI', 'Bank Transfer', 'Cheque'].map((m) {
              final sel = method == m;
              return GestureDetector(
                onTap: () => ss(() => method = m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? const Color(0xFF00E5A0).withOpacity(0.12) : const Color(0xFF1A2540),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: sel ? const Color(0xFF00E5A0) : const Color(0xFF243050)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_mIcon(m), color: sel ? const Color(0xFF00E5A0) : const Color(0xFF7B8FAD), size: 15),
                    const SizedBox(width: 6),
                    Text(m, style: TextStyle(
                        color: sel ? const Color(0xFF00E5A0) : const Color(0xFF7B8FAD),
                        fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
                  ]),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx, method),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Confirm Collection', style: TextStyle(fontSize: 15)),
            ),
          ),
        ]),
      )),
    );

    if (result == null || !context.mounted) return;

    try {
      final db   = DatabaseHelper.instance;
      final loan = await db.getLoan(inst.loanId);
      if (loan == null) return;
      final pay = await context.read<FinanceProvider>().collectPayment(
        loan: loan, installment: inst, paymentMethod: result,
      );
      await onDone();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF00E5A0), size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(
              '₹${_fmtExact(inst.amount)} collected  •  ${pay.receiptNumber}',
              style: const TextStyle(color: Color(0xFFEDF2FF)),
            )),
          ]),
          backgroundColor: const Color(0xFF141E2E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFFF6B6B),
        ));
      }
    }
  }

  IconData _mIcon(String m) {
    switch (m) {
      case 'UPI':           return Icons.qr_code_rounded;
      case 'Bank Transfer': return Icons.account_balance_rounded;
      case 'Cheque':        return Icons.receipt_long_rounded;
      default:              return Icons.payments_rounded;
    }
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 11)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
      ]),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════
//  SUMMARY BAR
// ═══════════════════════════════════════════════════════════════

class _SummaryBar extends StatelessWidget {
  final double expected, collected;
  final int total, paid, pending;
  const _SummaryBar({
    required this.expected,
    required this.collected,
    required this.total,
    required this.paid,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    final pct = expected > 0 ? (collected / expected).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: const Color(0xFF0F1621),
      child: Column(children: [
        Row(children: [
          Expanded(child: _Pill2('Total',     '$total',               const Color(0xFF7B8FAD))),
          const SizedBox(width: 8),
          Expanded(child: _Pill2('Expected',  '₹${_fmtExact(expected)}', const Color(0xFFFFB800))),
          const SizedBox(width: 8),
          Expanded(child: _Pill2('Collected', '₹${_fmtExact(collected)}',const Color(0xFF00E5A0))),
          const SizedBox(width: 8),
          Expanded(child: _Pill2('Pending',   '$pending',            const Color(0xFFFF6B6B))),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => LinearProgressIndicator(
              value: v, minHeight: 6,
              backgroundColor: const Color(0xFF243050),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E5A0)),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text('${(pct * 100).toStringAsFixed(1)}% collected',
              style: const TextStyle(color: Color(0xFF00E5A0), fontSize: 11)),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SHARED WIDGETS & UTILS
// ═══════════════════════════════════════════════════════════════

class _Pill2 extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Pill2(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    decoration: BoxDecoration(
        color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
    child: Column(children: [
      Text(value,
          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
          overflow: TextOverflow.ellipsis),
      Text(label, style: const TextStyle(color: Color(0xFF3D4F6B), fontSize: 9)),
    ]),
  );
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
        color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
    child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500)),
  );
}

class _EmptyMsg extends StatelessWidget {
  final IconData icon;
  final String msg;
  const _EmptyMsg({required this.icon, required this.msg});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 64, color: const Color(0xFF243050)),
      const SizedBox(height: 14),
      Text(msg, style: const TextStyle(color: Color(0xFF7B8FAD), fontSize: 14),
          textAlign: TextAlign.center),
    ]),
  );
}

String _fmtExact(double v) {
  final str = v.toStringAsFixed(0);
  if (str.length <= 3) return str;
  final lastThree = str.substring(str.length - 3);
  final rest = str.substring(0, str.length - 3);
  final RegExp reg = RegExp(r'\B(?=(\d{2})+(?!\d))');
  return '${rest.replaceAll(reg, ',')},$lastThree';
}

Future<void> _call(String mobile) async {
  if (mobile.isEmpty) return;
  final uri = Uri.parse('tel:$mobile');
  try {
    await launchUrl(uri);
  } catch (e) {
    debugPrint('Could not launch call: $e');
  }
}