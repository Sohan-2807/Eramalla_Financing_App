import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'customer_loan_modules.dart';
import 'customers_view.dart'; // FIXED: Added import to resolve the CustomerDetailScreen visibility

class CustomerRegistryScreen extends StatefulWidget {
  const CustomerRegistryScreen({super.key});

  @override
  State<CustomerRegistryScreen> createState() => _CustomerRegistryScreenState();
}

class _CustomerRegistryScreenState extends State<CustomerRegistryScreen> {
  // FIXED: Converted state lists from raw dynamic Maps to strongly typed Customer models
  List<Customer> _allCustomers = [];
  List<Customer> _filteredCustomers = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshCustomers();
  }

  Future<void> _refreshCustomers() async {
    // FIXED: Swapped out getCustomers() for the actual database method getAllCustomers()
    final data = await DatabaseHelper.instance.getAllCustomers();
    setState(() {
      _allCustomers = data;
      _filteredCustomers = data;
    });
  }

  void _filterCustomers(String query) {
    if (query.isEmpty) {
      setState(() => _filteredCustomers = _allCustomers);
    } else {
      setState(() {
        _filteredCustomers = _allCustomers.where((customer) {
          // FIXED: Adjusted search lookup to read the proper fullName model parameter
          final name = customer.fullName.toLowerCase();
          return name.contains(query.toLowerCase());
        }).toList();
      });
    }
  }

  void _showAddCustomerSheet() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Add New Customer", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: Colors.black),
                decoration: const InputDecoration(labelText: 'Customer Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.black),
                decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: Colors.black),
                decoration: const InputDecoration(labelText: 'Address (e.g., Kurnool)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () async {
                    if (nameCtrl.text.isNotEmpty) {
                      // FIXED: Configured object initialization sequence via the required Customer constructor fields
                      final newCustomer = Customer(
                        id: Customer.generateId(),
                        fullName: nameCtrl.text.trim(),
                        mobile: phoneCtrl.text.trim(),
                        address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                        createdAt: DateTime.now().toIso8601String(),
                      );

                      // FIXED: Swapped addCustomer() for insertCustomer()
                      await DatabaseHelper.instance.insertCustomer(newCustomer);
                      _refreshCustomers();
                      Navigator.pop(context);
                    }
                  },
                  child: const Text("Save Customer", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Customer Directory'),
      ),
      body: Column(
        children: [
          Container(
            color: Theme.of(context).appBarTheme.backgroundColor,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterCustomers,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                hintText: 'Search by name...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Expanded(
            child: _filteredCustomers.isEmpty
                ? const Center(child: Text("No customers found.", style: TextStyle(color: Colors.white54)))
                : ListView.builder(
              itemCount: _filteredCustomers.length,
              itemBuilder: (context, index) {
                final customer = _filteredCustomers[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                      child: Text(
                        // FIXED: Replaced unsafe string indexing with the model's auto-generated initials tracker
                        customer.initials,
                        style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                    // FIXED: Replaced map bracket index strings with dot property references
                    title: Text(customer.fullName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text("${customer.mobile} • ${customer.address ?? 'No Address'}", style: const TextStyle(color: Colors.white60)),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () {
                      // FIXED: Corrected view targeting reference to route to CustomerDetailScreen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CustomerDetailScreen(customer: customer),
                        ),
                      ).then((_) => _refreshCustomers());
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCustomerSheet,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}