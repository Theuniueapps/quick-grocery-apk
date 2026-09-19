import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GroceryApp());
}

class GroceryApp extends StatelessWidget {
  const GroceryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Local Grocery',
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      home: FutureBuilder(
        future: Firebase.initializeApp(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'Firebase Error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            );
          }
          return const RoleSelectionScreen();
        },
      ),
    );
  }
}

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quick Grocery')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.shopping_cart),
              label: const Text('Customer Store'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomerCatalogScreen()),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text('Admin / Store Owner'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _nameCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();

  void _addItem() async {
    final name = _nameCtrl.text.trim();
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0.0;
    final unit = _unitCtrl.text.trim();

    if (name.isNotEmpty && rate > 0) {
      await FirebaseFirestore.instance.collection('products').add({
        'name': name,
        'price': rate,
        'unit': unit.isEmpty ? 'item' : unit,
      });
      _nameCtrl.clear();
      _rateCtrl.clear();
      _unitCtrl.clear();
      if (mounted) Navigator.pop(context);
    }
  }

  void _openAddModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 16,
          right: 16,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Item Name')),
            TextField(controller: _rateCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Rate / Price')),
            TextField(controller: _unitCtrl, decoration: const InputDecoration(labelText: 'Unit (e.g. 1 kg, 500g, 1 piece)')),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _addItem, child: const Text('Save Item')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Console'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Incoming Orders'), Tab(text: 'My Items')],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _openAddModal,
          child: const Icon(Icons.add),
        ),
        body: TabBarView(
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('orders').orderBy('timestamp', descending: true).snapshots(),
              builder: (ctx, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final orders = snapshot.data!.docs;
                if (orders.isEmpty) return const Center(child: Text('No orders placed yet.'));

                return ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (ctx, i) {
                    final data = orders[i].data() as Map<String, dynamic>;
                    final items = (data['items'] as List?) ?? [];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text('${data['customerName']} - ₹${data['total']}'),
                        subtitle: Text('Phone: ${data['phone']}\nAddress: ${data['address']}\nItems: ' +
                            items.map((e) => '${e['name']} (${e['quantity']}x)').join(', ')),
                        trailing: DropdownButton<String>(
                          value: data['status'] ?? 'Pending',
                          items: ['Pending', 'Purchased', 'Delivered'].map((status) {
                            return DropdownMenuItem(value: status, child: Text(status));
                          }).toList(),
                          onChanged: (newStatus) {
                            if (newStatus != null) {
                              orders[i].reference.update({'status': newStatus});
                            }
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('products').snapshots(),
              builder: (ctx, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final products = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (ctx, i) {
                    final item = products[i].data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(item['name']),
                      subtitle: Text('₹${item['price']} / ${item['unit']}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => products[i].reference.delete(),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class CustomerCatalogScreen extends StatefulWidget {
  const CustomerCatalogScreen({super.key});

  @override
  State<CustomerCatalogScreen> createState() => _CustomerCatalogScreenState();
}

class _CustomerCatalogScreenState extends State<CustomerCatalogScreen> {
  final Map<String, int> _cart = {};

  double _calculateTotal(List<QueryDocumentSnapshot> docs) {
    double total = 0.0;
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final qty = _cart[doc.id] ?? 0;
      total += (data['price'] as num) * qty;
    }
    return total;
  }

  void _checkout(List<QueryDocumentSnapshot> docs) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delivery Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Your Name')),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone Number')),
            TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Delivery Address')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final orderedItems = [];
              for (var doc in docs) {
                final qty = _cart[doc.id] ?? 0;
                if (qty > 0) {
                  final data = doc.data() as Map<String, dynamic>;
                  orderedItems.add({
                    'name': data['name'],
                    'price': data['price'],
                    'quantity': qty,
                  });
                }
              }

              if (orderedItems.isEmpty || nameCtrl.text.isEmpty) return;

              await FirebaseFirestore.instance.collection('orders').add({
                'customerName': nameCtrl.text.trim(),
                'phone': phoneCtrl.text.trim(),
                'address': addressCtrl.text.trim(),
                'items': orderedItems,
                'total': _calculateTotal(docs),
                'status': 'Pending',
                'timestamp': FieldValue.serverTimestamp(),
              });

              setState(() => _cart.clear());
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Order placed!')),
                );
              }
            },
            child: const Text('Submit Order'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order Groceries')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('products').snapshots(),
        builder: (ctx, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No items available currently.'));

          final total = _calculateTotal(docs);

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final item = docs[i].data() as Map<String, dynamic>;
                    final id = docs[i].id;
                    final qty = _cart[id] ?? 0;

                    return ListTile(
                      title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('₹${item['price']} / ${item['unit']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: qty > 0 ? () => setState(() => _cart[id] = qty - 1) : null,
                          ),
                          Text('$qty', style: const TextStyle(fontSize: 16)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => setState(() => _cart[id] = qty + 1),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total: ₹$total', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ElevatedButton(
                      onPressed: total > 0 ? () => _checkout(docs) : null,
                      child: const Text('Place Order'),
                    ),
                  ],
                ),
              )
            ],
          );
        },
      ),
    );
  }
}
