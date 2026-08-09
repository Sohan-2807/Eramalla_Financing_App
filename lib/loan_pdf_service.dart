import 'dart:typed_data';
import 'package:flutter/material.dart'
    show BuildContext, ScaffoldMessenger, SnackBar, Color, Text, BorderRadius, SnackBarBehavior;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'customer_loan_modules.dart';

// ══════════════════════════════════════════════════════════════
//  LOAN PDF SERVICE (Full Loan Summary & Detailed Schedules)
// ══════════════════════════════════════════════════════════════

class LoanPdfService {
  LoanPdfService._();

  // Brand Palette
  static const _green  = PdfColor.fromInt(0xFF00E5A0);
  static const _violet = PdfColor.fromInt(0xFF6C63FF);
  static const _red    = PdfColor.fromInt(0xFFFF6B6B);
  static const _dark   = PdfColor.fromInt(0xFF0A1628);

  /// Generate and share full loan summary document
  static Future<void> share(
      BuildContext context, {
        required Loan loan,
        required Customer customer,
        required List<Installment> installments,
        required List<Payment> payments,
        String? businessName,
      }) async {
    final prefs = await SharedPreferences.getInstance();
    // 👈 Updated Spelling to Erramala
    final name = businessName ?? prefs.getString('businessName') ?? 'Erramala Finance';
    final ownerName = prefs.getString('ownerName') ?? '';
    final phone = prefs.getString('phone') ?? '';

    final pdfBytes = await _build(
      loan: loan,
      customer: customer,
      installments: installments,
      payments: payments,
      businessName: name,
      ownerName: ownerName,
      businessPhone: phone,
    );

    final fileName =
        'Loan_${loan.id}_${customer.fullName.replaceAll(' ', '_')}.pdf';

    await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
  }

  /// Print preview
  static Future<void> preview(
      BuildContext context, {
        required Loan loan,
        required Customer customer,
        required List<Installment> installments,
        required List<Payment> payments,
        String? businessName,
      }) async {
    final prefs = await SharedPreferences.getInstance();
    final name = businessName ?? prefs.getString('businessName') ?? 'Erramala Finance';
    final ownerName = prefs.getString('ownerName') ?? '';
    final phone = prefs.getString('phone') ?? '';

    await Printing.layoutPdf(
      onLayout: (_) async => _build(
        loan: loan,
        customer: customer,
        installments: installments,
        payments: payments,
        businessName: name,
        ownerName: ownerName,
        businessPhone: phone,
      ),
      name: 'Loan Summary — ${customer.fullName}',
    );
  }

  // ── INTERNAL PDF BUILDER ─────────────────────────────────────

  static Future<Uint8List> _build({
    required Loan loan,
    required Customer customer,
    required List<Installment> installments,
    required List<Payment> payments,
    required String businessName,
    required String ownerName,
    required String businessPhone,
  }) async {
    final doc = pw.Document(
      title: 'Loan Summary',
      author: businessName,
      creator: 'Erramala Finance App',
    );

    // Fonts
    final fontRegular   = await PdfGoogleFonts.nunitoRegular();
    final fontBold      = await PdfGoogleFonts.nunitoBold();
    final fontExtraBold = await PdfGoogleFonts.nunitoExtraBold();
    final fontMono      = await PdfGoogleFonts.sourceCodeProRegular();

    // Load Logo Image
    pw.MemoryImage? logoImage;
    try {
      final ByteData data = await rootBundle.load('assets/logo.png');
      logoImage = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      // Fallback handled safely inside the header
    }

    // Key Calculated Metrics
    final paidCount    = installments.where((i) => i.status == 'Paid').length;
    final pendingCount = installments.where((i) => i.status != 'Paid').length;
    final overdueCount = installments.where((i) => i.isOverdue).length;
    final progressPct  = loan.progressPercent;
    final generatedOn  = _dateStr(DateTime.now());

    final displayCustId = customer.id.length > 12
        ? '${customer.id.substring(0, 12)}…'
        : customer.id;

    final lastPaymentStr = payments.isNotEmpty
        ? '${payments.first.date} (₹${_fmt(payments.first.amount)})'
        : 'No payments yet';

    // ── PAGE 1: SUMMARY ──────────────────────────────────────
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(0),
        build: (ctx) => [
          // Company Heading Banner
          _header(businessName, ownerName, businessPhone,
              fontBold, fontExtraBold, fontRegular, logoImage),

          // Title & Status Row
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(28, 16, 28, 0),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('LOAN STATEMENT & SUMMARY',
                    style: pw.TextStyle(
                        font: fontExtraBold,
                        fontSize: 16,
                        color: _dark,
                        letterSpacing: 1.5)),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: loan.status == 'Active'
                        ? _green.shade(0.15)
                        : _violet.shade(0.15),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(
                      color: loan.status == 'Active' ? _green : _violet,
                      width: 1,
                    ),
                  ),
                  child: pw.Text(loan.status.toUpperCase(),
                      style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 10,
                          color: loan.status == 'Active'
                              ? _green
                              : _violet)),
                ),
              ],
            ),
          ),

          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(28, 2, 28, 14),
            child: pw.Text('Generated on $generatedOn',
                style: pw.TextStyle(
                    font: fontRegular,
                    fontSize: 8,
                    color: PdfColors.grey)),
          ),

          // Customer Details & Loan Timeline Box
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 28),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _sectionBox(
                    title: 'CUSTOMER DETAILS',
                    fontBold: fontBold,
                    fontRegular: fontRegular,
                    rows: [
                      _kv('Name', customer.fullName, fontBold, fontRegular),
                      _kv('Mobile', customer.mobile, fontBold, fontRegular),
                      if (customer.city != null)
                        _kv('City', customer.city!, fontBold, fontRegular),
                      if (customer.village != null)
                        _kv('Village', customer.village!, fontBold, fontRegular),
                      if (customer.aadhaar != null)
                        _kv('Aadhaar', _maskAadhaar(customer.aadhaar!), fontBold, fontRegular),
                      _kv('Customer ID', displayCustId, fontBold, fontRegular),
                    ],
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: _sectionBox(
                    title: 'LOAN DATES & TIMELINE',
                    fontBold: fontBold,
                    fontRegular: fontRegular,
                    rows: [
                      _kv('Loan ID', loan.id, fontMono, fontRegular, smallKey: true),
                      _kv('Issued Date', loan.loanDate, fontBold, fontRegular),
                      _kv('Start Date', loan.firstCollectionDate.toIso8601String().substring(0, 10), fontBold, fontRegular),
                      _kv('End Date', loan.endDate ?? '-', fontBold, fontRegular),
                      _kv('Last Payment', lastPaymentStr, fontBold, fontRegular),
                      _kv('Frequency', loan.frequency, fontBold, fontRegular),
                    ],
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 12),

          // Key Financial Summary Tiles
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 28),
            child: pw.Row(children: [
              _financeTile('ISSUED AMOUNT',
                  '₹${_fmt(loan.amountGiven)}',
                  'Disbursed principal',
                  PdfColor.fromInt(0xFF6C63FF),
                  fontBold, fontRegular),
              pw.SizedBox(width: 8),
              _financeTile('TO RECEIVE',
                  '₹${_fmt(loan.amountToReceive)}',
                  'Total payable',
                  PdfColor.fromInt(0xFF00B4D8),
                  fontBold, fontRegular),
              pw.SizedBox(width: 8),
              _financeTile('COLLECTED',
                  '₹${_fmt(loan.paidAmount)}',
                  'Total paid so far',
                  _green,
                  fontBold, fontRegular),
              pw.SizedBox(width: 8),
              _financeTile('BALANCE PAYMENTS',
                  '₹${_fmt(loan.outstandingBalance)}',
                  'Outstanding balance',
                  _red,
                  fontBold, fontRegular),
            ]),
          ),

          pw.SizedBox(height: 12),

          // Installments Stats
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 28),
            child: pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF8FFFE),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                border: pw.Border.all(color: _green, width: 1),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _emiStat('EMI Amount',
                      '₹${_fmt(loan.installmentAmount)}',
                      fontBold, fontRegular),
                  _divider(),
                  _emiStat('Completed',
                      '${loan.completedCycles} of ${loan.totalCycles}',
                      fontBold, fontRegular),
                  _divider(),
                  _emiStat('Remaining',
                      '${loan.remainingCycles} installments',
                      fontBold, fontRegular),
                  _divider(),
                  _emiStat('Overdue Cycles',
                      '$overdueCount',
                      fontBold, fontRegular),
                ],
              ),
            ),
          ),

          pw.SizedBox(height: 12),

          // Repayment Progress Bar
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 28),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('REPAYMENT PROGRESS',
                    style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 8,
                        color: PdfColors.grey600,
                        letterSpacing: 1)),
                pw.SizedBox(height: 4),
                pw.Container(
                  height: 12,
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFE5EBF0),
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Row(
                    children: [
                      if (progressPct > 0)
                        pw.Expanded(
                          flex: (progressPct.clamp(0.0, 1.0) * 1000).toInt(),
                          child: pw.Container(
                            height: 12,
                            decoration: const pw.BoxDecoration(
                              color: PdfColor.fromInt(0xFF00E5A0),
                              borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                            ),
                          ),
                        ),
                      if (progressPct < 1.0)
                        pw.Expanded(
                          flex: ((1.0 - progressPct.clamp(0.0, 1.0)) * 1000).toInt(),
                          child: pw.SizedBox(),
                        ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('0%', style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey)),
                    pw.Text('${(progressPct * 100).toStringAsFixed(1)}% Complete',
                        style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColor.fromInt(0xFF00A876))),
                    pw.Text('100%', style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey)),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 12),

          // Status boxes
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 28),
            child: pw.Row(children: [
              _statusBox('PAID CYCLES', paidCount, _green, fontBold, fontRegular),
              pw.SizedBox(width: 8),
              _statusBox('PENDING CYCLES', pendingCount - overdueCount,
                  PdfColor.fromInt(0xFF7B8FAD), fontBold, fontRegular),
              pw.SizedBox(width: 8),
              _statusBox('OVERDUE CYCLES', overdueCount, _red, fontBold, fontRegular),
            ]),
          ),

          pw.SizedBox(height: 14),

          // Payment History Table
          if (payments.isNotEmpty) ...[
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 28),
              child: pw.Text('RECENT PAYMENT HISTORY',
                  style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 8,
                      color: PdfColors.grey600,
                      letterSpacing: 1)),
            ),
            pw.SizedBox(height: 6),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 28),
              child: _paymentTable(
                  payments.take(10).toList(), fontBold, fontRegular, fontMono),
            ),
          ],

          pw.SizedBox(height: 14),
        ],
        footer: (ctx) => _footer(
            ctx, businessName, businessPhone, fontRegular, fontBold),
      ),
    );

    // ── PAGE 2: FULL SCHEDULE ──────────────────────────────────
    if (installments.isNotEmpty) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(0),
          build: (ctx) => [
            _header(businessName, ownerName, businessPhone,
                fontBold, fontExtraBold, fontRegular, logoImage),
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(28, 16, 28, 0),
              child: pw.Text('COMPLETE INSTALLMENT SCHEDULE',
                  style: pw.TextStyle(
                      font: fontExtraBold,
                      fontSize: 14,
                      color: _dark,
                      letterSpacing: 1.2)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(28, 2, 28, 12),
              child: pw.Text(
                  '${customer.fullName}  •  Loan ID: ${loan.id}  •  Issued: ${loan.loanDate}',
                  style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 8,
                      color: PdfColors.grey)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 28),
              child: _scheduleTable(installments, fontBold, fontRegular, fontMono),
            ),
            pw.SizedBox(height: 16),
          ],
          footer: (ctx) => _footer(
              ctx, businessName, businessPhone, fontRegular, fontBold),
        ),
      );
    }

    return doc.save();
  }

  // ── HEADER & SHARED COMPONENTS ─────────────────────────────

  static pw.Widget _header(
      String businessName,
      String ownerName,
      String phone,
      pw.Font fontBold,
      pw.Font fontExtraBold,
      pw.Font fontRegular,
      pw.MemoryImage? logoImage,
      ) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(28, 20, 28, 20),
      decoration: const pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [
            PdfColor.fromInt(0xFF0A1628),
            PdfColor.fromInt(0xFF1A1040),
          ],
          begin: pw.Alignment.centerLeft,
          end: pw.Alignment.centerRight,
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Row(children: [
            if (logoImage != null)
              pw.Container(
                width: 40,
                height: 40,
                decoration: pw.BoxDecoration(
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(9)),
                  image: pw.DecorationImage(
                    image: logoImage,
                    fit: pw.BoxFit.cover,
                  ),
                ),
              )
            else
              pw.Container(
                width: 40,
                height: 40,
                decoration: const pw.BoxDecoration(
                  gradient: pw.LinearGradient(
                    colors: [
                      PdfColor.fromInt(0xFF00E5A0),
                      PdfColor.fromInt(0xFF6C63FF),
                    ],
                  ),
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(9)),
                ),
                alignment: pw.Alignment.center,
                child: pw.Text('₹',
                    style: pw.TextStyle(
                        font: fontExtraBold,
                        fontSize: 20,
                        color: PdfColors.black)),
              ),
            pw.SizedBox(width: 12),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(businessName.toUpperCase(),
                    style: pw.TextStyle(
                        font: fontExtraBold,
                        fontSize: 18,
                        color: PdfColor.fromInt(0xFF00E5A0),
                        letterSpacing: 1.0)),
                pw.Text('Finance & Collection Management',
                    style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 8,
                        color: PdfColor.fromInt(0xFF7B8FAD))),
              ],
            ),
          ]),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              if (ownerName.isNotEmpty)
                pw.Text(ownerName,
                    style: pw.TextStyle(
                        font: fontExtraBold, // Made Extra Bold
                        fontSize: 18, // Made Bigger
                        color: PdfColors.white)),
              if (phone.isNotEmpty)
                pw.Text(phone,
                    style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 9,
                        color: PdfColor.fromInt(0xFF7B8FAD))),
              pw.Text('Powered by Erramala', // 👈 Updated
                  style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 7,
                      color: PdfColor.fromInt(0xFF3D4F6B))),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _footer(
      pw.Context ctx,
      String businessName,
      String phone,
      pw.Font fontRegular,
      pw.Font fontBold,
      ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColor.fromInt(0xFFE0E7EF), width: 1),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('$businessName  •  Confidential Statement',
              style: pw.TextStyle(
                  font: fontRegular,
                  fontSize: 8,
                  color: PdfColors.grey)),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: pw.TextStyle(
                  font: fontBold, fontSize: 8, color: PdfColors.grey)),
          pw.Text('Generated by Erramala Finance System', // 👈 Updated
              style: pw.TextStyle(
                  font: fontRegular,
                  fontSize: 8,
                  color: PdfColors.grey)),
        ],
      ),
    );
  }

  static pw.Widget _sectionBox({
    required String title,
    required pw.Font fontBold,
    required pw.Font fontRegular,
    required List<pw.Widget> rows,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE0E7EF), width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 8,
                  color: PdfColor.fromInt(0xFF6C63FF),
                  letterSpacing: 0.8)),
          pw.Divider(color: PdfColor.fromInt(0xFFE0E7EF), height: 8),
          ...rows,
        ],
      ),
    );
  }

  static pw.Widget _kv(
      String key,
      String value,
      pw.Font fontBold,
      pw.Font fontRegular, {
        bool smallKey = false,
      }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.0),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 80,
            child: pw.Text(key,
                style: pw.TextStyle(
                    font: fontRegular,
                    fontSize: 8,
                    color: PdfColors.grey600)),
          ),
          pw.Expanded(
            child: pw.Text(value,
                style: pw.TextStyle(
                    font: smallKey ? fontRegular : fontBold,
                    fontSize: smallKey ? 7.5 : 8,
                    color: PdfColors.black)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _financeTile(
      String label,
      String value,
      String subtitle,
      PdfColor accent,
      pw.Font fontBold,
      pw.Font fontRegular,
      ) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: accent.shade(0.07),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          border: pw.Border.all(color: accent.shade(0.3), width: 1),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 6.5,
                    color: accent,
                    letterSpacing: 0.5)),
            pw.SizedBox(height: 3),
            pw.Text(value,
                style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 12,
                    color: accent)),
            pw.SizedBox(height: 2),
            pw.Text(subtitle,
                style: pw.TextStyle(
                    font: fontRegular,
                    fontSize: 6.5,
                    color: PdfColors.grey600)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _emiStat(
      String label,
      String value,
      pw.Font fontBold,
      pw.Font fontRegular,
      ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(value,
            style: pw.TextStyle(
                font: fontBold,
                fontSize: 10,
                color: PdfColor.fromInt(0xFF0A1628))),
        pw.SizedBox(height: 2),
        pw.Text(label,
            style: pw.TextStyle(
                font: fontRegular,
                fontSize: 7.5,
                color: PdfColors.grey600)),
      ],
    );
  }

  static pw.Widget _divider() => pw.Container(
    width: 1,
    height: 24,
    color: PdfColor.fromInt(0xFFD0DBE8),
  );

  static pw.Widget _statusBox(
      String label,
      int count,
      PdfColor color,
      pw.Font fontBold,
      pw.Font fontRegular,
      ) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: pw.BoxDecoration(
          color: color.shade(0.08),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          border: pw.Border.all(color: color.shade(0.3), width: 1),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text('$count',
                style: pw.TextStyle(
                    font: fontBold, fontSize: 16, color: color)),
            pw.SizedBox(width: 6),
            pw.Text(label,
                style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 8,
                    color: color)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _paymentTable(
      List<Payment> payments,
      pw.Font fontBold,
      pw.Font fontRegular,
      pw.Font fontMono,
      ) {
    final headerStyle = pw.TextStyle(
        font: fontBold, fontSize: 7.5, color: PdfColors.white);
    final cellStyle = pw.TextStyle(
        font: fontRegular, fontSize: 7.5, color: PdfColors.black);
    final monoStyle = pw.TextStyle(
        font: fontMono, fontSize: 7, color: PdfColors.black);

    return pw.Table(
      border: pw.TableBorder.all(
          color: PdfColor.fromInt(0xFFE0E7EF), width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.5),
        1: const pw.FlexColumnWidth(1.4),
        2: const pw.FlexColumnWidth(1.0),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(0.8),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF0A1628)),
          children: [
            _th('#', headerStyle),
            _th('Receipt No', headerStyle),
            _th('Date', headerStyle),
            _th('Amount Paid', headerStyle),
            _th('Method', headerStyle),
          ],
        ),
        ...payments.asMap().entries.map((entry) {
          final i = entry.key;
          final p = entry.value;
          final bg = i.isEven
              ? PdfColors.white
              : PdfColor.fromInt(0xFFF7FAFE);
          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              _td('${i + 1}', cellStyle),
              _td(p.receiptNumber, monoStyle),
              _td('${p.date} ${p.time}', cellStyle),
              _td('₹${_fmt(p.amount)}',
                  pw.TextStyle(
                      font: fontBold,
                      fontSize: 7.5,
                      color: PdfColor.fromInt(0xFF008A5E))),
              _td(p.paymentMethod, cellStyle),
            ],
          );
        }),
        pw.TableRow(
          decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF00E5A0)),
          children: [
            _th('', headerStyle),
            _th('TOTAL COLLECTED', headerStyle),
            _th('', headerStyle),
            _th('₹${_fmt(payments.fold(0.0, (s, p) => s + p.amount))}',
                pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.black)),
            _th('', headerStyle),
          ],
        ),
      ],
    );
  }

  static pw.Widget _scheduleTable(
      List<Installment> installments,
      pw.Font fontBold,
      pw.Font fontRegular,
      pw.Font fontMono,
      ) {
    final headerStyle = pw.TextStyle(
        font: fontBold, fontSize: 8, color: PdfColors.white);
    final cellStyle = pw.TextStyle(
        font: fontRegular, fontSize: 8, color: PdfColors.black);

    return pw.Table(
      border: pw.TableBorder.all(
          color: PdfColor.fromInt(0xFFE0E7EF), width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.5),
        1: const pw.FlexColumnWidth(1.2),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(1.0),
        4: const pw.FlexColumnWidth(0.8),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF0A1628)),
          children: [
            _th('#', headerStyle),
            _th('Due Date', headerStyle),
            _th('Amount', headerStyle),
            _th('Paid', headerStyle),
            _th('Status', headerStyle),
          ],
        ),
        ...installments.asMap().entries.map((entry) {
          final i = entry.key;
          final inst = entry.value;
          final isPaid = inst.status == 'Paid';
          final isOverdue = inst.isOverdue;
          final bg = isPaid
              ? PdfColor.fromInt(0xFFF0FBF7)
              : isOverdue
              ? PdfColor.fromInt(0xFFFFF5F5)
              : i.isEven
              ? PdfColors.white
              : PdfColor.fromInt(0xFFF7FAFE);
          final statusColor = isPaid
              ? PdfColor.fromInt(0xFF008A5E)
              : isOverdue
              ? PdfColor.fromInt(0xFFCC3333)
              : PdfColors.grey700;

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              _td('${inst.installmentNumber}', cellStyle),
              _td(inst.dueDate, cellStyle),
              _td('₹${_fmt(inst.amount)}', cellStyle),
              _td(isPaid ? '₹${_fmt(inst.paidAmount)}' : '-',
                  pw.TextStyle(
                      font: fontBold,
                      fontSize: 8,
                      color: isPaid
                          ? PdfColor.fromInt(0xFF008A5E)
                          : PdfColors.grey400)),
              _td(
                isPaid
                    ? 'Paid'
                    : isOverdue
                    ? 'Overdue'
                    : 'Pending',
                pw.TextStyle(
                    font: fontBold, fontSize: 8, color: statusColor),
              ),
            ],
          );
        }),
      ],
    );
  }

  // ── HELPERS & UTILITIES ────────────────────────────────────

  static pw.Widget _th(String text, pw.TextStyle style) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    child: pw.Text(text, style: style),
  );

  static pw.Widget _td(String text, pw.TextStyle style) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
    child: pw.Text(text, style: style),
  );

  static String _fmt(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(2)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(2)}L';
    return v.toStringAsFixed(2);
  }

  static String _dateStr(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _maskAadhaar(String a) =>
      a.length >= 4 ? 'XXXX XXXX ${a.substring(a.length - 4)}' : a;
}

// ══════════════════════════════════════════════════════════════
//  PDF GENERATOR (For Payment Receipts & Summary Reports)
// ══════════════════════════════════════════════════════════════

class PdfGenerator {
  /// Generate and share a payment receipt PDF in A5 format
  static Future<void> receipt({
    required BuildContext context,
    required Payment payment,
    required Customer customer,
    required Loan loan,
    required Installment installment,
    String? businessName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    // 👈 Updated Spelling to Erramala
    final name = businessName ?? prefs.getString('businessName') ?? 'Erramala Finance';
    final ownerName = prefs.getString('ownerName') ?? '';
    final pdf = pw.Document();

    final fontRegular = await PdfGoogleFonts.nunitoRegular();
    final fontBold    = await PdfGoogleFonts.nunitoBold();

    // Load Logo for the Receipt too
    pw.MemoryImage? logoImage;
    try {
      final ByteData data = await rootBundle.load('assets/logo.png');
      logoImage = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {}

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logoImage != null)
              pw.Center(
                child: pw.Container(
                  width: 40,
                  height: 40,
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  decoration: pw.BoxDecoration(
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(9)),
                    image: pw.DecorationImage(
                      image: logoImage,
                      fit: pw.BoxFit.cover,
                    ),
                  ),
                ),
              ),
            pw.Center(
              child: pw.Text(
                name.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 16,
                  font: fontBold,
                  color: PdfColor.fromInt(0xFF00E5A0),
                ),
              ),
            ),
            if (ownerName.isNotEmpty)
              pw.Center(
                child: pw.Text(
                  ownerName,
                  style: pw.TextStyle(
                    fontSize: 12,
                    font: fontBold,
                    color: PdfColors.black,
                  ),
                ),
              ),
            pw.Center(
              child: pw.Text('PAYMENT RECEIPT',
                  style: pw.TextStyle(
                      fontSize: 9,
                      font: fontRegular,
                      color: PdfColor.fromInt(0xFF7B8FAD))),
            ),
            pw.SizedBox(height: 6),
            pw.Divider(color: PdfColor.fromInt(0xFF00E5A0), thickness: 1),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Receipt No: ${payment.receiptNumber}',
                    style: pw.TextStyle(font: fontBold, fontSize: 9)),
                pw.Text('Date: ${payment.date} ${payment.time}',
                    style: pw.TextStyle(font: fontRegular, fontSize: 9)),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Text('Customer: ${customer.fullName}',
                style: pw.TextStyle(font: fontBold, fontSize: 10)),
            pw.Text('Loan ID: ${loan.id}',
                style: pw.TextStyle(font: fontRegular, fontSize: 9)),
            pw.Text('Installment: #${installment.installmentNumber}',
                style: pw.TextStyle(font: fontRegular, fontSize: 9)),
            pw.SizedBox(height: 8),
            pw.Divider(color: PdfColor.fromInt(0xFFE0E7EF)),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Amount Paid:',
                    style: pw.TextStyle(fontSize: 11, font: fontBold)),
                pw.Text('₹${payment.amount.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                        fontSize: 14,
                        font: fontBold,
                        color: PdfColor.fromInt(0xFF008A5E))),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Outstanding Balance:',
                    style: pw.TextStyle(fontSize: 9, font: fontRegular)),
                pw.Text('₹${loan.outstandingBalance.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 9, font: fontBold)),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Payment Method:',
                    style: pw.TextStyle(fontSize: 9, font: fontRegular)),
                pw.Text(payment.paymentMethod,
                    style: pw.TextStyle(fontSize: 9, font: fontBold)),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(color: PdfColor.fromInt(0xFFE0E7EF)),
            pw.Spacer(),
            pw.Center(
              child: pw.Text('Thank you for your payment!',
                  style: pw.TextStyle(
                      fontSize: 8,
                      font: fontRegular,
                      color: PdfColors.grey600)),
            ),
          ],
        ),
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Receipt_${payment.receiptNumber}.pdf',
    );
  }

  /// Generate and trigger summary report notification
  static Future<void> summaryReport({
    required BuildContext context,
    required Map<String, dynamic> data,
    required String period,
  }) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generating Summary Report PDF...'),
        backgroundColor: Color(0xFF141E2E),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}