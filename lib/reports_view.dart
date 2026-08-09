import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'finance_provider.dart';
import 'customer_loan_modules.dart';
import 'database_helper.dart';

// ═══════════════════════════════════════════════════════════════
//  REPORTS VIEW  — 2 tabs only: Collection | Loan Recovery
// ═══════════════════════════════════════════════════════════════

class ReportsView extends StatefulWidget {
  const ReportsView({super.key});
  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        bottom: TabBar(
          controller: _tab,
          labelColor: const Color(0xFF00E5A0),
          unselectedLabelColor: const Color(0xFF7B8FAD),
          indicatorColor: const Color(0xFF00E5A0),
          tabs: const [
            Tab(text: 'Collection'),
            Tab(text: 'Loan Recovery'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _CollectionReport(),
          _LoanRecoveryReport(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  COLLECTION REPORT
// ═══════════════════════════════════════════════════════════════

class _CollectionReport extends StatefulWidget {
  const _CollectionReport();
  @override
  State<_CollectionReport> createState() => _CollectionReportState();
}

class _CollectionReportState extends State<_CollectionReport> {
  String _period = 'This Month';
  bool _loading  = true;
  bool _exporting = false;

  double _totalCollected = 0;
  double _outstanding    = 0;
  double _overdueAmt     = 0;
  int    _overdueCount   = 0;
  List<Payment>  _payments   = [];
  Map<String, double> _daily = {};

  static const _periods = ['Today', 'This Week', 'This Month', 'This Year', 'Custom'];
  DateTime _customFrom = DateTime.now().subtract(const Duration(days: 30));
  DateTime _customTo   = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  (DateTime, DateTime) _range() {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_period) {
      case 'Today':
        return (today, now);
      case 'This Week':
        return (today.subtract(Duration(days: today.weekday - 1)), now);
      case 'This Month':
        return (DateTime(now.year, now.month, 1), now);
      case 'This Year':
        return (DateTime(now.year, 1, 1), now);
      case 'Custom':
        return (_customFrom, _customTo);
      default:
        return (DateTime(now.year, now.month, 1), now);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final (from, to) = _range();
    final fp = context.read<FinanceProvider>();

    final pays = await fp.paymentsForRange(
      from.toIso8601String().substring(0, 10),
      to.toIso8601String().substring(0, 10),
    );

    final db      = DatabaseHelper.instance;
    final overdue = await db.getOverdueInstallments();

    final daily = <String, double>{};
    for (final p in pays) {
      daily[p.date] = (daily[p.date] ?? 0) + p.amount;
    }

    setState(() {
      _payments        = pays;
      _daily           = daily;
      _totalCollected  = pays.fold(0.0, (s, p) => s + p.amount);
      _outstanding     = fp.activeLoans.fold(0.0, (s, l) => s + l.outstandingBalance);
      _overdueAmt      = overdue.fold(0.0, (s, i) => s + i.remainingAmount);
      _overdueCount    = overdue.length;
      _loading         = false;
    });
  }

  // ── PDF EXPORT ─────────────────────────────────────────────

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      final prefs     = await _getPrefs();
      final fp        = context.read<FinanceProvider>();
      final custMap   = {for (var c in fp.customers) c.id: c.fullName};
      final pdfBytes  = await _buildPdf(prefs, custMap);
      final dir       = await getApplicationDocumentsDirectory();
      final file      = File('${dir.path}/Eramalla_Collection_Report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Eramalla Collection Report — $_period',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('PDF error: $e'),
          backgroundColor: const Color(0xFFFF6B6B),
        ));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<Map<String, String>> _getPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'businessName': prefs.getString('businessName') ?? 'Eramalla Finance',
      'ownerName':    prefs.getString('ownerName')    ?? '',
      'phone':        prefs.getString('phone')        ?? '',
    };
  }

  Future<Uint8List> _buildPdf(
      Map<String, String> prefs, Map<String, String> custMap) async {
    final doc          = pw.Document(title: 'Collection Report');
    final fontRegular  = await PdfGoogleFonts.nunitoRegular();
    final fontBold     = await PdfGoogleFonts.nunitoBold();
    final fontXBold    = await PdfGoogleFonts.nunitoExtraBold();
    final businessName = prefs['businessName'] ?? 'Eramalla Finance';
    final ownerName    = prefs['ownerName']    ?? '';
    final phone        = prefs['phone']        ?? '';
    final generatedOn  = _dateFmt(DateTime.now());

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (ctx) => [
        // ── Header ────────────────────────────────────────────
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.fromLTRB(28, 22, 28, 22),
          decoration: const pw.BoxDecoration(
            gradient: pw.LinearGradient(colors: [
              PdfColor.fromInt(0xFF0A1628),
              PdfColor.fromInt(0xFF1A1040),
            ]),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(children: [
                pw.Container(
                  width: 40, height: 40,
                  decoration: const pw.BoxDecoration(
                    gradient: pw.LinearGradient(colors: [
                      PdfColor.fromInt(0xFF00E5A0),
                      PdfColor.fromInt(0xFF6C63FF),
                    ]),
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(10)),
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text('₹', style: pw.TextStyle(font: fontXBold, fontSize: 20, color: PdfColors.black)),
                ),
                pw.SizedBox(width: 12),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(businessName, style: pw.TextStyle(font: fontXBold, fontSize: 17, color: PdfColor.fromInt(0xFF00E5A0))),
                  pw.Text('Finance Collection Management', style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColor.fromInt(0xFF7B8FAD))),
                ]),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                if (ownerName.isNotEmpty)
                  pw.Text(ownerName, style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.white)),
                if (phone.isNotEmpty)
                  pw.Text(phone, style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColor.fromInt(0xFF7B8FAD))),
              ]),
            ],
          ),
        ),

        // ── Title ─────────────────────────────────────────────
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(28, 20, 28, 4),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('COLLECTION REPORT', style: pw.TextStyle(font: fontXBold, fontSize: 16, color: PdfColor.fromInt(0xFF0A1628), letterSpacing: 1.5)),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF00E5A0).shade(0.15),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColor.fromInt(0xFF00E5A0), width: 1),
              ),
              child: pw.Text(_period.toUpperCase(), style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColor.fromInt(0xFF00A876))),
            ),
          ]),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(28, 0, 28, 16),
          child: pw.Text('Generated on $generatedOn', style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey600)),
        ),

        // ── KPI Tiles ─────────────────────────────────────────
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 28),
          child: pw.Row(children: [
            _pdfKpi('TOTAL COLLECTED', '₹${_fmtN(_totalCollected)}', 'Received this period', PdfColor.fromInt(0xFF00E5A0), fontBold, fontRegular),
            pw.SizedBox(width: 10),
            _pdfKpi('OUTSTANDING', '₹${_fmtN(_outstanding)}', 'Pending across all loans', PdfColor.fromInt(0xFFFF6B6B), fontBold, fontRegular),
            pw.SizedBox(width: 10),
            _pdfKpi('OVERDUE AMOUNT', '₹${_fmtN(_overdueAmt)}', '$_overdueCount installments', PdfColor.fromInt(0xFFFFB800), fontBold, fontRegular),
          ]),
        ),

        pw.SizedBox(height: 20),

        // ── Payment History Table ──────────────────────────────
        if (_payments.isNotEmpty) ...[
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 28),
            child: pw.Text('PAYMENT HISTORY', style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey600, letterSpacing: 1)),
          ),
          pw.SizedBox(height: 8),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 28),
            child: pw.Table(
              border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFE0E7EF), width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.4),
                1: const pw.FlexColumnWidth(1.6), // Customer Name
                2: const pw.FlexColumnWidth(1.0), // Date
                3: const pw.FlexColumnWidth(0.9), // Amount
                4: const pw.FlexColumnWidth(0.8), // Method
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0A1628)),
                  children: [
                    _th('#',             fontBold),
                    _th('Customer Name', fontBold),
                    _th('Date',          fontBold),
                    _th('Amount',        fontBold),
                    _th('Method',        fontBold),
                  ],
                ),
                // Data rows
                ..._payments.take(50).toList().asMap().entries.map((e) {
                  final i = e.key;
                  final p = e.value;
                  final custName = custMap[p.customerId] ?? 'Unknown';
                  final bg = i.isEven ? PdfColors.white : PdfColor.fromInt(0xFFF7FAFE);
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: bg),
                    children: [
                      _td('${i + 1}',        fontRegular),
                      _td(custName,          fontRegular),
                      _td('${p.date} ${p.time}', fontRegular),
                      _td('₹${_fmtN(p.amount)}', fontBold,
                          style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColor.fromInt(0xFF008A5E))),
                      _td(p.paymentMethod,   fontRegular),
                    ],
                  );
                }),
                // Total row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF00E5A0)),
                  children: [
                    _th('', fontBold),
                    _th('TOTAL', fontBold),
                    _th('', fontBold),
                    _th('₹${_fmtN(_totalCollected)}', fontBold,
                        style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.black)),
                    _th('', fontBold),
                  ],
                ),
              ],
            ),
          ),
          if (_payments.length > 50)
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(28, 6, 28, 0),
              child: pw.Text('… and ${_payments.length - 50} more payments not shown.',
                  style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey)),
            ),
        ],

        pw.SizedBox(height: 24),
      ],
      footer: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 10),
        decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColor.fromInt(0xFFE0E7EF), width: 1))),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('$businessName  •  Confidential',
              style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey)),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.grey)),
          pw.Text('Generated by Eramalla Finance',
              style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey)),
        ]),
      ),
    ));

    return doc.save();
  }

  // ── PDF helper widgets ─────────────────────────────────────

  pw.Widget _pdfKpi(String label, String value, String sub,
      PdfColor color, pw.Font bold, pw.Font regular) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: color.shade(0.08),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          border: pw.Border.all(color: color.shade(0.3), width: 1),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label, style: pw.TextStyle(font: bold, fontSize: 7, color: color, letterSpacing: 0.5)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 13, color: color)),
          pw.SizedBox(height: 2),
          pw.Text(sub, style: pw.TextStyle(font: regular, fontSize: 7, color: PdfColors.grey600)),
        ]),
      ),
    );
  }

  pw.Widget _th(String t, pw.Font font, {pw.TextStyle? style}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    child: pw.Text(
      t,
      style: style ?? pw.TextStyle(font: font, fontSize: 8, color: PdfColors.white),
    ),
  );

  pw.Widget _td(String t, pw.Font font, {bool small = false, pw.TextStyle? style}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    child: pw.Text(
      t,
      style: style ?? pw.TextStyle(font: font, fontSize: small ? 7 : 8, color: PdfColors.black),
    ),
  );

  String _dateFmt(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}  ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';

  // ── BUILD UI ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Period selector
      _PeriodBar(
        current: _period,
        periods: _periods,
        onSelect: (p) async {
          if (p == 'Custom') {
            final range = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              initialDateRange: DateTimeRange(start: _customFrom, end: _customTo),
              builder: (c, child) => Theme(
                data: Theme.of(c).copyWith(
                    colorScheme: Theme.of(c).colorScheme.copyWith(
                        primary: const Color(0xFF00E5A0), onPrimary: Colors.black)),
                child: child!,
              ),
            );
            if (range == null) return;
            _customFrom = range.start;
            _customTo   = range.end;
          }
          setState(() => _period = p);
          _load();
        },
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5A0)))
            : RefreshIndicator(
          color: const Color(0xFF00E5A0),
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            child: Column(children: [
              // KPI row
              Row(children: [
                Expanded(child: _KpiTile('Total Collected', '₹${_fmtN(_totalCollected)}',
                    Icons.arrow_downward_rounded, const Color(0xFF00E5A0))),
                const SizedBox(width: 10),
                Expanded(child: _KpiTile('Outstanding', '₹${_fmtN(_outstanding)}',
                    Icons.pending_rounded, const Color(0xFFFF6B6B))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _KpiTile('Overdue Amount', '₹${_fmtN(_overdueAmt)}',
                    Icons.warning_rounded, const Color(0xFFFFB800))),
                const SizedBox(width: 10),
                Expanded(child: _KpiTile('Overdue Count', '$_overdueCount',
                    Icons.people_rounded, const Color(0xFF6C63FF))),
              ]),
              const SizedBox(height: 16),

              // Mini bar chart
              if (_daily.isNotEmpty) _MiniBarChart(data: _daily),
              const SizedBox(height: 16),

              // Export row
              Row(children: [
                Expanded(
                  child: _exporting
                      ? Container(
                    height: 48,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFFF6B6B)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFFFF6B6B))),
                    ),
                  )
                      : OutlinedButton.icon(
                    onPressed: _exportPdf,
                    icon: const Icon(Icons.picture_as_pdf_rounded,
                        color: Color(0xFFFF6B6B), size: 18),
                    label: const Text('Export PDF',
                        style: TextStyle(color: Color(0xFFFF6B6B))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFF6B6B)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _printPreview(),
                    icon: const Icon(Icons.print_rounded,
                        color: Color(0xFF00E5A0), size: 18),
                    label: const Text('Print / Preview',
                        style: TextStyle(color: Color(0xFF00E5A0))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF00E5A0)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 16),

              // Payment list
              if (_payments.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Payment History',
                      style: TextStyle(
                          color: Color(0xFFEDF2FF),
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ),
                const SizedBox(height: 8),
                ..._payments.map((p) => _PayRow(p, context.read<FinanceProvider>())),
              ] else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('No payments in this period',
                      style: TextStyle(color: Color(0xFF7B8FAD)))),
                ),
            ]),
          ),
        ),
      ),
    ]);
  }

  Future<void> _printPreview() async {
    final prefs = await _getPrefs();
    final fp = context.read<FinanceProvider>();
    final custMap = {for (var c in fp.customers) c.id: c.fullName};
    final bytes = await _buildPdf(prefs, custMap);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'Eramalla_Collection_Report',
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  LOAN RECOVERY REPORT
// ═══════════════════════════════════════════════════════════════

class _LoanRecoveryReport extends StatelessWidget {
  const _LoanRecoveryReport();

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceProvider>(builder: (_, fp, __) {
      final loans = fp.loans;
      if (loans.isEmpty) {
        return const Center(child: Text('No loans yet',
            style: TextStyle(color: Color(0xFF7B8FAD))));
      }

      final active   = loans.where((l) => l.status == 'Active').toList();
      final closed   = loans.where((l) => l.status == 'Closed').toList();
      final settled  = loans.where((l) => l.status == 'Settled by Override').toList();

      final totalGiven     = loans.fold(0.0, (s, l) => s + l.amountGiven);
      final totalToReceive = loans.fold(0.0, (s, l) => s + l.amountToReceive);
      final totalCollected = loans.fold(0.0, (s, l) => s + l.paidAmount);
      final recoveryRate   = totalToReceive > 0 ? totalCollected / totalToReceive : 0.0;

      return RefreshIndicator(
        color: const Color(0xFF00E5A0),
        onRefresh: () => fp.loadAll(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          child: Column(children: [
            // Recovery rate card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF141E2E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF243050)),
              ),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Loan Recovery Rate',
                      style: TextStyle(color: Color(0xFF7B8FAD), fontSize: 13)),
                  Text('${(recoveryRate * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                          color: recoveryRate >= 0.8
                              ? const Color(0xFF00E5A0)
                              : recoveryRate >= 0.5
                              ? const Color(0xFFFFB800)
                              : const Color(0xFFFF6B6B),
                          fontWeight: FontWeight.w800,
                          fontSize: 24)),
                ]),
                const SizedBox(height: 12),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: recoveryRate.clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: v, minHeight: 12,
                      backgroundColor: const Color(0xFF243050),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        v >= 0.8
                            ? const Color(0xFF00E5A0)
                            : v >= 0.5
                            ? const Color(0xFFFFB800)
                            : const Color(0xFFFF6B6B),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),

            // Totals row
            Row(children: [
              Expanded(child: _StatBox('Total Given',   '₹${_fmtN(totalGiven)}',     const Color(0xFF6C63FF))),
              const SizedBox(width: 8),
              Expanded(child: _StatBox('To Receive',    '₹${_fmtN(totalToReceive)}', const Color(0xFFFFB800))),
              const SizedBox(width: 8),
              Expanded(child: _StatBox('Collected',     '₹${_fmtN(totalCollected)}', const Color(0xFF00E5A0))),
            ]),
            const SizedBox(height: 10),

            // Status counts
            Row(children: [
              Expanded(child: _StatBox('Active',   '${active.length}',  const Color(0xFFFFB800))),
              const SizedBox(width: 8),
              Expanded(child: _StatBox('Closed',   '${closed.length}',  const Color(0xFF00E5A0))),
              const SizedBox(width: 8),
              Expanded(child: _StatBox('Settled',  '${settled.length}', const Color(0xFF7B8FAD))),
            ]),
            const SizedBox(height: 16),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text('All Loans',
                  style: TextStyle(
                      color: Color(0xFFEDF2FF),
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ),
            const SizedBox(height: 8),
            ...loans.map((l) => _LoanRecovRow(loan: l, customer: fp.customerById(l.customerId))),
          ]),
        ),
      );
    });
  }
}

// ═══════════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════

class _PeriodBar extends StatelessWidget {
  final String current;
  final List<String> periods;
  final ValueChanged<String> onSelect;
  const _PeriodBar({required this.current, required this.periods, required this.onSelect});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      itemCount: periods.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final p   = periods[i];
        final sel = current == p;
        return GestureDetector(
          onTap: () => onSelect(p),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: sel
                  ? const Color(0xFF00E5A0).withOpacity(0.12)
                  : const Color(0xFF141E2E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: sel ? const Color(0xFF00E5A0) : const Color(0xFF243050),
              ),
            ),
            child: Text(p,
                style: TextStyle(
                    color: sel ? const Color(0xFF00E5A0) : const Color(0xFF7B8FAD),
                    fontSize: 12,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
          ),
        );
      },
    ),
  );
}

class _KpiTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _KpiTile(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF141E2E),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16),
            overflow: TextOverflow.ellipsis),
        Text(label,
            style: const TextStyle(color: Color(0xFF7B8FAD), fontSize: 11)),
      ])),
    ]),
  );
}

class _MiniBarChart extends StatelessWidget {
  final Map<String, double> data;
  const _MiniBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final sorted = data.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final visible = sorted.length > 14
        ? sorted.sublist(sorted.length - 14)
        : sorted;
    final maxVal = visible.fold(0.0, (m, e) => e.value > m ? e.value : m);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141E2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF243050)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Daily Collections',
            style: TextStyle(
                color: Color(0xFFEDF2FF),
                fontWeight: FontWeight.w600,
                fontSize: 13)),
        const SizedBox(height: 14),
        SizedBox(
          height: 80,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: visible.map((e) {
              final pct = maxVal > 0 ? (e.value / maxVal).clamp(0.02, 1.0) : 0.02;
              final day = e.key.length >= 10 ? e.key.substring(8) : e.key;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: pct),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => Container(
                          height: 60 * v,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00E5A0), Color(0xFF6C63FF)],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(day,
                          style: const TextStyle(
                              color: Color(0xFF3D4F6B), fontSize: 8)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatBox(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(children: [
      Text(value,
          style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16),
          overflow: TextOverflow.ellipsis),
      Text(label, style: const TextStyle(color: Color(0xFF7B8FAD), fontSize: 10)),
    ]),
  );
}

class _LoanRecovRow extends StatelessWidget {
  final Loan loan;
  final Customer? customer;
  const _LoanRecovRow({required this.loan, required this.customer});

  Color _sc(String s) {
    switch (s) {
      case 'Active':             return const Color(0xFFFFB800);
      case 'Closed':             return const Color(0xFF00E5A0);
      case 'Settled by Override':return const Color(0xFF6C63FF);
      default:                   return const Color(0xFF7B8FAD);
    }
  }

  @override
  Widget build(BuildContext context) {
    final col = _sc(loan.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFF141E2E),
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(customer?.fullName ?? 'Unknown',
              style: const TextStyle(
                  color: Color(0xFFEDF2FF), fontSize: 13, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(
            '₹${_fmtN(loan.amountGiven)} given  •  '
                '${loan.completedCycles}/${loan.totalCycles} paid  •  '
                '${loan.frequency}',
            style: const TextStyle(color: Color(0xFF7B8FAD), fontSize: 11),
          ),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: col.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4)),
            child: Text(loan.status,
                style: TextStyle(color: col, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 4),
          Text('${(loan.progressPercent * 100).toStringAsFixed(0)}%',
              style: TextStyle(color: col, fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
      ]),
    );
  }
}

class _PayRow extends StatelessWidget {
  final Payment payment;
  final FinanceProvider fp;
  const _PayRow(this.payment, this.fp);

  @override
  Widget build(BuildContext context) {
    final customer = fp.customerById(payment.customerId);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: const Color(0xFF141E2E),
          borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        const Icon(Icons.arrow_downward_rounded, color: Color(0xFF00E5A0), size: 16),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(customer?.fullName ?? 'Unknown',
              style: const TextStyle(
                  color: Color(0xFFEDF2FF), fontSize: 12, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis),
          Text(
            '${payment.date}  ${payment.time}  •  ${payment.paymentMethod}  •  ${payment.receiptNumber}',
            style: const TextStyle(color: Color(0xFF7B8FAD), fontSize: 10),
            overflow: TextOverflow.ellipsis,
          ),
        ])),
        const SizedBox(width: 8),
        Text('₹${_fmtN(payment.amount)}',
            style: const TextStyle(
                color: Color(0xFF00E5A0), fontWeight: FontWeight.w700, fontSize: 14)),
      ]),
    );
  }
}

// ─── Utility ──────────────────────────────────────────────────

String _fmtN(double v) {
  if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
  if (v >= 100000)   return '${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000)     return '${(v / 1000).toStringAsFixed(1)}K';
  return v.toStringAsFixed(0);
}