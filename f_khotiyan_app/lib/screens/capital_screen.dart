import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class CapitalScreen extends StatefulWidget {
  const CapitalScreen({super.key});
  @override
  State<CapitalScreen> createState() => _CapitalScreenState();
}

class _CapitalScreenState extends State<CapitalScreen> {
  final _api = ApiService();
  List<dynamic> _capital = [];
  bool _loading = true;

  static const _types = [
    {'value': 'initial', 'label': 'প্রাথমিক বিনিয়োগ'},
    {'value': 'additional', 'label': 'অতিরিক্ত বিনিয়োগ'},
    {'value': 'withdrawal', 'label': 'উত্তোলন'},
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
      final res = await _api.getCapital(_token());
      final list = res['results'] ?? res ?? [];
      setState(() => _capital = list is List ? list : []);
    } catch (_) {}
    setState(() => _loading = false);
  }

  double get _net => _capital.fold(0.0, (sum, c) {
        final amount = double.tryParse(c['amount'].toString()) ?? 0;
        return c['investment_type'] == 'withdrawal'
            ? sum - amount
            : sum + amount;
      });

  void _openForm() {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String type = 'additional';
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
                const Text('বিনিয়োগ/উত্তোলন',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: _dec('ধরন'),
                  items: _types
                      .map((t) => DropdownMenuItem(
                          value: t['value'], child: Text(t['label']!)))
                      .toList(),
                  onChanged: (v) => setModal(() => type = v!),
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
                            await _api.createCapital(_token(), {
                              'investment_type': type,
                              'amount': amountCtrl.text.trim(),
                              'description': descCtrl.text.trim(),
                            });
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
                      : const Text('যোগ করুন'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('মুছে ফেলবেন?'),
        content: const Text('এই এন্ট্রি মুছে ফেলতে চান?'),
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
        await _api.deleteCapital(_token(), c['id']);
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

  String _typeLabel(String? v) => _types.firstWhere((t) => t['value'] == v,
      orElse: () => {'label': v ?? ''})['label']!;

  @override
  Widget build(BuildContext context) {
    final isPositive = _net >= 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('মূলধন বিনিয়োগ'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isPositive ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color:
                      isPositive ? Colors.green.shade200 : Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 40,
                  color: isPositive ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('নিট মূলধন',
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                    Text(
                      '৳${_net.toStringAsFixed(0)}',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: isPositive
                              ? Colors.green.shade700
                              : Colors.red.shade700),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_capital.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_balance_wallet_outlined,
                        size: 64,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    const Text('কোনো বিনিয়োগ পাওয়া যায়নি'),
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
                  itemCount: _capital.length,
                  itemBuilder: (ctx, i) {
                    final c = _capital[i] as Map<String, dynamic>;
                    final isWithdrawal = c['investment_type'] == 'withdrawal';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isWithdrawal
                              ? Colors.red.withValues(alpha: 0.13)
                              : Colors.green.withValues(alpha: 0.13),
                          child: Icon(
                            isWithdrawal
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            color: isWithdrawal ? Colors.red : Colors.green,
                          ),
                        ),
                        title: Text(_typeLabel(c['investment_type']),
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${c['description'] ?? ''}\n${c['investment_date'] ?? ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${isWithdrawal ? '-' : '+'}৳${c['amount']}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color:
                                      isWithdrawal ? Colors.red : Colors.green),
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
        onPressed: _openForm,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
