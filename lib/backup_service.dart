import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'customer_loan_modules.dart';
import 'database_helper.dart';

/// Standalone backup service — used by settings and auto-backup scheduler.
class BackupService {
  static final BackupService instance = BackupService._();
  BackupService._();

  final _db = DatabaseHelper.instance;

  /// Create a JSON backup. Returns the file path on success.
  Future<String> createBackup({String businessName = 'Eramalla'}) async {
    final customers = await _db.getAllCustomers();
    final loans = await _db.getAllLoans();
    final expenses = await _db.getAllExpenses();

    final allInst = <Map<String, dynamic>>[];
    final allPay = <Map<String, dynamic>>[];
    for (final l in loans) {
      final insts = await _db.getInstallmentsByLoan(l.id);
      final pays = await _db.getPaymentsByLoan(l.id);
      allInst.addAll(insts.map((i) => i.toMap()));
      allPay.addAll(pays.map((p) => p.toMap()));
    }

    final payload = {
      'version': '2.0',
      'appName': 'Eramalla',
      'businessName': businessName,
      'timestamp': DateTime.now().toIso8601String(),
      'counts': {
        'customers': customers.length,
        'loans': loans.length,
        'installments': allInst.length,
        'payments': allPay.length,
        'expenses': expenses.length,
      },
      'customers': customers.map((c) => c.toMap()).toList(),
      'loans': loans.map((l) => l.toMap()).toList(),
      'installments': allInst,
      'payments': allPay,
      'expenses': expenses.map((e) => e.toMap()).toList(),
    };

    final dir = await getApplicationDocumentsDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/eramalla_backup_$ts.json');
    await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(payload),
        encoding: utf8);
    return file.path;
  }

  /// Restore from a backup file path.
  Future<RestoreResult> restore(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return RestoreResult.fail('Backup file not found');
      }
      final raw = await file.readAsString(encoding: utf8);
      final data = jsonDecode(raw) as Map<String, dynamic>;

      final customers = (data['customers'] as List)
          .map((m) => Customer.fromMap(m as Map<String, dynamic>))
          .toList();
      final loans = (data['loans'] as List)
          .map((m) => Loan.fromMap(m as Map<String, dynamic>))
          .toList();
      final expenses = (data['expenses'] as List? ?? [])
          .map((m) => Expense.fromMap(m as Map<String, dynamic>))
          .toList();

      for (final c in customers) await _db.insertCustomer(c);
      for (final l in loans) await _db.insertLoan(l);
      for (final e in expenses) await _db.insertExpense(e);

      return RestoreResult.ok(
        customers: customers.length,
        loans: loans.length,
        expenses: expenses.length,
      );
    } catch (e) {
      return RestoreResult.fail('Restore error: $e');
    }
  }

  /// List backup files, newest first.
  Future<List<File>> listBackups() async {
    final dir = await getApplicationDocumentsDirectory();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) =>
    f.path.contains('eramalla_backup_') &&
        f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  Future<void> deleteBackup(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}

class RestoreResult {
  final bool success;
  final String message;
  final int customersRestored;
  final int loansRestored;
  final int expensesRestored;

  RestoreResult._({
    required this.success,
    required this.message,
    this.customersRestored = 0,
    this.loansRestored = 0,
    this.expensesRestored = 0,
  });

  factory RestoreResult.ok({
    required int customers,
    required int loans,
    required int expenses,
  }) =>
      RestoreResult._(
        success: true,
        message:
        'Restored $customers customers, $loans loans, $expenses expenses',
        customersRestored: customers,
        loansRestored: loans,
        expensesRestored: expenses,
      );

  factory RestoreResult.fail(String msg) =>
      RestoreResult._(success: false, message: msg);
}
