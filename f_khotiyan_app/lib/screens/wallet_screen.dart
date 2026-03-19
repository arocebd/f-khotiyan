import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _api = ApiService();
  bool _loading = true;
  Map<String, dynamic>? _data;

  String _token() =>
      Provider.of<AuthProvider>(context, listen: false).accessToken ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final d = await _api.getWalletInfo(_token());
      if (mounted) setState(() => _data = d);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _openTopup() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => _TopupSheet(
          onSuccess: _load,
          token: _token(),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('ওয়ালেট')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Balance card
                  Card(
                    color: theme.colorScheme.primary,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text('ওয়ালেট ব্যালেন্স',
                              style: theme.textTheme.titleSmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.8))),
                          const SizedBox(height: 8),
                          Text(
                            '৳${(_data?['wallet_balance'] ?? 0).toStringAsFixed(2)}',
                            style: theme.textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              const _InfoChip(
                                  label: 'SMS প্রতি',
                                  value: '৳0.45',
                                  icon: Icons.sms_rounded),
                              const _InfoChip(
                                  label: 'AI প্রতি',
                                  value: '৳0.10+',
                                  icon: Icons.auto_awesome_rounded),
                              _InfoChip(
                                  label: 'AI ফ্রি',
                                  value:
                                      '${_data?['ai_free_uses_remaining'] ?? 0}টি',
                                  icon: Icons.star_rounded),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _openTopup,
                    icon: const Icon(Icons.add_circle_rounded),
                    label: const Text('ওয়ালেট রিচার্জ করুন'),
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                  const SizedBox(height: 20),
                  Text('লেনদেনের ইতিহাস',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  ...(_data?['transactions'] as List? ?? []).map((t) {
                    final isCredit = (t['amount'] as num) > 0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCredit
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.red.withValues(alpha: 0.15),
                          child: Icon(
                            isCredit
                                ? Icons.arrow_downward_rounded
                                : Icons.arrow_upward_rounded,
                            color: isCredit ? Colors.green : Colors.red,
                            size: 20,
                          ),
                        ),
                        title: Text(t['description'] ?? t['type_display'] ?? '',
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text(t['created_at'] ?? '',
                            style: const TextStyle(fontSize: 12)),
                        trailing: Text(
                          '${isCredit ? '+' : ''}৳${(t['amount'] as num).toStringAsFixed(2)}',
                          style: TextStyle(
                            color: isCredit ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  }),
                  if ((_data?['transactions'] as List? ?? []).isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('কোনো লেনদেন নেই',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _InfoChip(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13)),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75), fontSize: 11)),
      ],
    );
  }
}

// ─── Top-up Bottom Sheet ──────────────────────────────────────────────────────

class _TopupSheet extends StatefulWidget {
  final VoidCallback onSuccess;
  final String token;
  const _TopupSheet({required this.onSuccess, required this.token});

  @override
  State<_TopupSheet> createState() => _TopupSheetState();
}

class _TopupSheetState extends State<_TopupSheet> {
  final _api = ApiService();
  final _amountCtrl = TextEditingController();
  final _txnCtrl = TextEditingController();
  final _senderCtrl = TextEditingController();
  String _method = 'bkash';
  bool _submitting = false;

  static const _methods = [
    {'value': 'bkash', 'label': 'bKash'},
    {'value': 'nagad', 'label': 'Nagad'},
    {'value': 'rocket', 'label': 'Rocket'},
    {'value': 'bank', 'label': 'Bank Transfer'},
  ];

  // Payment numbers - update these with your actual account numbers
  static const _paymentNumbers = {
    'bkash': '01XXXXXXXXX (bKash)',
    'nagad': '01XXXXXXXXX (Nagad)',
    'rocket': '01XXXXXXXXX (Rocket)',
    'bank': 'Bank: XXXX | Account: XXXX',
  };

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount < 10) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('সর্বনিম্ন রিচার্জ ৳10')));
      return;
    }
    if (_txnCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ট্রানজেকশন আইডি দিন')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await _api.requestTopup(widget.token,
          amount: amount,
          paymentMethod: _method,
          transactionId: _txnCtrl.text.trim(),
          senderNumber: _senderCtrl.text.trim());
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'রিচার্জ অনুরোধ জমা হয়েছে। অ্যাডমিন যাচাইয়ের পর ব্যালেন্স যোগ হবে।')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ত্রুটি: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _txnCtrl.dispose();
    _senderCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ওয়ালেট রিচার্জ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          // Payment method
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: const InputDecoration(
                labelText: 'পেমেন্ট পদ্ধতি',
                border: OutlineInputBorder(),
                isDense: true),
            items: _methods
                .map((m) => DropdownMenuItem(
                    value: m['value'], child: Text(m['label']!)))
                .toList(),
            onChanged: (v) => setState(() => _method = v!),
          ),
          const SizedBox(height: 8),
          // Payment instructions
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: Colors.blue, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'পাঠান: ${_paymentNumbers[_method]}',
                    style: const TextStyle(fontSize: 13, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'পরিমাণ (৳)',
                border: OutlineInputBorder(),
                isDense: true,
                prefixText: '৳ '),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _senderCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'প্রেরকের নম্বর',
                border: OutlineInputBorder(),
                isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _txnCtrl,
            decoration: const InputDecoration(
                labelText: 'ট্রানজেকশন আইডি',
                border: OutlineInputBorder(),
                isDense: true),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('অনুরোধ পাঠান'),
            ),
          ),
        ],
      ),
    );
  }
}
