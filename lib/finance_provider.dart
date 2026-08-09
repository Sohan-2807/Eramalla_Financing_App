import 'package:flutter/material.dart';
import 'customer_loan_modules.dart';
import 'database_helper.dart';

class FinanceProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;

  List<Customer> _customers = [];
  List<Loan> _loans = [];
  List<Installment> _todayInst = [];
  List<Installment> _overdueInst = [];
  Map<String, dynamic> _stats = {};
  bool loading = false;
  String _searchQ = '';

  // ── GETTERS ──────────────────────────────────────────────

  List<Customer> get customers => _searchQ.isEmpty
      ? _customers
      : _customers
      .where((c) =>
  c.fullName.toLowerCase().contains(_searchQ.toLowerCase()) ||
      c.mobile.contains(_searchQ) ||
      (c.village?.toLowerCase().contains(_searchQ.toLowerCase()) ??
          false) ||
      (c.city?.toLowerCase().contains(_searchQ.toLowerCase()) ?? false))
      .toList();

  List<Loan> get loans => _loans;
  List<Loan> get activeLoans =>
      _loans.where((l) => l.status == 'Active').toList();
  List<Installment> get todayInstallments => _todayInst;
  List<Installment> get overdueInstallments => _overdueInst;
  Map<String, dynamic> get stats => _stats;

  /// Calculates total expected amount for today (sums all today installment targets)
  double get todayTotalExpected {
    return _todayInst.fold(0.0, (s, i) => s + i.amount);
  }

  /// Calculates 6-Month trend of total loan amounts given (disbursed) per month
  List<Map<String, dynamic>> get monthlyDisbursedList {
    final now = DateTime.now();
    final List<Map<String, dynamic>> series = [];

    for (int i = 5; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final monthStr =
          "${monthDate.year}-${monthDate.month.toString().padLeft(2, '0')}";

      final monthLoans = _loans.where((l) => l.loanDate.startsWith(monthStr));
      final totalGiven = monthLoans.fold(0.0, (s, l) => s + l.amountGiven);

      series.add({
        'month': monthStr,
        'amount': totalGiven,
      });
    }

    return series;
  }

  Customer? customerById(String id) {
    try {
      return _customers.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Loan> loansForCustomer(String cId) =>
      _loans.where((l) => l.customerId == cId).toList();

  // ── LOAD ────────────────────────────────────────────────

  Future<void> loadAll() async {
    loading = true;
    notifyListeners();
    await Future.wait([
      _loadCustomers(),
      _loadLoans(),
      _loadToday(),
      _loadOverdue(),
    ]);
    await _loadStats();
    loading = false;
    notifyListeners();
  }

  Future<void> _loadCustomers() async =>
      _customers = await _db.getAllCustomers();
  Future<void> _loadLoans() async => _loans = await _db.getAllLoans();
  Future<void> _loadToday() async =>
      _todayInst = await _db.getTodayInstallments();
  Future<void> _loadOverdue() async =>
      _overdueInst = await _db.getOverdueInstallments();

  Future<void> _loadStats() async {
    _stats = await _db.getDashboardStats();

    // Enrich dashboard stats map with calculated fields
    final now = DateTime.now();
    final curMonthStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}";
    final thisMonthDisbursed = _loans
        .where((l) => l.loanDate.startsWith(curMonthStr))
        .fold(0.0, (s, l) => s + l.amountGiven);

    _stats['todayTotalAmount'] = todayTotalExpected;
    _stats['monthDisbursed'] = thisMonthDisbursed;
    _stats['monthlyDisbursedSeries'] = monthlyDisbursedList;
  }

  void setSearch(String q) {
    _searchQ = q;
    notifyListeners();
  }

  // ── CUSTOMER ACTIONS ────────────────────────────────────

  Future<Customer> addCustomer(Customer c) async {
    await _db.insertCustomer(c);
    await Future.wait([_loadCustomers(), _loadStats()]);
    notifyListeners();
    return c;
  }

  Future<void> updateCustomer(Customer c) async {
    await _db.updateCustomer(c);
    await _loadCustomers();
    notifyListeners();
  }

  Future<void> deleteCustomer(String customerId) async {
    await _db.deleteCustomerCascade(customerId);
    await loadAll();
  }

  // ── LOAN ACTIONS ────────────────────────────────────────

  Future<Loan> createLoan(Loan loan) async {
    await _db.insertLoan(loan);
    final schedule = LoanEngine.generateSchedule(loan);
    await _db.insertInstallmentsBatch(schedule);
    await Future.wait([_loadLoans(), _loadToday(), _loadStats()]);
    notifyListeners();
    return loan;
  }

  Future<void> updateLoan(Loan loan) async {
    await _db.updateLoan(loan);
    await loadAll();
  }

  Future<void> deleteLoan(String loanId) async {
    await _db.deleteLoanCascade(loanId);
    await loadAll();
  }

  /// Override old loan: close it, create new one, archive history
  Future<void> overrideLoan({
    required Loan oldLoan,
    required Loan newLoan,
  }) async {
    final closed = oldLoan.copyWith(status: 'Settled by Override');
    await _db.updateLoan(closed);
    await _db.insertLoan(newLoan);
    await _db.insertInstallmentsBatch(LoanEngine.generateSchedule(newLoan));
    await Future.wait([_loadLoans(), _loadStats()]);
    notifyListeners();
  }

  Future<List<Installment>> installmentsForLoan(String loanId) =>
      _db.getInstallmentsByLoan(loanId);

  Future<List<Installment>> installmentsForDate(DateTime date) =>
      _db.getInstallmentsByDate(date.toIso8601String().substring(0, 10));

  // ── PAYMENT ─────────────────────────────────────────────

  Future<Payment> collectPayment({
    required Loan loan,
    required Installment installment,
    required String paymentMethod,
    String? collector,
    String? notes,
  }) async {
    final now = DateTime.now();
    final receipt = Payment.generateReceipt();
    final amount = installment.amount;

    final payment = Payment(
      id: Payment.generateId(),
      loanId: loan.id,
      customerId: loan.customerId,
      installmentId: installment.id,
      date: now.toIso8601String().substring(0, 10),
      time:
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      amount: amount,
      collector: collector,
      paymentMethod: paymentMethod,
      notes: notes,
      receiptNumber: receipt,
    );

    await _db.insertPayment(payment);

    // Mark installment paid
    await _db.updateInstallment(installment.copyWith(
      paidAmount: amount,
      remainingAmount: 0,
      status: 'Paid',
      collector: collector,
      collectionTime: payment.time,
      paymentMethod: paymentMethod,
      receiptNumber: receipt,
    ));

    // Update loan
    final newPaid = loan.paidAmount + amount;
    final newOutstanding =
    (loan.outstandingBalance - amount).clamp(0.0, double.infinity);
    final newCompleted = loan.completedCycles + 1;
    final loanStatus = newOutstanding <= 0 ? 'Closed' : 'Active';

    await _db.updateLoan(loan.copyWith(
      paidAmount: newPaid,
      outstandingBalance: newOutstanding,
      completedCycles: newCompleted,
      status: loanStatus,
    ));

    await Future.wait(
        [_loadLoans(), _loadToday(), _loadOverdue(), _loadStats()]);
    notifyListeners();
    return payment;
  }

  Future<List<Payment>> paymentsForLoan(String loanId) =>
      _db.getPaymentsByLoan(loanId);

  Future<List<Payment>> paymentsForDate(String date) =>
      _db.getPaymentsByDate(date);

  Future<List<Payment>> paymentsForRange(String from, String to) =>
      _db.getPaymentsByDateRange(from, to);

  // ── EXPENSE ─────────────────────────────────────────────

  Future<void> addExpense(Expense e) async {
    await _db.insertExpense(e);
    notifyListeners();
  }

  Future<List<Expense>> getExpenses() => _db.getAllExpenses();

  // ── REPORT DATA ─────────────────────────────────────────

  Future<Map<String, dynamic>> reportData({
    required DateTime from,
    required DateTime to,
  }) async {
    final fromStr = from.toIso8601String().substring(0, 10);
    final toStr = to.toIso8601String().substring(0, 10);
    final pays = await _db.getPaymentsByDateRange(fromStr, toStr);
    final exps = await _db.getExpensesByDateRange(fromStr, toStr);
    final totalCol = pays.fold(0.0, (s, p) => s + p.amount);
    final totalExp = exps.fold(0.0, (s, e) => s + e.amount);
    final outstanding =
    activeLoans.fold(0.0, (s, l) => s + l.outstandingBalance);
    return {
      'totalCollected': totalCol,
      'totalExpenses': totalExp,
      'netProfit': totalCol - totalExp,
      'totalOutstanding': outstanding,
      'activeLoans': activeLoans.length,
      'totalCustomers': _customers.length,
      'payments': pays,
      'expenses': exps,
    };
  }
}