import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'finance_provider.dart';
import 'customer_loan_modules.dart';
import 'database_helper.dart';

// ═══════════════════════════════════════════════════════════════
//  SETTINGS  —  Business Profile + Backup only
// ═══════════════════════════════════════════════════════════════

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});
  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  String _businessName = 'Eramalla Finance';
  String _ownerName    = '';
  String _phone        = '';
  String _address      = '';
  bool   _autoBackup   = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _businessName = p.getString('businessName') ?? 'Eramalla Finance';
      _ownerName    = p.getString('ownerName')    ?? '';
      _phone        = p.getString('phone')        ?? '';
      _address      = p.getString('address')      ?? '';
      _autoBackup   = p.getBool('autoBackup')     ?? true;
    });
  }

  Future<void> _save(String key, dynamic val) async {
    final p = await SharedPreferences.getInstance();
    if (val is bool)   await p.setBool(key, val);
    if (val is String) await p.setString(key, val);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          // ── Business card ─────────────────────────────────
          _buildBusinessCard(),
          const SizedBox(height: 16),

          // ── Quick stats ───────────────────────────────────
          _buildStats(),
          const SizedBox(height: 16),

          // ── BUSINESS PROFILE ──────────────────────────────
          _Group('Business Profile', [
            _Tile(
              icon: Icons.storefront_rounded,
              color: const Color(0xFF00E5A0),
              title: 'Business Name',
              sub: _businessName,
              onTap: () => _edit('Business Name', _businessName, (v) async {
                setState(() => _businessName = v);
                await _save('businessName', v);
              }),
            ),
            _Tile(
              icon: Icons.person_rounded,
              color: const Color(0xFF6C63FF),
              title: 'Owner Name',
              sub: _ownerName.isEmpty ? 'Not set' : _ownerName,
              onTap: () => _edit('Owner Name', _ownerName, (v) async {
                setState(() => _ownerName = v);
                await _save('ownerName', v);
              }),
            ),
            _Tile(
              icon: Icons.phone_rounded,
              color: const Color(0xFF4FC3F7),
              title: 'Phone Number',
              sub: _phone.isEmpty ? 'Not set' : _phone,
              onTap: () => _edit('Phone Number', _phone, (v) async {
                setState(() => _phone = v);
                await _save('phone', v);
              }, kb: TextInputType.phone),
            ),
            _Tile(
              icon: Icons.location_on_rounded,
              color: const Color(0xFFFFB800),
              title: 'Business Address',
              sub: _address.isEmpty ? 'Not set' : _address,
              onTap: () => _edit('Business Address', _address, (v) async {
                setState(() => _address = v);
                await _save('address', v);
              }),
            ),
          ]),
          const SizedBox(height: 12),

          // ── BACKUP & RESTORE ──────────────────────────────
          _Group('Backup & Restore', [
            _SwTile(
              icon: Icons.sync_rounded,
              color: const Color(0xFF4FC3F7),
              title: 'Auto Backup',
              sub: 'Automatically backup data daily',
              value: _autoBackup,
              onChanged: (v) async {
                setState(() => _autoBackup = v);
                await _save('autoBackup', v);
              },
            ),
            _Tile(
              icon: Icons.upload_rounded,
              color: const Color(0xFF00E5A0),
              title: 'Backup Now',
              sub: 'Create encrypted backup file on device',
              onTap: _doBackup,
            ),
            _Tile(
              icon: Icons.download_rounded,
              color: const Color(0xFFFFB800),
              title: 'Restore Backup',
              sub: 'Import from latest backup file',
              onTap: _doRestore,
            ),
            _Tile(
              icon: Icons.folder_open_rounded,
              color: const Color(0xFF6C63FF),
              title: 'View Backups',
              sub: 'Browse and delete backup files',
              onTap: _viewBackups,
            ),
          ]),
          const SizedBox(height: 12),

          // ── ABOUT ─────────────────────────────────────────
          _Group('About', [
            _Tile(
              icon: Icons.info_outline_rounded,
              color: const Color(0xFF7B8FAD),
              title: 'App Version',
              sub: '2.0.0  •  Eramalla Finance',
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 24),

          // Footer
          Center(
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF00E5A0), Color(0xFF6C63FF)]),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.currency_rupee,
                      color: Colors.black, size: 15),
                ),
                const SizedBox(width: 8),
                const Text('Eramalla Finance',
                    style: TextStyle(
                        color: Color(0xFF00E5A0),
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ]),
              const SizedBox(height: 4),
              const Text('Finance Collection Management System',
                  style: TextStyle(color: Color(0xFF3D4F6B), fontSize: 11)),
              const Text('Version 2.0.0',
                  style: TextStyle(color: Color(0xFF3D4F6B), fontSize: 10)),
            ]),
          ),
        ],
      ),
    );
  }

  // ── HEADER CARD ───────────────────────────────────────────

  Widget _buildBusinessCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0D2A20), Color(0xFF131830)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFF00E5A0).withOpacity(0.2)),
    ),
    child: Row(children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF00E5A0), Color(0xFF6C63FF)]),
          borderRadius: BorderRadius.circular(13),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF00E5A0).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: const Icon(Icons.currency_rupee, color: Colors.black, size: 26),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_businessName,
                  style: const TextStyle(
                      color: Color(0xFFEDF2FF),
                      fontWeight: FontWeight.w800,
                      fontSize: 17),
                  overflow: TextOverflow.ellipsis),
              if (_ownerName.isNotEmpty)
                Text(_ownerName,
                    style: const TextStyle(
                        color: Color(0xFF7B8FAD), fontSize: 13)),
              if (_phone.isNotEmpty)
                Text(_phone,
                    style: const TextStyle(
                        color: Color(0xFF3D4F6B), fontSize: 12)),
              if (_address.isNotEmpty)
                Text(_address,
                    style: const TextStyle(
                        color: Color(0xFF3D4F6B), fontSize: 11),
                    overflow: TextOverflow.ellipsis),
            ]),
      ),
      GestureDetector(
        onTap: () => _edit('Business Name', _businessName, (v) async {
          setState(() => _businessName = v);
          await _save('businessName', v);
        }),
        child: const Icon(Icons.edit_rounded,
            color: Color(0xFF7B8FAD), size: 18),
      ),
    ]),
  );

  Widget _buildStats() => Consumer<FinanceProvider>(builder: (_, fp, __) {
    final s = fp.stats;
    return Row(children: [
      Expanded(child: _StatMini('Customers',
          '${s['totalCustomers'] ?? 0}', const Color(0xFF6C63FF))),
      const SizedBox(width: 10),
      Expanded(child: _StatMini('Active Loans',
          '${s['activeLoans'] ?? 0}', const Color(0xFF00E5A0))),
      const SizedBox(width: 10),
      Expanded(child: _StatMini('Overdue',
          '${s['overdueCount'] ?? 0}', const Color(0xFFFF6B6B))),
    ]);
  });

  // ── ACTIONS ──────────────────────────────────────────────

  Future<void> _edit(
      String label,
      String current,
      Future<void> Function(String) onSave, {
        TextInputType kb = TextInputType.text,
      }) async {
    final ctrl = TextEditingController(text: current);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141E2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 20, right: 20, top: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _handle(),
          const SizedBox(height: 18),
          Text('Edit $label',
              style: const TextStyle(
                  color: Color(0xFFEDF2FF),
                  fontWeight: FontWeight.w700,
                  fontSize: 16)),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: kb,
            style: const TextStyle(color: Color(0xFFEDF2FF)),
            decoration: InputDecoration(labelText: label),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await onSave(ctrl.text.trim());
              },
              child: const Text('Save'),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _doBackup() async {
    try {
      _showLoading('Creating backup…');
      final db        = DatabaseHelper.instance;
      final customers = await db.getAllCustomers();
      final loans     = await db.getAllLoans();
      final expenses  = await db.getAllExpenses();

      final allInst = <Map<String, dynamic>>[];
      final allPay  = <Map<String, dynamic>>[];
      for (final l in loans) {
        allInst.addAll(
            (await db.getInstallmentsByLoan(l.id)).map((i) => i.toMap()));
        allPay.addAll(
            (await db.getPaymentsByLoan(l.id)).map((p) => p.toMap()));
      }

      final payload = {
        'version':      '2.0',
        'appName':      'Eramalla',
        'timestamp':    DateTime.now().toIso8601String(),
        'businessName': _businessName,
        'counts': {
          'customers':    customers.length,
          'loans':        loans.length,
          'installments': allInst.length,
          'payments':     allPay.length,
          'expenses':     expenses.length,
        },
        'customers':    customers.map((c) => c.toMap()).toList(),
        'loans':        loans.map((l) => l.toMap()).toList(),
        'installments': allInst,
        'payments':     allPay,
        'expenses':     expenses.map((e) => e.toMap()).toList(),
      };

      final dir  = await getApplicationDocumentsDirectory();
      final ts   = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/eramalla_backup_$ts.json');
      await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(payload));

      if (mounted) {
        Navigator.of(context).pop(); // close loading
        _toast(
            '✓ Backup created — ${customers.length} customers, ${loans.length} loans',
            const Color(0xFF00E5A0));
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _toast('Backup failed: $e', const Color(0xFFFF6B6B));
      }
    }
  }

  Future<void> _doRestore() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF141E2E),
        title: const Text('Restore Backup',
            style: TextStyle(color: Color(0xFFEDF2FF))),
        content: const Text(
            'This will import data from your latest backup.\n'
                'Existing data will NOT be deleted.\n\nContinue?',
            style: TextStyle(color: Color(0xFF7B8FAD), fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restore')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) =>
      f.path.contains('eramalla_backup_') &&
          f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));

      if (files.isEmpty) {
        _toast('No backup files found', const Color(0xFFFFB800));
        return;
      }

      _showLoading('Restoring…');
      final raw  = await files.first.readAsString();
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final db   = DatabaseHelper.instance;

      for (final m in (data['customers'] as List)) {
        await db.insertCustomer(Customer.fromMap(m as Map<String, dynamic>));
      }
      for (final m in (data['loans'] as List)) {
        await db.insertLoan(Loan.fromMap(m as Map<String, dynamic>));
      }
      for (final m in (data['expenses'] as List? ?? [])) {
        await db.insertExpense(Expense.fromMap(m as Map<String, dynamic>));
      }

      if (mounted) {
        await context.read<FinanceProvider>().loadAll();
        Navigator.of(context).pop();
        _toast('✓ Restore complete', const Color(0xFF00E5A0));
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _toast('Restore failed: $e', const Color(0xFFFF6B6B));
      }
    }
  }

  Future<void> _viewBackups() async {
    final dir = await getApplicationDocumentsDirectory();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) =>
    f.path.contains('eramalla_backup_') &&
        f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141E2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scroll) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(children: [
            _handle(),
            const SizedBox(height: 16),
            const Text('Saved Backups',
                style: TextStyle(
                    color: Color(0xFFEDF2FF),
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
            const SizedBox(height: 12),
            Expanded(
              child: files.isEmpty
                  ? const Center(
                  child: Text('No backups found',
                      style: TextStyle(color: Color(0xFF7B8FAD))))
                  : ListView.builder(
                controller: scroll,
                itemCount: files.length,
                itemBuilder: (_, i) {
                  final f    = files[i];
                  final name = f.path.split('/').last;
                  final size =
                      '${(f.statSync().size / 1024).toStringAsFixed(1)} KB';
                  return ListTile(
                    leading: const Icon(Icons.backup_rounded,
                        color: Color(0xFF00E5A0)),
                    title: Text(name,
                        style: const TextStyle(
                            color: Color(0xFFEDF2FF), fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                    subtitle: Text(size,
                        style: const TextStyle(
                            color: Color(0xFF7B8FAD), fontSize: 10)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Color(0xFFFF6B6B), size: 18),
                      onPressed: () async {
                        await f.delete();
                        Navigator.pop(context);
                        _toast('Backup deleted',
                            const Color(0xFF7B8FAD));
                      },
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showLoading(String msg) => showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF141E2E),
      content: Row(children: [
        const CircularProgressIndicator(color: Color(0xFF00E5A0)),
        const SizedBox(width: 16),
        Text(msg, style: const TextStyle(color: Color(0xFFEDF2FF))),
      ]),
    ),
  );

  void _toast(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Color(0xFFEDF2FF))),
      backgroundColor: const Color(0xFF141E2E),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      showCloseIcon: true,
      closeIconColor: color,
    ));
  }

  Widget _handle() => Center(
    child: Container(
      width: 40, height: 4,
      decoration: BoxDecoration(
          color: const Color(0xFF243050),
          borderRadius: BorderRadius.circular(2)),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
//  WIDGETS
// ─────────────────────────────────────────────────────────────

class _Group extends StatelessWidget {
  final String title;
  final List<Widget> items;
  const _Group(this.title, this.items);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(title,
            style: const TextStyle(
                color: Color(0xFF00E5A0),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      ),
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141E2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF243050)),
        ),
        child: Column(
          children: List.generate(items.length, (i) => Column(children: [
            items[i],
            if (i < items.length - 1)
              const Divider(color: Color(0xFF1A2540), height: 0, indent: 56),
          ])),
        ),
      ),
    ],
  );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, sub;
  final VoidCallback onTap;

  const _Tile({
    required this.icon,
    required this.color,
    required this.title,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
    leading: Container(
      width: 34, height: 34,
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(9)),
      child: Icon(icon, color: color, size: 17),
    ),
    title: Text(title,
        style: const TextStyle(
            color: Color(0xFFEDF2FF),
            fontSize: 13,
            fontWeight: FontWeight.w500)),
    subtitle: Text(sub,
        style: const TextStyle(color: Color(0xFF7B8FAD), fontSize: 11),
        overflow: TextOverflow.ellipsis),
    trailing: const Icon(Icons.chevron_right_rounded,
        color: Color(0xFF3D4F6B), size: 18),
    onTap: onTap,
    dense: true,
  );
}

class _SwTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, sub;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SwTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.sub,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
    leading: Container(
      width: 34, height: 34,
      decoration: BoxDecoration(
          color: (value ? color : const Color(0xFF7B8FAD)).withOpacity(0.12),
          borderRadius: BorderRadius.circular(9)),
      child: Icon(icon,
          color: value ? color : const Color(0xFF7B8FAD), size: 17),
    ),
    title: Text(title,
        style: const TextStyle(
            color: Color(0xFFEDF2FF),
            fontSize: 13,
            fontWeight: FontWeight.w500)),
    subtitle: Text(sub,
        style: const TextStyle(color: Color(0xFF7B8FAD), fontSize: 11),
        overflow: TextOverflow.ellipsis),
    trailing: Transform.scale(
      scale: 0.82,
      child: Switch(value: value, onChanged: onChanged, activeColor: color),
    ),
    dense: true,
  );
}

class _StatMini extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatMini(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w800, fontSize: 20)),
      Text(label,
          style: const TextStyle(color: Color(0xFF7B8FAD), fontSize: 10)),
    ]),
  );
}
