import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'customer_loan_modules.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _db;
  DatabaseHelper._();

  Future<Database> get database async => _db ??= await _init();

  Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'eramalla_v3.db');
    return openDatabase(path, version: 1, onCreate: _create);
  }

  Future<void> _create(Database db, int v) async {
    await db.execute('''CREATE TABLE customers(
      id TEXT PRIMARY KEY, fullName TEXT NOT NULL, fatherName TEXT,
      mobile TEXT NOT NULL, altMobile TEXT, address TEXT, village TEXT,
      city TEXT, district TEXT, state TEXT, pinCode TEXT,
      aadhaar TEXT, pan TEXT, dob TEXT, gender TEXT,
      occupation TEXT, monthlyIncome REAL, photoPath TEXT,
      status TEXT DEFAULT 'Active',
      guarantorName TEXT, guarantorMobile TEXT, guarantorAddress TEXT,
      guarantorRelation TEXT, guarantorAadhaar TEXT,
      notes TEXT, createdAt TEXT NOT NULL)''');

    await db.execute('''CREATE TABLE loans(
      id TEXT PRIMARY KEY, customerId TEXT NOT NULL,
      amountGiven REAL NOT NULL, amountToReceive REAL NOT NULL,
      loanDate TEXT NOT NULL, endDate TEXT,
      installmentAmount REAL NOT NULL,
      frequency TEXT DEFAULT 'Daily',
      totalCycles INTEGER NOT NULL,
      completedCycles INTEGER DEFAULT 0,
      paidAmount REAL DEFAULT 0,
      outstandingBalance REAL NOT NULL,
      status TEXT DEFAULT 'Active',
      parentLoanId TEXT,
      isExistingLoan INTEGER DEFAULT 0,
      completedAtMigration INTEGER,
      notes TEXT,
      createdAt TEXT NOT NULL,
      FOREIGN KEY(customerId) REFERENCES customers(id))''');

    await db.execute('''CREATE TABLE installments(
      id TEXT PRIMARY KEY, loanId TEXT NOT NULL, customerId TEXT NOT NULL,
      installmentNumber INTEGER NOT NULL, dueDate TEXT NOT NULL,
      amount REAL NOT NULL, paidAmount REAL DEFAULT 0,
      remainingAmount REAL NOT NULL,
      collector TEXT, collectionTime TEXT,
      paymentMethod TEXT, receiptNumber TEXT,
      status TEXT DEFAULT 'Pending', notes TEXT,
      FOREIGN KEY(loanId) REFERENCES loans(id))''');

    await db.execute('''CREATE TABLE payments(
      id TEXT PRIMARY KEY, loanId TEXT NOT NULL, customerId TEXT NOT NULL,
      installmentId TEXT, date TEXT NOT NULL, time TEXT NOT NULL,
      amount REAL NOT NULL, collector TEXT,
      paymentMethod TEXT DEFAULT 'Cash', notes TEXT,
      receiptNumber TEXT NOT NULL,
      FOREIGN KEY(loanId) REFERENCES loans(id))''');

    await db.execute('''CREATE TABLE expenses(
      id TEXT PRIMARY KEY, category TEXT NOT NULL, amount REAL NOT NULL,
      description TEXT, date TEXT NOT NULL, createdAt TEXT NOT NULL)''');

    await db.execute('CREATE INDEX idx_loans_cust ON loans(customerId)');
    await db.execute('CREATE INDEX idx_inst_loan ON installments(loanId)');
    await db.execute('CREATE INDEX idx_inst_due ON installments(dueDate)');
    await db.execute('CREATE INDEX idx_pay_loan ON payments(loanId)');
    await db.execute('CREATE INDEX idx_pay_date ON payments(date)');
  }

  // ── CUSTOMERS ──────────────────────────────────────────────

  Future<void> insertCustomer(Customer c) async =>
      (await database).insert('customers', c.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<Customer>> getAllCustomers() async =>
      (await (await database).query('customers', orderBy: 'createdAt DESC'))
          .map(Customer.fromMap)
          .toList();

  Future<Customer?> getCustomer(String id) async {
    final r = await (await database)
        .query('customers', where: 'id=?', whereArgs: [id]);
    return r.isEmpty ? null : Customer.fromMap(r.first);
  }

  Future<void> updateCustomer(Customer c) async =>
      (await database).update('customers', c.toMap(),
          where: 'id=?', whereArgs: [c.id]);

  Future<List<Customer>> searchCustomers(String q) async {
    final like = '%$q%';
    return (await (await database).query('customers',
        where:
        'fullName LIKE ? OR mobile LIKE ? OR village LIKE ? OR city LIKE ? OR aadhaar LIKE ?',
        whereArgs: [like, like, like, like, like],
        orderBy: 'fullName ASC'))
        .map(Customer.fromMap)
        .toList();
  }

  // ── LOANS ──────────────────────────────────────────────────

  Future<void> insertLoan(Loan l) async =>
      (await database).insert('loans', l.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<Loan>> getAllLoans() async =>
      (await (await database).query('loans', orderBy: 'createdAt DESC'))
          .map(Loan.fromMap)
          .toList();

  Future<List<Loan>> getLoansByCustomer(String cId) async =>
      (await (await database).query('loans',
          where: 'customerId=?',
          whereArgs: [cId],
          orderBy: 'createdAt DESC'))
          .map(Loan.fromMap)
          .toList();

  Future<Loan?> getLoan(String id) async {
    final r =
    await (await database).query('loans', where: 'id=?', whereArgs: [id]);
    return r.isEmpty ? null : Loan.fromMap(r.first);
  }

  Future<void> updateLoan(Loan l) async =>
      (await database).update('loans', l.toMap(),
          where: 'id=?', whereArgs: [l.id]);

  // ── INSTALLMENTS ────────────────────────────────────────────

  Future<void> insertInstallmentsBatch(List<Installment> list) async {
    final db = await database;
    final batch = db.batch();
    for (final i in list) {
      batch.insert('installments', i.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Installment>> getInstallmentsByLoan(String loanId) async =>
      (await (await database).query('installments',
          where: 'loanId=?',
          whereArgs: [loanId],
          orderBy: 'installmentNumber ASC'))
          .map(Installment.fromMap)
          .toList();

  // 👈 FIX: Removed "AND status!='Paid'" so paid items stay in the list for 100% completion bar
  Future<List<Installment>> getInstallmentsByDate(String date) async =>
      (await (await database).query('installments',
          where: "dueDate=?",
          whereArgs: [date],
          orderBy: 'loanId ASC'))
          .map(Installment.fromMap)
          .toList();

  Future<List<Installment>> getTodayInstallments() async =>
      getInstallmentsByDate(
          DateTime.now().toIso8601String().substring(0, 10));

  Future<List<Installment>> getOverdueInstallments() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return (await (await database).query('installments',
        where: "dueDate<? AND status!='Paid'",
        whereArgs: [today],
        orderBy: 'dueDate ASC'))
        .map(Installment.fromMap)
        .toList();
  }

  Future<void> updateInstallment(Installment i) async =>
      (await database).update('installments', i.toMap(),
          where: 'id=?', whereArgs: [i.id]);

  // ── PAYMENTS ────────────────────────────────────────────────

  Future<void> insertPayment(Payment p) async =>
      (await database).insert('payments', p.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<Payment>> getPaymentsByLoan(String loanId) async =>
      (await (await database).query('payments',
          where: 'loanId=?',
          whereArgs: [loanId],
          orderBy: 'date DESC, time DESC'))
          .map(Payment.fromMap)
          .toList();

  Future<List<Payment>> getPaymentsByDate(String date) async =>
      (await (await database).query('payments',
          where: 'date=?',
          whereArgs: [date],
          orderBy: 'time DESC'))
          .map(Payment.fromMap)
          .toList();

  Future<List<Payment>> getPaymentsByDateRange(String from, String to) async =>
      (await (await database).query('payments',
          where: 'date>=? AND date<=?',
          whereArgs: [from, to],
          orderBy: 'date DESC'))
          .map(Payment.fromMap)
          .toList();

  // ── EXPENSES ────────────────────────────────────────────────

  Future<void> insertExpense(Expense e) async =>
      (await database).insert('expenses', e.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<Expense>> getAllExpenses() async =>
      (await (await database).query('expenses', orderBy: 'date DESC'))
          .map(Expense.fromMap)
          .toList();

  Future<List<Expense>> getExpensesByDateRange(String from, String to) async =>
      (await (await database).query('expenses',
          where: 'date>=? AND date<=?',
          whereArgs: [from, to]))
          .map(Expense.fromMap)
          .toList();

  // ── DASHBOARD STATS ─────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboardStats() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final now = DateTime.now();
    final mp =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final weekStart = now
        .subtract(Duration(days: now.weekday - 1))
        .toIso8601String()
        .substring(0, 10);

    Future<int> cnt(String sql, [List? args]) async =>
        Sqflite.firstIntValue(await db.rawQuery(sql, args)) ?? 0;
    Future<double> sm(String sql, [List? args]) async =>
        ((await db.rawQuery(sql, args)).first.values.first as num?)
            ?.toDouble() ??
            0;

    final totalC = await cnt('SELECT COUNT(*) FROM customers');
    final activeC =
    await cnt("SELECT COUNT(*) FROM customers WHERE status='Active'");
    final totalL = await cnt('SELECT COUNT(*) FROM loans');
    final activeL =
    await cnt("SELECT COUNT(*) FROM loans WHERE status='Active'");
    final closedL =
    await cnt("SELECT COUNT(*) FROM loans WHERE status='Closed'");
    final todayCol = await sm(
        'SELECT COALESCE(SUM(amount),0) FROM payments WHERE date=?', [today]);
    final weekCol = await sm(
        'SELECT COALESCE(SUM(amount),0) FROM payments WHERE date>=?',
        [weekStart]);
    final monthCol = await sm(
        "SELECT COALESCE(SUM(amount),0) FROM payments WHERE date LIKE '$mp%'");
    final outstanding = await sm(
        "SELECT COALESCE(SUM(outstandingBalance),0) FROM loans WHERE status='Active'");
    final overdueC = await cnt(
        "SELECT COUNT(*) FROM installments WHERE dueDate<? AND status!='Paid'",
        [today]);

    // Keep 'Due Today' quick stats showing only pending ones so you know what's left
    final todayDue = await cnt(
        "SELECT COUNT(*) FROM installments WHERE dueDate=? AND status!='Paid'",
        [today]);
    final todayDueAmt = await sm(
        "SELECT COALESCE(SUM(remainingAmount),0) FROM installments WHERE dueDate=? AND status!='Paid'",
        [today]);

    // Monthly collection last 6 months for chart
    final monthlySeries = <Map<String, dynamic>>[];
    for (int i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      final prefix =
          '${d.year}-${d.month.toString().padLeft(2, '0')}';
      final amt = await sm(
          "SELECT COALESCE(SUM(amount),0) FROM payments WHERE date LIKE '$prefix%'");
      monthlySeries.add({'month': prefix, 'amount': amt});
    }

    return {
      'totalCustomers': totalC,
      'activeCustomers': activeC,
      'totalLoans': totalL,
      'activeLoans': activeL,
      'closedLoans': closedL,
      'todayCollection': todayCol,
      'weekCollection': weekCol,
      'monthCollection': monthCol,
      'outstanding': outstanding,
      'overdueCount': overdueC,
      'todayDue': todayDue,
      'todayDueAmount': todayDueAmt,
      'monthlySeries': monthlySeries,
    };
  }

  // ── CASCADE DELETES ──────────────────────────────────────────

  /// Deletes a customer and all associated loans, installments, and payment history
  Future<void> deleteCustomerCascade(String customerId) async {
    final db = await database;
    await db.transaction((txn) async {
      final loans = await txn.query(
        'loans',
        where: 'customerId = ?',
        whereArgs: [customerId],
      );

      for (final l in loans) {
        final loanId = l['id'].toString();
        await txn.delete('payments', where: 'loanId = ?', whereArgs: [loanId]);
        await txn.delete('installments', where: 'loanId = ?', whereArgs: [loanId]);
      }

      await txn.delete('payments', where: 'customerId = ?', whereArgs: [customerId]);
      await txn.delete('loans', where: 'customerId = ?', whereArgs: [customerId]);
      await txn.delete('customers', where: 'id = ?', whereArgs: [customerId]);
    });
  }

  /// Deletes a single loan along with its installments and payment records
  Future<void> deleteLoanCascade(String loanId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('payments', where: 'loanId = ?', whereArgs: [loanId]);
      await txn.delete('installments', where: 'loanId = ?', whereArgs: [loanId]);
      await txn.delete('loans', where: 'id = ?', whereArgs: [loanId]);
    });
  }
}