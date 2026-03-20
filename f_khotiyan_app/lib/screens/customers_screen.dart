import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});
  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _api = ApiService();
  List<dynamic> _customers = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  final _search = TextEditingController();

  String _token() =>
      Provider.of<AuthProvider>(context, listen: false).accessToken ?? '';

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(() {
      final q = _search.text.toLowerCase();
      setState(() {
        _filtered = q.isEmpty
            ? _customers
            : _customers
                .where((c) =>
                    (c['customer_name'] ?? '').toLowerCase().contains(q) ||
                    (c['phone_number'] ?? '').contains(q))
                .toList();
      });
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getCustomers(_token());
      final list = res['results'] ?? res ?? [];
      setState(() {
        _customers = list is List ? list : [];
        _filtered = _customers;
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _openForm({Map<String, dynamic>? customer}) {
    final nameCtrl =
        TextEditingController(text: customer?['customer_name'] ?? '');
    final phoneCtrl =
        TextEditingController(text: customer?['phone_number'] ?? '');
    final addressCtrl = TextEditingController(text: customer?['address'] ?? '');
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  customer == null ? 'নতুন গ্রাহক' : 'গ্রাহক সম্পাদনা',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameCtrl,
                  decoration: _dec('গ্রাহকের নাম'),
                  validator: (v) => v?.isEmpty == true ? 'নাম লিখুন' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: phoneCtrl,
                  decoration: _dec('ফোন নম্বর'),
                  keyboardType: TextInputType.phone,
                  validator: (v) => v?.isEmpty == true ? 'ফোন লিখুন' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: addressCtrl,
                  decoration: _dec('ঠিকানা'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setModal(() => saving = true);
                          try {
                            final data = {
                              'customer_name': nameCtrl.text.trim(),
                              'phone_number': phoneCtrl.text.trim(),
                              'address': addressCtrl.text.trim(),
                            };
                            if (customer == null) {
                              await _api.createCustomer(_token(), data);
                            } else {
                              await _api.updateCustomer(
                                  _token(), customer['id'], data);
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            _load();
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text('ত্রুটি: $e')));
                            }
                          } finally {
                            setModal(() => saving = false);
                          }
                        },
                  child: saving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(customer == null ? 'যোগ করুন' : 'আপডেট করুন'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> customer) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('মুছে ফেলবেন?'),
        content: Text('${customer['customer_name']} কে মুছে ফেলতে চান?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('না')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('হ্যাঁ', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _api.deleteCustomer(_token(), customer['id']);
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('ত্রুটি: $e')));
        }
      }
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text('${l.customersTitle} (${_filtered.length})'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: l.search,
                prefixIcon: const Icon(Icons.search_rounded),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_filtered.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_outline,
                        size: 64,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    Text(l.noData),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _filtered.length,
                  itemBuilder: (ctx, i) {
                    final c = _filtered[i] as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            (c['customer_name'] as String? ?? '?').isNotEmpty
                                ? (c['customer_name'] as String)
                                    .substring(0, 1)
                                    .toUpperCase()
                                : '?',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                                child: Text(c['customer_name'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600))),
                            if (c['is_fake'] == true)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.13),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('ভুয়া',
                                    style: TextStyle(
                                        color: Colors.red, fontSize: 10)),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c['phone_number'] ?? ''),
                            Text(
                              'অর্ডার: ${c['total_orders'] ?? 0} | মোট: ৳${c['total_amount'] ?? 0}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _openForm(customer: c),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 20, color: Colors.redAccent),
                              onPressed: () => _delete(c),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.person_add_rounded),
      ),
    );
  }
}
