import 'dart:math';

// ══════════════════════════════════════════════════════════════
//  CUSTOMER
// ══════════════════════════════════════════════════════════════

class Customer {
  final String id;
  final String fullName;
  final String? fatherName;
  final String mobile;
  final String? altMobile;
  final String? address;
  final String? village;
  final String? city;
  final String? district;
  final String? state;
  final String? pinCode;
  final String? aadhaar;
  final String? pan;
  final String? dob;
  final String? gender;
  final String? occupation;
  final double? monthlyIncome;
  final String? photoPath;
  final String status;
  final String? guarantorName;
  final String? guarantorMobile;
  final String? guarantorAddress;
  final String? guarantorRelation;
  final String? guarantorAadhaar;
  final String? notes;
  final String createdAt;

  Customer({
    required this.id,
    required this.fullName,
    this.fatherName,
    required this.mobile,
    this.altMobile,
    this.address,
    this.village,
    this.city,
    this.district,
    this.state,
    this.pinCode,
    this.aadhaar,
    this.pan,
    this.dob,
    this.gender,
    this.occupation,
    this.monthlyIncome,
    this.photoPath,
    this.status = 'Active',
    this.guarantorName,
    this.guarantorMobile,
    this.guarantorAddress,
    this.guarantorRelation,
    this.guarantorAadhaar,
    this.notes,
    required this.createdAt,
  });

  static String generateId() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rnd = Random().nextInt(9999).toString().padLeft(4, '0');
    return 'CUST$ts$rnd';
  }

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }

  String get displayLocation {
    final parts = [village, city, district]
        .where((e) => e != null && e.isNotEmpty)
        .toList();
    return parts.join(', ');
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'fullName': fullName,
    'fatherName': fatherName,
    'mobile': mobile,
    'altMobile': altMobile,
    'address': address,
    'village': village,
    'city': city,
    'district': district,
    'state': state,
    'pinCode': pinCode,
    'aadhaar': aadhaar,
    'pan': pan,
    'dob': dob,
    'gender': gender,
    'occupation': occupation,
    'monthlyIncome': monthlyIncome,
    'photoPath': photoPath,
    'status': status,
    'guarantorName': guarantorName,
    'guarantorMobile': guarantorMobile,
    'guarantorAddress': guarantorAddress,
    'guarantorRelation': guarantorRelation,
    'guarantorAadhaar': guarantorAadhaar,
    'notes': notes,
    'createdAt': createdAt,
  };

  static Customer fromMap(Map<String, dynamic> m) => Customer(
    id: m['id'],
    fullName: m['fullName'],
    fatherName: m['fatherName'],
    mobile: m['mobile'],
    altMobile: m['altMobile'],
    address: m['address'],
    village: m['village'],
    city: m['city'],
    district: m['district'],
    state: m['state'],
    pinCode: m['pinCode'],
    aadhaar: m['aadhaar'],
    pan: m['pan'],
    dob: m['dob'],
    gender: m['gender'],
    occupation: m['occupation'],
    monthlyIncome: (m['monthlyIncome'] as num?)?.toDouble(),
    photoPath: m['photoPath'],
    status: m['status'] ?? 'Active',
    guarantorName: m['guarantorName'],
    guarantorMobile: m['guarantorMobile'],
    guarantorAddress: m['guarantorAddress'],
    guarantorRelation: m['guarantorRelation'],
    guarantorAadhaar: m['guarantorAadhaar'],
    notes: m['notes'],
    createdAt: m['createdAt'],
  );

  Customer copyWith({
    String? status,
    String? photoPath,
    String? notes,
    String? fullName,
    String? mobile,
    String? city,
    String? village,
    String? occupation,
    double? monthlyIncome,
  }) =>
      Customer(
        id: id,
        fullName: fullName ?? this.fullName,
        fatherName: fatherName,
        mobile: mobile ?? this.mobile,
        altMobile: altMobile,
        address: address,
        village: village ?? this.village,
        city: city ?? this.city,
        district: district,
        state: state,
        pinCode: pinCode,
        aadhaar: aadhaar,
        pan: pan,
        dob: dob,
        gender: gender,
        occupation: occupation ?? this.occupation,
        monthlyIncome: monthlyIncome ?? this.monthlyIncome,
        photoPath: photoPath ?? this.photoPath,
        status: status ?? this.status,
        guarantorName: guarantorName,
        guarantorMobile: guarantorMobile,
        guarantorAddress: guarantorAddress,
        guarantorRelation: guarantorRelation,
        guarantorAadhaar: guarantorAadhaar,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );
}

// ══════════════════════════════════════════════════════════════
//  LOAN  — simplified to match real business workflow
//  No interest %, no fees, no insurance.
//  User enters: amountGiven, amountToReceive, totalCycles, frequency, loanDate
// ══════════════════════════════════════════════════════════════

class Loan {
  final String id;
  final String customerId;
  final double amountGiven;       // cash disbursed
  final double amountToReceive;   // total to collect
  final String loanDate;          // date given (collection NEVER starts this day)
  final String? endDate;
  final double installmentAmount; // amountToReceive / totalCycles
  final String frequency;         // Daily | Weekly
  final int totalCycles;
  final int completedCycles;
  final double paidAmount;
  final double outstandingBalance;
  final String status;            // Active | Closed | Settled by Override
  final String? parentLoanId;
  final bool isExistingLoan;
  final int? completedAtMigration; // for existing loan migration
  final String? notes;
  final String createdAt;

  Loan({
    required this.id,
    required this.customerId,
    required this.amountGiven,
    required this.amountToReceive,
    required this.loanDate,
    this.endDate,
    required this.installmentAmount,
    this.frequency = 'Daily',
    required this.totalCycles,
    this.completedCycles = 0,
    this.paidAmount = 0,
    required this.outstandingBalance,
    this.status = 'Active',
    this.parentLoanId,
    this.isExistingLoan = false,
    this.completedAtMigration,
    this.notes,
    required this.createdAt,
  });

  static String generateId() => 'LOAN${DateTime.now().millisecondsSinceEpoch}';

  int get remainingCycles => max(0, totalCycles - completedCycles);
  double get progressPercent =>
      totalCycles > 0 ? (completedCycles / totalCycles).clamp(0.0, 1.0) : 0.0;

  /// First collection date — always the day AFTER loanDate
  DateTime get firstCollectionDate {
    final base = DateTime.parse(loanDate);
    switch (frequency) {
      case 'Weekly':
        return base.add(const Duration(days: 7));
      default: // Daily
        return base.add(const Duration(days: 1));
    }
  }

  static Loan create({
    required String customerId,
    required double amountGiven,
    required double amountToReceive,
    required int totalCycles,
    required String frequency,
    required String loanDate,
    bool isExistingLoan = false,
    int completedCycles = 0,
    double paidAmount = 0,
    String? parentLoanId,
    String? notes,
  }) {
    final emi = double.parse((amountToReceive / totalCycles).toStringAsFixed(2));
    final firstCollection = _firstCollDate(loanDate, frequency);
    final endDate = _calcEndDate(firstCollection, frequency, totalCycles);
    final outstanding = emi * (totalCycles - completedCycles) - paidAmount.clamp(0, double.infinity);

    return Loan(
      id: generateId(),
      customerId: customerId,
      amountGiven: amountGiven,
      amountToReceive: amountToReceive,
      loanDate: loanDate,
      endDate: endDate.toIso8601String().substring(0, 10),
      installmentAmount: emi,
      frequency: frequency,
      totalCycles: totalCycles,
      completedCycles: completedCycles,
      paidAmount: paidAmount,
      outstandingBalance: outstanding > 0 ? outstanding : emi * (totalCycles - completedCycles),
      status: 'Active',
      parentLoanId: parentLoanId,
      isExistingLoan: isExistingLoan,
      completedAtMigration: isExistingLoan ? completedCycles : null,
      notes: notes,
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  static DateTime _firstCollDate(String loanDate, String frequency) {
    final base = DateTime.parse(loanDate);
    return frequency == 'Weekly'
        ? base.add(const Duration(days: 7))
        : base.add(const Duration(days: 1));
  }

  static DateTime _calcEndDate(DateTime firstColl, String frequency, int cycles) {
    switch (frequency) {
      case 'Weekly':
        return firstColl.add(Duration(days: (cycles - 1) * 7));
      default:
        return firstColl.add(Duration(days: cycles - 1));
    }
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'customerId': customerId,
    'amountGiven': amountGiven,
    'amountToReceive': amountToReceive,
    'loanDate': loanDate,
    'endDate': endDate,
    'installmentAmount': installmentAmount,
    'frequency': frequency,
    'totalCycles': totalCycles,
    'completedCycles': completedCycles,
    'paidAmount': paidAmount,
    'outstandingBalance': outstandingBalance,
    'status': status,
    'parentLoanId': parentLoanId,
    'isExistingLoan': isExistingLoan ? 1 : 0,
    'completedAtMigration': completedAtMigration,
    'notes': notes,
    'createdAt': createdAt,
  };

  static Loan fromMap(Map<String, dynamic> m) => Loan(
    id: m['id'],
    customerId: m['customerId'],
    amountGiven: (m['amountGiven'] as num).toDouble(),
    amountToReceive: (m['amountToReceive'] as num).toDouble(),
    loanDate: m['loanDate'],
    endDate: m['endDate'],
    installmentAmount: (m['installmentAmount'] as num).toDouble(),
    frequency: m['frequency'] ?? 'Daily',
    totalCycles: m['totalCycles'],
    completedCycles: m['completedCycles'] ?? 0,
    paidAmount: (m['paidAmount'] as num?)?.toDouble() ?? 0,
    outstandingBalance: (m['outstandingBalance'] as num).toDouble(),
    status: m['status'] ?? 'Active',
    parentLoanId: m['parentLoanId'],
    isExistingLoan: (m['isExistingLoan'] ?? 0) == 1,
    completedAtMigration: m['completedAtMigration'],
    notes: m['notes'],
    createdAt: m['createdAt'],
  );

  Loan copyWith({
    double? paidAmount,
    double? outstandingBalance,
    int? completedCycles,
    String? status,
  }) =>
      Loan(
        id: id,
        customerId: customerId,
        amountGiven: amountGiven,
        amountToReceive: amountToReceive,
        loanDate: loanDate,
        endDate: endDate,
        installmentAmount: installmentAmount,
        frequency: frequency,
        totalCycles: totalCycles,
        completedCycles: completedCycles ?? this.completedCycles,
        paidAmount: paidAmount ?? this.paidAmount,
        outstandingBalance: outstandingBalance ?? this.outstandingBalance,
        status: status ?? this.status,
        parentLoanId: parentLoanId,
        isExistingLoan: isExistingLoan,
        completedAtMigration: completedAtMigration,
        notes: notes,
        createdAt: createdAt,
      );
}

// ══════════════════════════════════════════════════════════════
//  INSTALLMENT
// ══════════════════════════════════════════════════════════════

class Installment {
  final String id;
  final String loanId;
  final String customerId;
  final int installmentNumber;
  final String dueDate;
  final double amount;
  final double paidAmount;
  final double remainingAmount;
  final String? collector;
  final String? collectionTime;
  final String? paymentMethod;
  final String? receiptNumber;
  final String status; // Paid | Pending | Overdue
  final String? notes;

  Installment({
    required this.id,
    required this.loanId,
    required this.customerId,
    required this.installmentNumber,
    required this.dueDate,
    required this.amount,
    this.paidAmount = 0,
    required this.remainingAmount,
    this.collector,
    this.collectionTime,
    this.paymentMethod,
    this.receiptNumber,
    this.status = 'Pending',
    this.notes,
  });

  static String generateId(String loanId, int num) => '${loanId}_I$num';

  bool get isOverdue =>
      status != 'Paid' &&
          DateTime.parse(dueDate).isBefore(
            DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
          );

  String get effectiveStatus => isOverdue ? 'Overdue' : status;

  Map<String, dynamic> toMap() => {
    'id': id,
    'loanId': loanId,
    'customerId': customerId,
    'installmentNumber': installmentNumber,
    'dueDate': dueDate,
    'amount': amount,
    'paidAmount': paidAmount,
    'remainingAmount': remainingAmount,
    'collector': collector,
    'collectionTime': collectionTime,
    'paymentMethod': paymentMethod,
    'receiptNumber': receiptNumber,
    'status': status,
    'notes': notes,
  };

  static Installment fromMap(Map<String, dynamic> m) => Installment(
    id: m['id'],
    loanId: m['loanId'],
    customerId: m['customerId'],
    installmentNumber: m['installmentNumber'],
    dueDate: m['dueDate'],
    amount: (m['amount'] as num).toDouble(),
    paidAmount: (m['paidAmount'] as num?)?.toDouble() ?? 0,
    remainingAmount: (m['remainingAmount'] as num?)?.toDouble() ??
        (m['amount'] as num).toDouble(),
    collector: m['collector'],
    collectionTime: m['collectionTime'],
    paymentMethod: m['paymentMethod'],
    receiptNumber: m['receiptNumber'],
    status: m['status'] ?? 'Pending',
    notes: m['notes'],
  );

  Installment copyWith({
    double? paidAmount,
    double? remainingAmount,
    String? status,
    String? collector,
    String? collectionTime,
    String? paymentMethod,
    String? receiptNumber,
  }) =>
      Installment(
        id: id,
        loanId: loanId,
        customerId: customerId,
        installmentNumber: installmentNumber,
        dueDate: dueDate,
        amount: amount,
        paidAmount: paidAmount ?? this.paidAmount,
        remainingAmount: remainingAmount ?? this.remainingAmount,
        collector: collector ?? this.collector,
        collectionTime: collectionTime ?? this.collectionTime,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        receiptNumber: receiptNumber ?? this.receiptNumber,
        status: status ?? this.status,
        notes: notes,
      );
}

// ══════════════════════════════════════════════════════════════
//  PAYMENT
// ══════════════════════════════════════════════════════════════

class Payment {
  final String id;
  final String loanId;
  final String customerId;
  final String? installmentId;
  final String date;
  final String time;
  final double amount;
  final String? collector;
  final String paymentMethod;
  final String? notes;
  final String receiptNumber;

  Payment({
    required this.id,
    required this.loanId,
    required this.customerId,
    this.installmentId,
    required this.date,
    required this.time,
    required this.amount,
    this.collector,
    this.paymentMethod = 'Cash',
    this.notes,
    required this.receiptNumber,
  });

  static String generateId() => 'PAY${DateTime.now().millisecondsSinceEpoch}';
  static String generateReceipt() {
    final ts = DateTime.now();
    return 'ERA${ts.year}${ts.month.toString().padLeft(2, '0')}${ts.day.toString().padLeft(2, '0')}${ts.millisecondsSinceEpoch % 100000}';
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'loanId': loanId,
    'customerId': customerId,
    'installmentId': installmentId,
    'date': date,
    'time': time,
    'amount': amount,
    'collector': collector,
    'paymentMethod': paymentMethod,
    'notes': notes,
    'receiptNumber': receiptNumber,
  };

  static Payment fromMap(Map<String, dynamic> m) => Payment(
    id: m['id'],
    loanId: m['loanId'],
    customerId: m['customerId'],
    installmentId: m['installmentId'],
    date: m['date'],
    time: m['time'],
    amount: (m['amount'] as num).toDouble(),
    collector: m['collector'],
    paymentMethod: m['paymentMethod'] ?? 'Cash',
    notes: m['notes'],
    receiptNumber: m['receiptNumber'] ?? m['id'],
  );
}

// ══════════════════════════════════════════════════════════════
//  EXPENSE
// ══════════════════════════════════════════════════════════════

class Expense {
  final String id;
  final String category;
  final double amount;
  final String? description;
  final String date;
  final String createdAt;

  static const categories = [
    'Salary', 'Fuel', 'Rent', 'Electricity',
    'Internet', 'Stationery', 'Miscellaneous'
  ];

  Expense({
    required this.id,
    required this.category,
    required this.amount,
    this.description,
    required this.date,
    required this.createdAt,
  });

  static String generateId() => 'EXP${DateTime.now().millisecondsSinceEpoch}';

  Map<String, dynamic> toMap() => {
    'id': id,
    'category': category,
    'amount': amount,
    'description': description,
    'date': date,
    'createdAt': createdAt,
  };

  static Expense fromMap(Map<String, dynamic> m) => Expense(
    id: m['id'],
    category: m['category'],
    amount: (m['amount'] as num).toDouble(),
    description: m['description'],
    date: m['date'],
    createdAt: m['createdAt'],
  );
}

// ══════════════════════════════════════════════════════════════
//  LOAN ENGINE — schedule generator
//  Rule: collection NEVER starts on loan date
//  Daily → first collection = loanDate + 1 day
//  Weekly → first collection = loanDate + 7 days
// ══════════════════════════════════════════════════════════════

class LoanEngine {
  static List<Installment> generateSchedule(Loan loan) {
    final schedule = <Installment>[];
    final firstColl = loan.firstCollectionDate;

    for (int i = 1; i <= loan.totalCycles; i++) {
      final due = _dueDate(firstColl, loan.frequency, i);
      final isPast = i <= (loan.completedAtMigration ?? 0);
      schedule.add(Installment(
        id: Installment.generateId(loan.id, i),
        loanId: loan.id,
        customerId: loan.customerId,
        installmentNumber: i,
        dueDate: due.toIso8601String().substring(0, 10),
        amount: loan.installmentAmount,
        paidAmount: isPast ? loan.installmentAmount : 0,
        remainingAmount: isPast ? 0 : loan.installmentAmount,
        status: isPast ? 'Paid' : 'Pending',
      ));
    }
    return schedule;
  }

  static DateTime _dueDate(DateTime firstColl, String freq, int n) {
    switch (freq) {
      case 'Weekly':
        return firstColl.add(Duration(days: (n - 1) * 7));
      default: // Daily
        return firstColl.add(Duration(days: n - 1));
    }
  }

  static Map<String, double> overrideCalc({
    required Loan oldLoan,
    required double newAmountToReceive,
  }) {
    final outstanding = oldLoan.outstandingBalance;
    final cash = newAmountToReceive - outstanding;
    return {
      'oldBalance': outstanding,
      'adjustmentAmount': outstanding,
      'cashToDisburse': cash > 0 ? cash : 0,
      'newAmountToReceive': newAmountToReceive,
    };
  }
}
