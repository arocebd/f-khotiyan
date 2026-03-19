import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});
  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final _api = ApiService();
  List<dynamic> _expenses = [];
  bool _loading = true;
  String? _categoryFilter;

  static const _categories = [
    {'value': '', 'label': 'সব'},
    {'value': 'shipping', 'label': 'শিপিং'},
    {'value': 'packaging', 'label': 'প্যাকেজিং'},
    {'value': 'marketing', 'label': 'মার্কেটিং'},
    {'value': 'salary', 'label': 'বেতন'},
    {'value': 'rent', 'label': 'ভাড়া'},
    {'value': 'utilities', 'label': 'ইউটিলিটি'},
    {'value': 'other', 'label': 'অন্যান্য'},
  ];

  String _token() =>
      Provider.of<AuthProvider>(context, listen: false).accessToken ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getExpenses(_token());
      final list = res['results'] ?? res ?? [];
      setState(() => _expenses = (list is List ? list : []));
    } catch (_) {}
    setState(() => _loading = false);
  }

  List<dynamic> get _filtered {
    if (_categoryFilter == null || _categoryFilter!.isEmpty) {
      return _expenses;
    }
    return _expenses.where((e) => e['category'] == _categoryFilter).toList();
  }

  double get _total => _filtered.fold(
      0.0, (sum, e) => sum + (double.tryParse(e['amount'].toString()) ?? 0));

  void _openForm({Map<String, dynamic>? expense}) {
    final amountCtrl =
        TextEditingController(text: expense?['amount']?.toString() ?? '');
    final descCtrl = TextEditingController(text: expense?['description'] ?? '');
    String category = expense?['category'] ?? 'other';
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
                  expense == null ? 'নতুন খরচ' : 'খরচ সম্পাদনা',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: _dec('ক্যাটাগরি'),
                  items: _categories
                      .skip(1)
                      .map((c) => DropdownMenuItem(
                          value: c['value'], child: Text(c['label']!)))
                      .toList(),
                  onChanged: (v) => setModal(() => category = v!),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: amountCtrl,
                  decoration: _dec('পরিমাণ (৳)'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v?.isEmpty == true ? 'পরিমাণ লিখুন' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: descCtrl,
                  decoration: _dec('বিবরণ'),
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
                              'category': category,
                              'amount': amountCtrl.text.trim(),
                              'description': descCtrl.text.trim(),
                            };
                            if (expense == null) {
                              await _api.createExpense(_token(), data);
                            } else {
                              await _api.updateExpense(
                                  _token(), expense['id'], data);
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
                      : Text(expense == null ? 'যোগ করুন' : 'আপডেট করুন'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> expense) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('মুছে ফেলবেন?'),
        content: const Text('এই খরচটি মুছে ফেলতে চান?'),
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
        await _api.deleteExpense(_token(), expense['id']);
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

  String _catLabel(String? cat) =>
      _categories.firstWhere((c) => c['value'] == cat,
          orElse: () => {'label': cat ?? ''})['label']!;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('খরচ ব্যবস্থাপনা'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          // Summary card
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.money_off_rounded, size: 32),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('মোট খরচ', style: TextStyle(fontSize: 12)),
                    Text('৳${_total.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
          // Category filter chips
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (ctx, i) {
                final cat = _categories[i];
                final selected = (_categoryFilter ?? '') == cat['value'];
                return FilterChip(
                  label: Text(cat['label']!,
                      style: TextStyle(
                          fontSize: 12, color: selected ? Colors.white : null)),
                  selected: selected,
                  selectedColor: Theme.of(context).colorScheme.primary,
                  onSelected: (_) => setState(() {
                    _categoryFilter = cat['value'];
                  }),
                );
              },
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
                    Icon(Icons.receipt_long_outlined,
                        size: 64,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    const Text('কোনো খরচ পাওয়া যায়নি'),
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
                    final e = _filtered[i] as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              Colors.orange.withValues(alpha: 0.15),
                          child: const Icon(Icons.payments_outlined,
                              color: Colors.orange),
                        ),
                        title: Text(
                          _catLabel(e['category']),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${e['description'] ?? ''}\n${e['expense_date'] ?? ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '৳${e['amount']}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Theme.of(ctx).colorScheme.error),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _openForm(expense: e),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 20, color: Colors.redAccent),
                              onPressed: () => _delete(e),
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
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
