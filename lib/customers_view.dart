import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'finance_provider.dart';
import 'customer_loan_modules.dart';
import 'database_helper.dart';
import 'loan_pdf_service.dart';

// ═══════════════════════════════════════════════════════════════
//  CUSTOMERS LIST
// ═══════════════════════════════════════════════════════════════

class CustomersView extends StatefulWidget {
  const CustomersView({super.key});
  @override
  State<CustomersView> createState() => _CustomersViewState();
}

class _CustomersViewState extends State<CustomersView>
    with SingleTickerProviderStateMixin {
  final _search = TextEditingController();
  String _filter = 'All';
  late AnimationController _listCtrl;

  @override
  void initState() {
    super.initState();
    _listCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    Future.delayed(
        const Duration(milliseconds: 150), () {
      if (mounted) _listCtrl.forward();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceProvider>(builder: (context, fp, _) {
      var list = fp.customers;
      if (_filter != 'All') {
        list = list.where((c) => c.status == _filter).toList();
      }
      return Scaffold(
        appBar: AppBar(
          title: Row(children: [
            const Text('Customers'),
            const SizedBox(width: 8),
            _Chip('${list.length}', const Color(0xFF00E5A0)),
          ]),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_rounded),
              onPressed: () => Navigator.push(
                  context, _sr(const AddCustomerScreen())),
            ),
          ],
        ),
        body: Column(children: [
          _buildSearch(fp),
          _buildFilters(),
          Expanded(
            child: list.isEmpty
                ? _EmptyState(
              icon: Icons.people_outline_rounded,
              title: _search.text.isEmpty ? 'No Customers' : 'No Results',
              subtitle: _search.text.isEmpty
                  ? 'Add your first customer to begin'
                  : 'Try a different search',
              action: _search.text.isEmpty ? 'Add Customer' : null,
              onAction: () => Navigator.push(
                  context, _sr(const AddCustomerScreen())),
            )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final delay = (i * 0.05).clamp(0.0, 0.8);
                final anim = CurvedAnimation(
                    parent: _listCtrl,
                    curve: Interval(delay, 1.0,
                        curve: Curves.easeOut));
                return FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                        begin: const Offset(0, 0.07),
                        end: Offset.zero)
                        .animate(anim),
                    child: _CustomerCard(customer: list[i]),
                  ),
                );
              },
            ),
          ),
        ]),
      );
    });
  }

  Widget _buildSearch(FinanceProvider fp) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: TextField(
      controller: _search,
      onChanged: (v) {
        fp.setSearch(v);
        setState(() {});
      },
      style: const TextStyle(color: Color(0xFFEDF2FF)),
      decoration: InputDecoration(
        hintText: 'Search name, mobile, village…',
        prefixIcon: const Icon(Icons.search_rounded,
            color: Color(0xFF7B8FAD), size: 20),
        suffixIcon: _search.text.isNotEmpty
            ? IconButton(
            icon: const Icon(Icons.close_rounded,
                color: Color(0xFF7B8FAD), size: 20),
            onPressed: () {
              _search.clear();
              fp.setSearch('');
              setState(() {});
            })
            : null,
      ),
    ),
  );

  Widget _buildFilters() {
    const filters = [
      'All', 'Active', 'Closed', 'Pending Verification', 'Blacklisted'
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = filters[i];
          final sel = _filter == f;
          return GestureDetector(
            onTap: () => setState(() => _filter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: sel
                    ? const Color(0xFF00E5A0).withOpacity(0.12)
                    : const Color(0xFF141E2E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: sel
                      ? const Color(0xFF00E5A0)
                      : const Color(0xFF243050),
                ),
              ),
              child: Text(f,
                  style: TextStyle(
                      color: sel
                          ? const Color(0xFF00E5A0)
                          : const Color(0xFF7B8FAD),
                      fontWeight:
                      sel ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 12)),
            ),
          );
        },
      ),
    );
  }
}

// ── CUSTOMER CARD ─────────────────────────────────────────────

class _CustomerCard extends StatelessWidget {
  final Customer customer;
  const _CustomerCard({required this.customer});

  Color _sc(String s) {
    switch (s) {
      case 'Active': return const Color(0xFF00E5A0);
      case 'Closed': return const Color(0xFF7B8FAD);
      case 'Blacklisted': return const Color(0xFFFF6B6B);
      default: return const Color(0xFFFFB800);
    }
  }

  @override
  Widget build(BuildContext context) {
    final col = _sc(customer.status);
    return GestureDetector(
      onTap: () => Navigator.push(
          context, _sr(CustomerDetailScreen(customer: customer))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF141E2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF243050)),
        ),
        child: Row(children: [
          _Avatar(initials: customer.initials, color: col, radius: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(customer.fullName,
                      style: const TextStyle(
                          color: Color(0xFFEDF2FF),
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(customer.mobile,
                      style: const TextStyle(
                          color: Color(0xFF7B8FAD), fontSize: 12)),
                  if (customer.displayLocation.isNotEmpty)
                    Text(customer.displayLocation,
                        style: const TextStyle(
                            color: Color(0xFF3D4F6B), fontSize: 11),
                        overflow: TextOverflow.ellipsis),
                ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _StatusBadge(customer.status, col),
            const SizedBox(height: 4),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFF3D4F6B), size: 18),
          ]),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  ADD CUSTOMER
// ═══════════════════════════════════════════════════════════════

class AddCustomerScreen extends StatefulWidget {
  const AddCustomerScreen({super.key});
  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _form = GlobalKey<FormState>();
  bool _saving = false;

  final _name     = TextEditingController();
  final _father   = TextEditingController();
  final _mobile   = TextEditingController();
  final _altMob   = TextEditingController();
  final _address  = TextEditingController();
  final _village  = TextEditingController();
  final _city     = TextEditingController();
  final _district = TextEditingController();
  final _state    = TextEditingController();
  final _pin      = TextEditingController();
  final _aadhaar  = TextEditingController();
  final _pan      = TextEditingController();
  final _occ      = TextEditingController();
  final _income   = TextEditingController();
  final _gName    = TextEditingController();
  final _gMob     = TextEditingController();
  final _gAddr    = TextEditingController();
  final _gRel     = TextEditingController();
  final _notes    = TextEditingController();

  String _gender = 'Male';
  String _dob    = '';
  String _status = 'Active';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    for (final c in [
      _name, _father, _mobile, _altMob, _address, _village,
      _city, _district, _state, _pin, _aadhaar, _pan, _occ,
      _income, _gName, _gMob, _gAddr, _gRel, _notes
    ]) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      _tab.animateTo(0);
      return;
    }
    setState(() => _saving = true);
    final c = Customer(
      id: Customer.generateId(),
      fullName: _name.text.trim(),
      fatherName: _father.text.trim().ne,
      mobile: _mobile.text.trim(),
      altMobile: _altMob.text.trim().ne,
      address: _address.text.trim().ne,
      village: _village.text.trim().ne,
      city: _city.text.trim().ne,
      district: _district.text.trim().ne,
      state: _state.text.trim().ne,
      pinCode: _pin.text.trim().ne,
      aadhaar: _aadhaar.text.trim().ne,
      pan: _pan.text.trim().ne,
      dob: _dob.isEmpty ? null : _dob,
      gender: _gender,
      occupation: _occ.text.trim().ne,
      monthlyIncome: double.tryParse(_income.text.trim()),
      status: _status,
      guarantorName: _gName.text.trim().ne,
      guarantorMobile: _gMob.text.trim().ne,
      guarantorAddress: _gAddr.text.trim().ne,
      guarantorRelation: _gRel.text.trim().ne,
      notes: _notes.text.trim().ne,
      createdAt: DateTime.now().toIso8601String(),
    );
    await context.read<FinanceProvider>().addCustomer(c);
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context);
      _snack(context, '${c.fullName} added', const Color(0xFF00E5A0));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Customer'),
        bottom: TabBar(
          controller: _tab,
          labelColor: const Color(0xFF00E5A0),
          unselectedLabelColor: const Color(0xFF7B8FAD),
          indicatorColor: const Color(0xFF00E5A0),
          tabs: const [
            Tab(text: 'Personal'),
            Tab(text: 'Guarantor'),
            Tab(text: 'Other'),
          ],
        ),
        actions: [
          _saving
              ? const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF00E5A0))))
              : TextButton(
              onPressed: _save,
              child: const Text('Save',
                  style: TextStyle(
                      color: Color(0xFF00E5A0),
                      fontWeight: FontWeight.w700,
                      fontSize: 15))),
        ],
      ),
      body: Form(
        key: _form,
        child: TabBarView(controller: _tab, children: [
          _personalTab(),
          _guarantorTab(),
          _otherTab(),
        ]),
      ),
    );
  }

  Widget _personalTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      _F(_name, 'Full Name', required: true),
      _F(_father, "Father's Name"),
      _F(_mobile, 'Mobile Number',
          required: true, kb: TextInputType.phone, maxLen: 10),
      _F(_altMob, 'Alternate Mobile',
          kb: TextInputType.phone, maxLen: 10),
      _Drop('Gender', _gender, const ['Male', 'Female', 'Other'],
              (v) => setState(() => _gender = v!)),
      _DateF('Date of Birth', _dob,
              (d) => setState(() => _dob = d)),
      _F(_occ, 'Occupation'),
      _F(_income, 'Monthly Income (₹)', kb: TextInputType.number),
      const _Sec('Address'),
      _F(_address, 'Full Address', maxLines: 2),
      Row(children: [
        Expanded(child: _F(_village, 'Village')),
        const SizedBox(width: 12),
        Expanded(child: _F(_city, 'City')),
      ]),
      Row(children: [
        Expanded(child: _F(_district, 'District')),
        const SizedBox(width: 12),
        Expanded(child: _F(_state, 'State')),
      ]),
      _F(_pin, 'PIN Code', kb: TextInputType.number, maxLen: 6),
      const _Sec('Documents'),
      _F(_aadhaar, 'Aadhaar Number',
          kb: TextInputType.number, maxLen: 12),
      _F(_pan, 'PAN Number', maxLen: 10),
      const SizedBox(height: 80),
    ]),
  );

  Widget _guarantorTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      const _Sec('Guarantor Information'),
      _F(_gName, 'Guarantor Full Name'),
      _F(_gMob, 'Mobile Number',
          kb: TextInputType.phone, maxLen: 10),
      _F(_gAddr, 'Address', maxLines: 2),
      _F(_gRel, 'Relationship'),
      const SizedBox(height: 80),
    ]),
  );

  Widget _otherTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      _Drop('Customer Status', _status,
          const ['Active', 'Closed', 'Pending Verification', 'Blacklisted'],
              (v) => setState(() => _status = v!)),
      _F(_notes, 'Notes / Remarks', maxLines: 5),
      const SizedBox(height: 80),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════
//  EDIT CUSTOMER SCREEN
// ═══════════════════════════════════════════════════════════════

class EditCustomerScreen extends StatefulWidget {
  final Customer customer;
  const EditCustomerScreen({super.key, required this.customer});

  @override
  State<EditCustomerScreen> createState() => _EditCustomerScreenState();
}

class _EditCustomerScreenState extends State<EditCustomerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _form = GlobalKey<FormState>();
  bool _saving = false;

  late TextEditingController _name;
  late TextEditingController _father;
  late TextEditingController _mobile;
  late TextEditingController _altMob;
  late TextEditingController _address;
  late TextEditingController _village;
  late TextEditingController _city;
  late TextEditingController _district;
  late TextEditingController _state;
  late TextEditingController _pin;
  late TextEditingController _aadhaar;
  late TextEditingController _pan;
  late TextEditingController _occ;
  late TextEditingController _income;
  late TextEditingController _gName;
  late TextEditingController _gMob;
  late TextEditingController _gAddr;
  late TextEditingController _gRel;
  late TextEditingController _notes;

  late String _gender;
  late String _dob;
  late String _status;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    final c = widget.customer;
    _name     = TextEditingController(text: c.fullName);
    _father   = TextEditingController(text: c.fatherName ?? '');
    _mobile   = TextEditingController(text: c.mobile);
    _altMob   = TextEditingController(text: c.altMobile ?? '');
    _address  = TextEditingController(text: c.address ?? '');
    _village  = TextEditingController(text: c.village ?? '');
    _city     = TextEditingController(text: c.city ?? '');
    _district = TextEditingController(text: c.district ?? '');
    _state    = TextEditingController(text: c.state ?? '');
    _pin      = TextEditingController(text: c.pinCode ?? '');
    _aadhaar  = TextEditingController(text: c.aadhaar ?? '');
    _pan      = TextEditingController(text: c.pan ?? '');
    _occ      = TextEditingController(text: c.occupation ?? '');
    _income   = TextEditingController(text: c.monthlyIncome?.toStringAsFixed(0) ?? '');
    _gName    = TextEditingController(text: c.guarantorName ?? '');
    _gMob     = TextEditingController(text: c.guarantorMobile ?? '');
    _gAddr    = TextEditingController(text: c.guarantorAddress ?? '');
    _gRel     = TextEditingController(text: c.guarantorRelation ?? '');
    _notes    = TextEditingController(text: c.notes ?? '');

    _gender = c.gender ?? 'Male';
    _dob    = c.dob ?? '';
    _status = c.status;
  }

  @override
  void dispose() {
    _tab.dispose();
    for (final c in [
      _name, _father, _mobile, _altMob, _address, _village,
      _city, _district, _state, _pin, _aadhaar, _pan, _occ,
      _income, _gName, _gMob, _gAddr, _gRel, _notes
    ]) c.dispose();
    super.dispose();
  }

  Future<void> _update() async {
    if (!_form.currentState!.validate()) {
      _tab.animateTo(0);
      return;
    }
    setState(() => _saving = true);
    final updated = Customer(
      id: widget.customer.id,
      fullName: _name.text.trim(),
      fatherName: _father.text.trim().ne,
      mobile: _mobile.text.trim(),
      altMobile: _altMob.text.trim().ne,
      address: _address.text.trim().ne,
      village: _village.text.trim().ne,
      city: _city.text.trim().ne,
      district: _district.text.trim().ne,
      state: _state.text.trim().ne,
      pinCode: _pin.text.trim().ne,
      aadhaar: _aadhaar.text.trim().ne,
      pan: _pan.text.trim().ne,
      dob: _dob.isEmpty ? null : _dob,
      gender: _gender,
      occupation: _occ.text.trim().ne,
      monthlyIncome: double.tryParse(_income.text.trim()),
      status: _status,
      guarantorName: _gName.text.trim().ne,
      guarantorMobile: _gMob.text.trim().ne,
      guarantorAddress: _gAddr.text.trim().ne,
      guarantorRelation: _gRel.text.trim().ne,
      notes: _notes.text.trim().ne,
      createdAt: widget.customer.createdAt,
    );

    await DatabaseHelper.instance.updateCustomer(updated);
    if (mounted) {
      await context.read<FinanceProvider>().loadAll();
      setState(() => _saving = false);
      Navigator.pop(context, updated);
      _snack(context, '${updated.fullName} updated', const Color(0xFF00E5A0));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Customer'),
        bottom: TabBar(
          controller: _tab,
          labelColor: const Color(0xFF00E5A0),
          unselectedLabelColor: const Color(0xFF7B8FAD),
          indicatorColor: const Color(0xFF00E5A0),
          tabs: const [
            Tab(text: 'Personal'),
            Tab(text: 'Guarantor'),
            Tab(text: 'Other'),
          ],
        ),
        actions: [
          _saving
              ? const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF00E5A0))))
              : TextButton(
              onPressed: _update,
              child: const Text('Update',
                  style: TextStyle(
                      color: Color(0xFF00E5A0),
                      fontWeight: FontWeight.w700,
                      fontSize: 15))),
        ],
      ),
      body: Form(
        key: _form,
        child: TabBarView(controller: _tab, children: [
          _personalTab(),
          _guarantorTab(),
          _otherTab(),
        ]),
      ),
    );
  }

  Widget _personalTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      _F(_name, 'Full Name', required: true),
      _F(_father, "Father's Name"),
      _F(_mobile, 'Mobile Number',
          required: true, kb: TextInputType.phone, maxLen: 10),
      _F(_altMob, 'Alternate Mobile',
          kb: TextInputType.phone, maxLen: 10),
      _Drop('Gender', _gender, const ['Male', 'Female', 'Other'],
              (v) => setState(() => _gender = v!)),
      _DateF('Date of Birth', _dob,
              (d) => setState(() => _dob = d)),
      _F(_occ, 'Occupation'),
      _F(_income, 'Monthly Income (₹)', kb: TextInputType.number),
      const _Sec('Address'),
      _F(_address, 'Full Address', maxLines: 2),
      Row(children: [
        Expanded(child: _F(_village, 'Village')),
        const SizedBox(width: 12),
        Expanded(child: _F(_city, 'City')),
      ]),
      Row(children: [
        Expanded(child: _F(_district, 'District')),
        const SizedBox(width: 12),
        Expanded(child: _F(_state, 'State')),
      ]),
      _F(_pin, 'PIN Code', kb: TextInputType.number, maxLen: 6),
      const _Sec('Documents'),
      _F(_aadhaar, 'Aadhaar Number',
          kb: TextInputType.number, maxLen: 12),
      _F(_pan, 'PAN Number', maxLen: 10),
      const SizedBox(height: 80),
    ]),
  );

  Widget _guarantorTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      const _Sec('Guarantor Information'),
      _F(_gName, 'Guarantor Full Name'),
      _F(_gMob, 'Mobile Number',
          kb: TextInputType.phone, maxLen: 10),
      _F(_gAddr, 'Address', maxLines: 2),
      _F(_gRel, 'Relationship'),
      const SizedBox(height: 80),
    ]),
  );

  Widget _otherTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      _Drop('Customer Status', _status,
          const ['Active', 'Closed', 'Pending Verification', 'Blacklisted'],
              (v) => setState(() => _status = v!)),
      _F(_notes, 'Notes / Remarks', maxLines: 5),
      const SizedBox(height: 80),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════
//  CUSTOMER DETAIL
// ═══════════════════════════════════════════════════════════════

class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;
  const CustomerDetailScreen({super.key, required this.customer});
  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  late Customer _currentCust;
  List<Loan> _loans = [];

  @override
  void initState() {
    super.initState();
    _currentCust = widget.customer;
    _tab = TabController(length: 3, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _loans = context
          .read<FinanceProvider>()
          .loansForCustomer(_currentCust.id);
    });
  }

  Future<void> _editCustomer() async {
    final res = await Navigator.push<Customer>(
      context,
      _sr(EditCustomerScreen(customer: _currentCust)),
    );
    if (res != null) {
      setState(() {
        _currentCust = res;
      });
      _reload();
    }
  }

  Future<void> _deleteCustomer() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141E2E),
        title: const Text('Delete Customer?',
            style: TextStyle(color: Color(0xFFEDF2FF))),
        content: Text(
          'This will permanently delete ${_currentCust.fullName} along with ALL associated loans, installments, and payment history.',
          style: const TextStyle(color: Color(0xFF7B8FAD)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF7B8FAD))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B6B)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await DatabaseHelper.instance.deleteCustomerCascade(_currentCust.id);
      if (mounted) {
        await context.read<FinanceProvider>().loadAll();
        Navigator.pop(context);
        _snack(context, '${_currentCust.fullName} deleted', const Color(0xFFFF6B6B));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _currentCust;
    return Scaffold(
      appBar: AppBar(
        title: Text(c.fullName, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _editCustomer,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF7B8FAD)),
            color: const Color(0xFF1A2540),
            onSelected: (val) {
              if (val == 'delete') _deleteCustomer();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_forever_rounded, color: Color(0xFFFF6B6B), size: 18),
                  SizedBox(width: 8),
                  Text('Delete Customer', style: TextStyle(color: Color(0xFFFF6B6B))),
                ]),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: const Color(0xFF00E5A0),
          unselectedLabelColor: const Color(0xFF7B8FAD),
          indicatorColor: const Color(0xFF00E5A0),
          tabs: [
            const Tab(text: 'Overview'),
            Tab(text: 'Loans (${_loans.length})'),
            const Tab(text: 'Details'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
              context, _sr(AddLoanScreen(customer: c)));
          _reload();
        },
        icon: const Icon(Icons.add_card_rounded),
        label: const Text('New Loan'),
        backgroundColor: const Color(0xFF00E5A0),
        foregroundColor: Colors.black,
      ),
      body: TabBarView(controller: _tab, children: [
        _overviewTab(c),
        _loansTab(c),
        _detailsTab(c),
      ]),
    );
  }

  Widget _overviewTab(Customer c) {
    final col = c.status == 'Active'
        ? const Color(0xFF00E5A0)
        : const Color(0xFF7B8FAD);
    final activeL = _loans.where((l) => l.status == 'Active').toList();
    final totalOut =
    activeL.fold(0.0, (s, l) => s + l.outstandingBalance);
    final totalPaid = _loans.fold(0.0, (s, l) => s + l.paidAmount);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(children: [
        // Profile
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [col.withOpacity(0.1), const Color(0xFF141E2E)]),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: col.withOpacity(0.2)),
          ),
          child: Row(children: [
            _Avatar(initials: c.initials, color: col, radius: 34),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.fullName,
                        style: const TextStyle(
                            color: Color(0xFFEDF2FF),
                            fontSize: 17,
                            fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis),
                    Text(c.mobile,
                        style: const TextStyle(
                            color: Color(0xFF7B8FAD), fontSize: 13)),
                    if (c.displayLocation.isNotEmpty)
                      Text(c.displayLocation,
                          style: const TextStyle(
                              color: Color(0xFF3D4F6B), fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    _StatusBadge(c.status, col),
                  ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _KpiCard('Active Loans',
              '${activeL.length}', const Color(0xFF00E5A0))),
          const SizedBox(width: 10),
          Expanded(child: _KpiCard('Outstanding',
              '₹${_fmtN(totalOut)}', const Color(0xFFFF6B6B))),
          const SizedBox(width: 10),
          Expanded(child: _KpiCard('Total Paid',
              '₹${_fmtN(totalPaid)}', const Color(0xFF6C63FF))),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
              child: _ActBtn(Icons.call_rounded, 'Call',
                  const Color(0xFF00E5A0),
                      () => _call(c.mobile))),
          const SizedBox(width: 10),
          Expanded(
              child: _ActBtn(Icons.chat_rounded, 'WhatsApp',
                  const Color(0xFF25D366),
                      () => _whatsApp(c.mobile))),
          const SizedBox(width: 10),
          Expanded(
              child: _ActBtn(Icons.sms_rounded, 'SMS',
                  const Color(0xFF6C63FF),
                      () => _sms(c.mobile))),
        ]),
      ]),
    );
  }

  Widget _loansTab(Customer c) {
    if (_loans.isEmpty) {
      return Center(
        child: _EmptyState(
          icon: Icons.credit_card_outlined,
          title: 'No Loans',
          subtitle: 'Create first loan for this customer',
          action: 'Create Loan',
          onAction: () async {
            await Navigator.push(
                context, _sr(AddLoanScreen(customer: c)));
            _reload();
          },
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _loans.length,
      itemBuilder: (_, i) => _LoanCard(
        loan: _loans[i],
        onReload: _reload,
      ),
    );
  }

  Widget _detailsTab(Customer c) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
    child: Column(children: [
      _InfoSection('Personal', [
        if (c.fatherName != null) _IR("Father's Name", c.fatherName!),
        _IR('Gender', c.gender ?? '-'),
        _IR('Date of Birth', c.dob ?? '-'),
        _IR('Occupation', c.occupation ?? '-'),
        if (c.monthlyIncome != null)
          _IR('Monthly Income',
              '₹${c.monthlyIncome!.toStringAsFixed(0)}'),
      ]),
      const SizedBox(height: 10),
      _InfoSection('Contact & Address', [
        _IR('Mobile', c.mobile),
        if (c.altMobile != null) _IR('Alternate', c.altMobile!),
        if (c.address != null) _IR('Address', c.address!),
        _IR('Village', c.village ?? '-'),
        _IR('City', c.city ?? '-'),
        _IR('District', c.district ?? '-'),
        _IR('State', c.state ?? '-'),
        _IR('PIN Code', c.pinCode ?? '-'),
      ]),
      const SizedBox(height: 10),
      _InfoSection('Documents', [
        _IR('Aadhaar', c.aadhaar ?? '-'),
        _IR('PAN', c.pan ?? '-'),
      ]),
      if (c.guarantorName != null) ...[
        const SizedBox(height: 10),
        _InfoSection('Guarantor', [
          _IR('Name', c.guarantorName!),
          _IR('Mobile', c.guarantorMobile ?? '-'),
          _IR('Relation', c.guarantorRelation ?? '-'),
        ]),
      ],
      const SizedBox(height: 10),
      _InfoSection('System Info', [
        _IR('Customer ID', c.id),
        _IR('Status', c.status),
        _IR('Joined', c.createdAt.substring(0, 10)),
      ]),
      const SizedBox(height: 80),
    ]),
  );
}

// ── LOAN CARD ─────────────────────────────────────────────────

class _LoanCard extends StatelessWidget {
  final Loan loan;
  final VoidCallback? onReload;
  const _LoanCard({required this.loan, this.onReload});

  Color _lc(String s) {
    switch (s) {
      case 'Active': return const Color(0xFF00E5A0);
      case 'Closed': return const Color(0xFF7B8FAD);
      case 'Settled by Override': return const Color(0xFF6C63FF);
      default: return const Color(0xFFFF6B6B);
    }
  }

  Future<void> _deleteLoan(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141E2E),
        title: const Text('Delete Loan?', style: TextStyle(color: Color(0xFFEDF2FF))),
        content: Text(
          'This will permanently delete Loan ${loan.id} along with all its installments and payment history.',
          style: const TextStyle(color: Color(0xFF7B8FAD)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF7B8FAD))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B6B)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteLoanCascade(loan.id);
      await Provider.of<FinanceProvider>(context, listen: false).loadAll();
      onReload?.call();
      _snack(context, 'Loan deleted', const Color(0xFFFF6B6B));
    }
  }

  @override
  Widget build(BuildContext context) {
    final col = _lc(loan.status);
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
            context, _sr(LoanDetailScreen(loan: loan)));
        onReload?.call();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF141E2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: col.withOpacity(0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(loan.id,
                    style: const TextStyle(
                        color: Color(0xFF3D4F6B),
                        fontSize: 11,
                        fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis)),
            _StatusBadge(loan.status, col),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF7B8FAD), size: 18),
              color: const Color(0xFF1A2540),
              onSelected: (val) {
                if (val == 'delete') _deleteLoan(context);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_forever_rounded, color: Color(0xFFFF6B6B), size: 16),
                    SizedBox(width: 8),
                    Text('Delete Loan', style: TextStyle(color: Color(0xFFFF6B6B), fontSize: 13)),
                  ]),
                ),
              ],
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _LF('Given', '₹${_fmtN(loan.amountGiven)}'),
            _LF('To Receive', '₹${_fmtN(loan.amountToReceive)}'),
            _LF('EMI', '₹${_fmtN(loan.installmentAmount)}'),
            _LF(loan.frequency,
                '${loan.completedCycles}/${loan.totalCycles}'),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Progress',
                        style: TextStyle(
                            color: Color(0xFF7B8FAD), fontSize: 11)),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: loan.progressPercent),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => LinearProgressIndicator(
                          value: v,
                          backgroundColor: const Color(0xFF243050),
                          valueColor: AlwaysStoppedAnimation<Color>(col),
                          minHeight: 8,
                        ),
                      ),
                    ),
                  ]),
            ),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('Outstanding',
                  style: TextStyle(
                      color: Color(0xFF7B8FAD), fontSize: 11)),
              Text('₹${_fmtN(loan.outstandingBalance)}',
                  style: const TextStyle(
                      color: Color(0xFFFF6B6B),
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
            ]),
          ]),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  ADD LOAN SCREEN
// ═══════════════════════════════════════════════════════════════

class AddLoanScreen extends StatefulWidget {
  final Customer customer;
  const AddLoanScreen({super.key, required this.customer});
  @override
  State<AddLoanScreen> createState() => _AddLoanScreenState();
}

class _AddLoanScreenState extends State<AddLoanScreen> {
  final _form   = GlobalKey<FormState>();
  final _given  = TextEditingController();
  final _recv   = TextEditingController();
  final _cycles = TextEditingController();
  final _notes  = TextEditingController();

  String _freq     = 'Daily';
  String _loanDate = DateTime.now().toIso8601String().substring(0, 10);

  // 👈 FIX: Smart calculation for completed installments
  String _clearedUptoDate = '';
  bool _isExisting = false;
  bool _saving     = false;
  Loan? _preview;

  List<Loan> _activeLoans = [];
  Loan? _selectedForOverride;

  @override
  void initState() {
    super.initState();
    _activeLoans = context
        .read<FinanceProvider>()
        .loansForCustomer(widget.customer.id)
        .where((l) => l.status == 'Active')
        .toList();
  }

  @override
  void dispose() {
    for (final c in [_given, _recv, _cycles, _notes]) c.dispose();
    super.dispose();
  }

  void _recalc() {
    final given  = double.tryParse(_given.text);
    final recv   = double.tryParse(_recv.text);
    final cycles = int.tryParse(_cycles.text);
    if (given == null || recv == null || cycles == null || cycles <= 0) {
      setState(() => _preview = null);
      return;
    }

    // 👈 FIX: Automatic calculation of completed installments
    int completed = 0;
    if (_isExisting && _clearedUptoDate.isNotEmpty && _loanDate.isNotEmpty) {
      try {
        final st = DateTime.tryParse(_loanDate);
        final cl = DateTime.tryParse(_clearedUptoDate);
        if (st != null && cl != null && !cl.isBefore(st)) {
          final days = cl.difference(st).inDays;
          completed = _freq == 'Daily' ? days : days ~/ 7;
        }
      } catch(_) {}
    }

    setState(() => _preview = Loan.create(
      customerId: widget.customer.id,
      amountGiven: given,
      amountToReceive: recv,
      totalCycles: cycles,
      frequency: _freq,
      loanDate: _loanDate,
      isExistingLoan: _isExisting,
      completedCycles: completed,
      notes: _notes.text.trim().ne,
    ));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _preview == null) return;

    if (_selectedForOverride != null) {
      await _showOverrideSummary();
    } else {
      await _doCreate(_preview!);
    }
  }

  Future<void> _showOverrideSummary() async {
    final old = _selectedForOverride!;
    final newRecv = double.tryParse(_recv.text) ?? 0;
    final outstanding = old.outstandingBalance;
    final cashToGive = (newRecv - outstanding).clamp(0.0, double.infinity);

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF141E2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _Handle(),
          const SizedBox(height: 18),
          const Text('Loan Override Summary',
              style: TextStyle(
                  color: Color(0xFFEDF2FF),
                  fontWeight: FontWeight.w700,
                  fontSize: 17)),
          const SizedBox(height: 4),
          Text('The old loan will be closed and replaced.',
              style: const TextStyle(
                  color: Color(0xFF7B8FAD), fontSize: 12)),
          const SizedBox(height: 20),
          _SummaryRow(
            icon: Icons.credit_card_rounded,
            iconColor: const Color(0xFFFF6B6B),
            label: 'Old Loan Outstanding',
            value: '₹${_fmtN(outstanding)}',
            valueColor: const Color(0xFFFF6B6B),
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            icon: Icons.arrow_downward_rounded,
            iconColor: const Color(0xFF6C63FF),
            label: 'New Loan (Amount to Receive)',
            value: '₹${_fmtN(newRecv)}',
            valueColor: const Color(0xFF6C63FF),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5A0).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF00E5A0).withOpacity(0.3)),
            ),
            child: _SummaryRow(
              icon: Icons.payments_rounded,
              iconColor: const Color(0xFF00E5A0),
              label: 'Cash to Give Customer',
              value: '₹${_fmtN(cashToGive)}',
              valueColor: const Color(0xFF00E5A0),
              bold: true,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFF243050)),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.info_outline_rounded,
                color: Color(0xFF7B8FAD), size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Old loan (${old.id.substring(0, 12)}…) will be permanently closed.',
                style: const TextStyle(
                    color: Color(0xFF7B8FAD), fontSize: 11),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Confirm & Replace Loan',
                  style: TextStyle(fontSize: 15)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
        ]),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    final fp = context.read<FinanceProvider>();

    final finalLoan = Loan.create(
      customerId: widget.customer.id,
      amountGiven: cashToGive,
      amountToReceive: newRecv,
      totalCycles: int.tryParse(_cycles.text) ?? 1,
      frequency: _freq,
      loanDate: _loanDate,
      parentLoanId: old.id,
      notes: _notes.text.trim().ne,
    );

    await fp.overrideLoan(oldLoan: old, newLoan: finalLoan);

    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context);
      _snack(context, 'Loan replaced successfully ✓',
          const Color(0xFF00E5A0));
    }
  }

  Future<void> _doCreate(Loan loan) async {
    setState(() => _saving = true);
    await context.read<FinanceProvider>().createLoan(loan);
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context);
      _snack(context, 'Loan created successfully ✓',
          const Color(0xFF00E5A0));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('New Loan — ${widget.customer.fullName}',
            style: const TextStyle(fontSize: 15),
            overflow: TextOverflow.ellipsis),
        actions: [
          _saving
              ? const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF00E5A0))))
              : TextButton(
              onPressed: _save,
              child: const Text('Create',
                  style: TextStyle(
                      color: Color(0xFF00E5A0),
                      fontWeight: FontWeight.w700))),
        ],
      ),
      body: Form(
        key: _form,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Toggle(
                title: 'Existing Running Loan',
                subtitle: 'Migrating from paper records?',
                value: _isExisting,
                onChanged: (v) {
                  setState(() {
                    _isExisting = v;
                    if (v) _selectedForOverride = null;
                  });
                  _recalc();
                },
              ),
              const SizedBox(height: 16),

              if (!_isExisting && _activeLoans.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2540),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _selectedForOverride != null
                          ? const Color(0xFF6C63FF)
                          : const Color(0xFF243050),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.swap_horiz_rounded,
                            color: Color(0xFF6C63FF), size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('Override an Existing Loan',
                              style: TextStyle(
                                  color: Color(0xFFEDF2FF),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ),
                        if (_selectedForOverride != null)
                          GestureDetector(
                            onTap: () => setState(
                                    () => _selectedForOverride = null),
                            child: const Icon(Icons.close_rounded,
                                color: Color(0xFF7B8FAD), size: 18),
                          ),
                      ]),
                      const SizedBox(height: 4),
                      const Text(
                          'Select a running loan to replace it with this new one.',
                          style: TextStyle(
                              color: Color(0xFF7B8FAD), fontSize: 11)),
                      const SizedBox(height: 12),
                      ..._activeLoans.map((l) {
                        final isSelected = _selectedForOverride?.id == l.id;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedForOverride =
                              isSelected ? null : l),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF6C63FF).withOpacity(0.12)
                                  : const Color(0xFF141E2E),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF6C63FF)
                                    : const Color(0xFF243050),
                              ),
                            ),
                            child: Row(children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                color: isSelected
                                    ? const Color(0xFF6C63FF)
                                    : const Color(0xFF7B8FAD),
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '₹${_fmtN(l.amountToReceive)} • ${l.frequency} • ${l.completedCycles}/${l.totalCycles} paid',
                                        style: TextStyle(
                                            color: isSelected
                                                ? const Color(0xFFEDF2FF)
                                                : const Color(0xFF7B8FAD),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12),
                                      ),
                                      Text(
                                        'Outstanding: ₹${_fmtN(l.outstandingBalance)}  •  Since ${l.loanDate}',
                                        style: const TextStyle(
                                            color: Color(0xFF3D4F6B),
                                            fontSize: 10),
                                      ),
                                    ]),
                              ),
                            ]),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              _DateF('Loan Date', _loanDate, (d) {
                setState(() => _loanDate = d);
                _recalc();
              }),
              _F(_given, 'Amount Given (₹)',
                  required: true,
                  kb: TextInputType.number,
                  onChange: (_) => _recalc()),
              _F(_recv, 'Amount to Receive (₹)',
                  required: true,
                  kb: TextInputType.number,
                  onChange: (_) => _recalc()),
              _F(_cycles, 'Number of Installments',
                  required: true,
                  kb: TextInputType.number,
                  onChange: (_) => _recalc()),
              _Drop('Collection Type', _freq,
                  const ['Daily', 'Weekly'], (v) {
                    setState(() => _freq = v!);
                    _recalc();
                  }),

              if (_isExisting) ...[
                const _Sec('Migration Details'),
                // 👈 FIX: Smart Cleared Upto Date picker replaces manual number entry
                _DateF('Cleared Upto Date', _clearedUptoDate, (d) {
                  setState(() => _clearedUptoDate = d);
                  _recalc();
                }),
                if (_clearedUptoDate.isNotEmpty && _preview != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF00E5A0), size: 16),
                        const SizedBox(width: 8),
                        Text('Calculated completed installments: ${_preview!.completedCycles}',
                            style: const TextStyle(color: Color(0xFF00E5A0), fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],

              _F(_notes, 'Notes (optional)', maxLines: 2),

              if (_preview != null) ...[
                const SizedBox(height: 8),
                _LoanPreview(
                    loan: _preview!,
                    isExisting: _isExisting,
                    overrideLoan: _selectedForOverride),
              ],

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}

// ── LOAN PREVIEW CARD ─────────────────────────────────────────

class _LoanPreview extends StatelessWidget {
  final Loan loan;
  final bool isExisting;
  final Loan? overrideLoan;
  const _LoanPreview(
      {required this.loan,
        required this.isExisting,
        this.overrideLoan});

  @override
  Widget build(BuildContext context) {
    final firstColl = loan.firstCollectionDate;
    final showOverride = overrideLoan != null;
    final outstanding = overrideLoan?.outstandingBalance ?? 0;
    final cashToGive = showOverride
        ? (loan.amountToReceive - outstanding).clamp(0.0, double.infinity)
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF00E5A0).withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF00E5A0).withOpacity(0.3)),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.calculate_rounded,
                  color: Color(0xFF00E5A0), size: 14),
              SizedBox(width: 6),
              Text('Loan Preview',
                  style: TextStyle(
                      color: Color(0xFF00E5A0),
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _PK('Amount Given', '₹${_fmtN(loan.amountGiven)}')),
              Expanded(child: _PK('To Receive', '₹${_fmtN(loan.amountToReceive)}')),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _PK('Installments', '${loan.totalCycles}')),
              Expanded(child: _PK('EMI', '₹${_fmtN(loan.installmentAmount)}')),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _PK('Loan Date', loan.loanDate)),
              Expanded(child: _PK('First Collection',
                  firstColl.toIso8601String().substring(0, 10))),
            ]),
            const SizedBox(height: 8),
            _PK('End Date', loan.endDate ?? '-'),

            if (isExisting && loan.completedAtMigration != null) ...[
              const Divider(color: Color(0xFF243050), height: 20),
              Row(children: [
                Expanded(child: _PK('Completed',
                    '${loan.completedAtMigration} installments')),
                Expanded(child: _PK('Remaining',
                    '${loan.remainingCycles} installments')),
              ]),
              const SizedBox(height: 8),
              _PK('Outstanding Balance', '₹${_fmtN(loan.outstandingBalance)}'),
            ],

            if (showOverride) ...[
              const Divider(color: Color(0xFF243050), height: 20),
              Row(children: [
                const Icon(Icons.swap_horiz_rounded,
                    color: Color(0xFF6C63FF), size: 13),
                const SizedBox(width: 5),
                const Text('Override Calculation',
                    style: TextStyle(
                        color: Color(0xFF6C63FF),
                        fontWeight: FontWeight.w600,
                        fontSize: 11)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _PK('Old Outstanding',
                    '₹${_fmtN(outstanding)}')),
                Expanded(child: _PK('Cash to Customer',
                    '₹${_fmtN(cashToGive!)}')),
              ]),
            ],
          ]),
    );
  }
}

// ── SUMMARY ROW WIDGET ────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label, value;
  final Color valueColor;
  final bool bold;
  const _SummaryRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: iconColor, size: 16),
    ),
    const SizedBox(width: 12),
    Expanded(
        child: Text(label,
            style: const TextStyle(
                color: Color(0xFF7B8FAD), fontSize: 13))),
    Text(value,
        style: TextStyle(
            color: valueColor,
            fontWeight:
            bold ? FontWeight.w800 : FontWeight.w600,
            fontSize: bold ? 16 : 14)),
  ]);
}

// ═══════════════════════════════════════════════════════════════
//  LOAN DETAIL SCREEN
// ═══════════════════════════════════════════════════════════════

class LoanDetailScreen extends StatefulWidget {
  final Loan loan;
  const LoanDetailScreen({super.key, required this.loan});
  @override
  State<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends State<LoanDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  late Loan _currentLoan;
  List<Installment> _insts = [];
  List<Payment> _pays = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _currentLoan = widget.loan;
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final fp = context.read<FinanceProvider>();
    final updated = await DatabaseHelper.instance.getLoan(_currentLoan.id);
    final i = await fp.installmentsForLoan(_currentLoan.id);
    final p = await fp.paymentsForLoan(_currentLoan.id);
    if (mounted) {
      setState(() {
        if (updated != null) _currentLoan = updated;
        _insts = i;
        _pays = p;
        _loading = false;
      });
    }
  }

  Future<void> _sharePdf() async {
    final fp = context.read<FinanceProvider>();
    final customer = fp.customerById(_currentLoan.customerId);
    if (customer == null) return;
    try {
      await LoanPdfService.share(
        context,
        loan: _currentLoan,
        customer: customer,
        installments: _insts,
        payments: _pays,
      );
    } catch (e) {
      if (mounted) _snack(context, 'PDF error: $e', const Color(0xFFFF6B6B));
    }
  }

  Future<void> _deleteLoan() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141E2E),
        title: const Text('Delete Loan?', style: TextStyle(color: Color(0xFFEDF2FF))),
        content: Text(
          'This will permanently delete Loan ${_currentLoan.id} along with all schedules and payments.',
          style: const TextStyle(color: Color(0xFF7B8FAD)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF7B8FAD))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B6B)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await DatabaseHelper.instance.deleteLoanCascade(_currentLoan.id);
      await context.read<FinanceProvider>().loadAll();
      if (mounted) {
        Navigator.pop(context);
        _snack(context, 'Loan deleted successfully', const Color(0xFFFF6B6B));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loan = _currentLoan;
    return Scaffold(
      appBar: AppBar(
        title: Text(loan.id,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            overflow: TextOverflow.ellipsis),
        actions: [
          _loading
              ? const SizedBox.shrink()
              : TextButton.icon(
            onPressed: _sharePdf,
            icon: const Icon(Icons.picture_as_pdf_rounded,
                color: Color(0xFFFF6B6B), size: 18),
            label: const Text('PDF',
                style: TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontWeight: FontWeight.w700)),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF7B8FAD)),
            color: const Color(0xFF1A2540),
            onSelected: (val) {
              if (val == 'delete') _deleteLoan();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_forever_rounded, color: Color(0xFFFF6B6B), size: 18),
                  SizedBox(width: 8),
                  Text('Delete Loan', style: TextStyle(color: Color(0xFFFF6B6B))),
                ]),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: const Color(0xFF00E5A0),
          unselectedLabelColor: const Color(0xFF7B8FAD),
          indicatorColor: const Color(0xFF00E5A0),
          tabs: [
            const Tab(text: 'Overview'),
            Tab(text: 'Schedule (${_insts.length})'),
            Tab(text: 'Payments (${_pays.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
          child:
          CircularProgressIndicator(color: Color(0xFF00E5A0)))
          : TabBarView(controller: _tab, children: [
        _overviewTab(loan),
        _scheduleTab(loan),
        _paymentsTab(),
      ]),
    );
  }

  Widget _overviewTab(Loan loan) {
    final col = loan.status == 'Active'
        ? const Color(0xFF00E5A0)
        : const Color(0xFF7B8FAD);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [col.withOpacity(0.1), const Color(0xFF141E2E)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: col.withOpacity(0.2)),
          ),
          child: Column(children: [
            Row(children: [
              _LF('Amount Given', '₹${_fmtN(loan.amountGiven)}'),
              _LF('To Receive', '₹${_fmtN(loan.amountToReceive)}'),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _LF('EMI', '₹${_fmtN(loan.installmentAmount)}'),
              _LF('Frequency', loan.frequency),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _LF('Loan Date', loan.loanDate),
              _LF('End Date', loan.endDate ?? '-'),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _LF('First Collection',
                  loan.firstCollectionDate
                      .toIso8601String()
                      .substring(0, 10)),
              _LF('Status', loan.status),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: const Color(0xFF141E2E),
              borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Row(children: [
              Expanded(child: _KpiCard('Completed',
                  '${loan.completedCycles}/${loan.totalCycles}',
                  const Color(0xFF00E5A0))),
              const SizedBox(width: 10),
              Expanded(child: _KpiCard('Paid',
                  '₹${_fmtN(loan.paidAmount)}',
                  const Color(0xFF6C63FF))),
              const SizedBox(width: 10),
              Expanded(child: _KpiCard('Outstanding',
                  '₹${_fmtN(loan.outstandingBalance)}',
                  const Color(0xFFFF6B6B))),
            ]),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: loan.progressPercent),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  backgroundColor: const Color(0xFF243050),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF00E5A0)),
                  minHeight: 10,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                  '${(loan.progressPercent * 100).toStringAsFixed(1)}% complete',
                  style: const TextStyle(
                      color: Color(0xFF00E5A0), fontSize: 11)),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _sharePdf,
            icon: const Icon(Icons.picture_as_pdf_rounded,
                color: Color(0xFFFF6B6B), size: 18),
            label: const Text('Export Loan Summary PDF',
                style: TextStyle(color: Color(0xFFFF6B6B))),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFF6B6B)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 80),
      ]),
    );
  }

  Widget _scheduleTab(Loan loan) {
    if (_insts.isEmpty) {
      return const Center(child: Text('No schedule',
          style: TextStyle(color: Color(0xFF7B8FAD))));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _insts.length,
      itemBuilder: (_, i) => _InstRow(
        inst: _insts[i],
        onCollect: _insts[i].status != 'Paid'
            ? () => _collectSheet(_insts[i], loan)
            : null,
      ),
    );
  }

  Widget _paymentsTab() {
    if (_pays.isEmpty) {
      return const Center(child: Text('No payments yet',
          style: TextStyle(color: Color(0xFF7B8FAD))));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _pays.length,
      itemBuilder: (_, i) {
        final p = _pays[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
              color: const Color(0xFF141E2E),
              borderRadius: BorderRadius.circular(11)),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: const Color(0xFF00E5A0).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(7)),
              child: const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF00E5A0), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.receiptNumber,
                        style: const TextStyle(
                            color: Color(0xFFEDF2FF),
                            fontSize: 12,
                            fontFamily: 'monospace'),
                        overflow: TextOverflow.ellipsis),
                    Text('${p.date} ${p.time} • ${p.paymentMethod}',
                        style: const TextStyle(
                            color: Color(0xFF7B8FAD), fontSize: 11)),
                  ]),
            ),
            Text('₹${_fmtN(p.amount)}',
                style: const TextStyle(
                    color: Color(0xFF00E5A0),
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ]),
        );
      },
    );
  }

  Future<void> _collectSheet(Installment inst, Loan loan) async {
    String method = 'Cash';
    final confirmed = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141E2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 12),
        child: StatefulBuilder(builder: (_, ss) {
          final c = context.read<FinanceProvider>()
              .customerById(inst.customerId);
          return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Handle(),
                const SizedBox(height: 14),
                Row(children: [
                  _Avatar(
                      initials: c?.initials ?? '?',
                      color: const Color(0xFF00E5A0),
                      radius: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c?.fullName ?? 'Unknown',
                              style: const TextStyle(
                                  color: Color(0xFFEDF2FF),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15),
                              overflow: TextOverflow.ellipsis),
                          Text(
                              'Installment #${inst.installmentNumber}  •  Due ${inst.dueDate}',
                              style: const TextStyle(
                                  color: Color(0xFF7B8FAD), fontSize: 12)),
                        ]),
                  ),
                ]),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5A0).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF00E5A0).withOpacity(0.3)),
                  ),
                  child: Column(children: [
                    const Text('Collection Amount',
                        style: TextStyle(
                            color: Color(0xFF7B8FAD), fontSize: 11)),
                    const SizedBox(height: 4),
                    Text('₹${inst.amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: Color(0xFF00E5A0),
                            fontSize: 34,
                            fontWeight: FontWeight.w800)),
                  ]),
                ),
                const SizedBox(height: 16),
                const Text('Payment Method',
                    style: TextStyle(
                        color: Color(0xFF7B8FAD), fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children:
                  ['Cash', 'UPI', 'Bank Transfer', 'Cheque'].map((m) {
                    final sel = method == m;
                    return GestureDetector(
                      onTap: () => ss(() => method = m),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 9),
                        decoration: BoxDecoration(
                          color: sel
                              ? const Color(0xFF00E5A0).withOpacity(0.12)
                              : const Color(0xFF1A2540),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: sel
                                ? const Color(0xFF00E5A0)
                                : const Color(0xFF243050),
                          ),
                        ),
                        child: Text(m,
                            style: TextStyle(
                                color: sel
                                    ? const Color(0xFF00E5A0)
                                    : const Color(0xFF7B8FAD),
                                fontSize: 13,
                                fontWeight: sel
                                    ? FontWeight.w600
                                    : FontWeight.w400)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, method),
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Confirm Collection',
                        style: TextStyle(fontSize: 15)),
                  ),
                ),
              ]);
        }),
      ),
    );

    if (confirmed != null && mounted) {
      try {
        final updatedLoan = await DatabaseHelper.instance.getLoan(loan.id);
        if (updatedLoan == null) return;
        final pay = await context.read<FinanceProvider>().collectPayment(
          loan: updatedLoan,
          installment: inst,
          paymentMethod: confirmed,
        );
        _load();
        if (mounted) {
          _snack(context,
              '₹${inst.amount.toStringAsFixed(0)} collected — ${pay.receiptNumber}',
              const Color(0xFF00E5A0));
        }
      } catch (e) {
        if (mounted) {
          _snack(context, 'Error: $e', const Color(0xFFFF6B6B));
        }
      }
    }
  }
}

class _InstRow extends StatelessWidget {
  final Installment inst;
  final VoidCallback? onCollect;
  const _InstRow({required this.inst, this.onCollect});

  Color _col(String s) {
    switch (s) {
      case 'Paid': return const Color(0xFF00E5A0);
      case 'Overdue': return const Color(0xFFFF6B6B);
      default: return const Color(0xFF7B8FAD);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = inst.effectiveStatus;
    final col = _col(status);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141E2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: col.withOpacity(0.2)),
      ),
      child: Row(children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: col.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6)),
          child: Text('${inst.installmentNumber}',
              style: TextStyle(
                  color: col, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(inst.dueDate,
                style: const TextStyle(
                    color: Color(0xFFEDF2FF), fontSize: 12)),
            Text(status,
                style: TextStyle(color: col, fontSize: 11)),
          ]),
        ),
        Text('₹${_fmtN(inst.amount)}',
            style: TextStyle(
                color: inst.status == 'Paid'
                    ? const Color(0xFF3D4F6B)
                    : const Color(0xFFEDF2FF),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                decoration: inst.status == 'Paid'
                    ? TextDecoration.lineThrough
                    : null)),
        if (onCollect != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onCollect,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: const Color(0xFF00E5A0).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(7)),
              child: const Text('Collect',
                  style: TextStyle(
                      color: Color(0xFF00E5A0),
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ] else
          const Icon(Icons.check_circle, color: Color(0xFF00E5A0), size: 17),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SHARED FORM WIDGETS
// ═══════════════════════════════════════════════════════════════

class _F extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final bool required;
  final TextInputType kb;
  final int? maxLines, maxLen;
  final ValueChanged<String>? onChange;

  const _F(this.ctrl, this.label,
      {this.required = false,
        this.kb = TextInputType.text,
        this.maxLines = 1,
        this.maxLen,
        this.onChange});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: ctrl,
      keyboardType: kb,
      maxLines: maxLines,
      maxLength: maxLen,
      onChanged: onChange,
      style: const TextStyle(color: Color(0xFFEDF2FF)),
      decoration:
      InputDecoration(labelText: label, counterText: ''),
      validator: required
          ? (v) => v == null || v.trim().isEmpty
          ? '$label is required'
          : null
          : null,
    ),
  );
}

class _Drop extends StatelessWidget {
  final String label, value;
  final List<String> items;
  final ValueChanged<String?> onChange;
  const _Drop(this.label, this.value, this.items, this.onChange);

  @override
  Widget build(BuildContext context) {
    final safeValue = items.contains(value) ? value : (items.isNotEmpty ? items.first : null);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: safeValue,
        onChanged: onChange,
        decoration: InputDecoration(labelText: label),
        dropdownColor: const Color(0xFF1A2540),
        style: const TextStyle(color: Color(0xFFEDF2FF)),
        items: items
            .map((e) => DropdownMenuItem<String>(
          value: e,
          child: Text(e, style: const TextStyle(color: Color(0xFFEDF2FF))),
        ))
            .toList(),
      ),
    );
  }
}

class _DateF extends StatelessWidget {
  final String label, value;
  final ValueChanged<String> onPicked;
  const _DateF(this.label, this.value, this.onPicked);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () async {
      final picked = await showDatePicker(
        context: context,
        initialDate: value.isNotEmpty
            ? DateTime.tryParse(value) ?? DateTime.now()
            : DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2040),
        builder: (c, child) => Theme(
          data: Theme.of(c).copyWith(
              colorScheme: Theme.of(c).colorScheme.copyWith(
                  primary: const Color(0xFF00E5A0),
                  onPrimary: Colors.black)),
          child: child!,
        ),
      );
      if (picked != null) {
        onPicked(picked.toIso8601String().substring(0, 10));
      }
    },
    child: Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: const Color(0xFF141E2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF243050))),
        child: Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Color(0xFF7B8FAD), fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(value.isEmpty ? 'Tap to select' : value,
                      style: TextStyle(
                          color: value.isEmpty
                              ? const Color(0xFF3D4F6B)
                              : const Color(0xFFEDF2FF),
                          fontSize: 14)),
                ]),
          ),
          const Icon(Icons.calendar_month_rounded,
              color: Color(0xFF7B8FAD), size: 18),
        ]),
      ),
    ),
  );
}

class _Toggle extends StatelessWidget {
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Toggle(
      {required this.title,
        required this.subtitle,
        required this.value,
        required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: value
          ? const Color(0xFF6C63FF).withOpacity(0.08)
          : const Color(0xFF141E2E),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
          color: value
              ? const Color(0xFF6C63FF).withOpacity(0.4)
              : const Color(0xFF243050)),
    ),
    child: Row(children: [
      Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Color(0xFFEDF2FF),
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                Text(subtitle,
                    style: const TextStyle(
                        color: Color(0xFF7B8FAD), fontSize: 11)),
              ])),
      Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF6C63FF)),
    ]),
  );
}

class _Sec extends StatelessWidget {
  final String text;
  const _Sec(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 8),
    child: Text(text,
        style: const TextStyle(
            color: Color(0xFF00E5A0),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4)),
  );
}

// ═══════════════════════════════════════════════════════════════
//  SHARED UI WIDGETS
// ═══════════════════════════════════════════════════════════════

class _Avatar extends StatelessWidget {
  final String initials;
  final Color color;
  final double radius;
  const _Avatar(
      {required this.initials, required this.color, this.radius = 18});
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: color.withOpacity(0.15),
    child: Text(initials,
        style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: radius * 0.65)),
  );
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6)),
    child: Text(label,
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.w600)),
  );
}

class _InfoSection extends StatelessWidget {
  final String title;
  final List<Widget> rows;
  const _InfoSection(this.title, this.rows);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
        color: const Color(0xFF141E2E),
        borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: const TextStyle(
              color: Color(0xFF00E5A0),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4)),
      const SizedBox(height: 10),
      ...rows,
    ]),
  );
}

class _IR extends StatelessWidget {
  final String label, value;
  const _IR(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
          width: 110,
          child: Text(label,
              style: const TextStyle(
                  color: Color(0xFF7B8FAD), fontSize: 12))),
      Expanded(
          child: Text(value,
              style: const TextStyle(
                  color: Color(0xFFEDF2FF), fontSize: 12))),
    ]),
  );
}

class _KpiCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _KpiCard(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 15),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      Text(label,
          style: const TextStyle(
              color: Color(0xFF7B8FAD), fontSize: 10)),
    ]),
  );
}

class _ActBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActBtn(this.icon, this.label, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25))),
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

class _LF extends StatelessWidget {
  final String label, value;
  const _LF(this.label, this.value);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              color: Color(0xFF7B8FAD), fontSize: 10)),
      Text(value,
          style: const TextStyle(
              color: Color(0xFFEDF2FF),
              fontWeight: FontWeight.w600,
              fontSize: 13),
          overflow: TextOverflow.ellipsis),
    ]),
  );
}

class _PK extends StatelessWidget {
  final String label, value;
  const _PK(this.label, this.value);
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFF7B8FAD), fontSize: 11)),
        Text(value,
            style: const TextStyle(
                color: Color(0xFFEDF2FF),
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ]);
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8)),
    child: Text(label,
        style: TextStyle(
            color: color, fontWeight: FontWeight.w700, fontSize: 12)),
  );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final String? action;
  final VoidCallback? onAction;
  const _EmptyState(
      {required this.icon,
        required this.title,
        required this.subtitle,
        this.action,
        this.onAction});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: const Color(0xFF243050)),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  color: Color(0xFFEDF2FF),
                  fontWeight: FontWeight.w700,
                  fontSize: 16)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(
                  color: Color(0xFF7B8FAD), fontSize: 13)),
          if (action != null) ...[
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onAction, child: Text(action!)),
          ],
        ]),
  );
}

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
          color: const Color(0xFF243050),
          borderRadius: BorderRadius.circular(2)),
    ),
  );
}

// ── UTILS ────────────────────────────────────────────────────

String _fmtN(double v) {
  if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
  if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  return v.toStringAsFixed(0);
}

void _snack(BuildContext ctx, String msg, Color color) {
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(color: Color(0xFFEDF2FF))),
    backgroundColor: const Color(0xFF141E2E),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    showCloseIcon: true,
    closeIconColor: color,
  ));
}

Future<void> _call(String mobile) async {
  if (mobile.isEmpty) return;
  final uri = Uri.parse('tel:$mobile');
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}

Future<void> _whatsApp(String mobile) async {
  if (mobile.isEmpty) return;
  final clean = mobile.replaceAll(RegExp(r'\D'), '');
  final number = clean.startsWith('91') ? clean : '91$clean';
  final uri = Uri.parse('https://wa.me/$number');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Future<void> _sms(String mobile) async {
  if (mobile.isEmpty) return;
  final uri = Uri.parse('sms:$mobile');
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}

Route<T> _sr<T>(Widget page) => PageRouteBuilder<T>(
  pageBuilder: (_, a, __) => page,
  transitionsBuilder: (_, a, __, child) => SlideTransition(
    position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
    child: child,
  ),
  transitionDuration: const Duration(milliseconds: 320),
);

extension _SE on String {
  String? get ne => trim().isEmpty ? null : trim();
}