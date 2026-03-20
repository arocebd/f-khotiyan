import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _api = ApiService();
  bool _loading = true;
  List _history = [];
  Map<String, dynamic>? _walletData;

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
      final results = await Future.wait([
        _api.getPurchaseHistory(_token()),
        _api.getWalletInfo(_token()),
      ]);
      if (mounted) {
        setState(() {
          _history = results[0] as List;
          _walletData = results[1] as Map<String, dynamic>;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _buyPlan(String plan, double amount, String planLabel) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => _PurchaseSheet(
          plan: plan,
          amount: amount,
          planLabel: planLabel,
          token: _token(),
          onSuccess: _load,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isPremium = _walletData?['is_premium'] == true;
    final subType = _walletData?['subscription_type'] ?? '';
    final subEnd = _walletData?['subscription_end_date'] ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(l.subscriptionTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Current status
                  if (isPremium)
                    Card(
                      color: Colors.amber.shade700,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.workspace_premium_rounded,
                                color: Colors.white, size: 32),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('প্রিমিয়াম সক্রিয়',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16)),
                                  Text(
                                      subType == 'monthly'
                                          ? l.monthlyPlan
                                          : l.yearlyPlan,
                                      style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.85),
                                          fontSize: 13)),
                                  if (subEnd.isNotEmpty)
                                    Text('${l.validityLabel}: $subEnd',
                                        style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.75),
                                            fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Card(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'প্রিমিয়াম ক্রয় করুন এবং বিজ্ঞাপন থেকে মুক্তি পান',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Text(l.choosePlan,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  // Monthly plan card
                  _PlanCard(
                    title: l.monthlyPlan,
                    price: '৳200',
                    period: '/মাস',
                    features: const [
                      'সব বিজ্ঞাপন বন্ধ',
                      'সীমাহীন AI অর্ডার',
                      'অগ্রাধিকার সাপোর্ট',
                    ],
                    color: Colors.blue,
                    icon: Icons.calendar_month_rounded,
                    onBuy: () =>
                        _buyPlan('monthly', 200, '${l.monthlyPlan} (৳200)'),
                  ),
                  const SizedBox(height: 12),
                  // Yearly plan card
                  _PlanCard(
                    title: l.yearlyPlan,
                    price: '৳1099',
                    period: '/বছর',
                    features: const [
                      'সব বিজ্ঞাপন বন্ধ',
                      'সীমাহীন AI অর্ডার',
                      'অগ্রাধিকার সাপোর্ট',
                      '৫৪% ছাড় (মাসিকের তুলনায়)',
                    ],
                    color: Colors.amber.shade700,
                    icon: Icons.workspace_premium_rounded,
                    badge: 'সেরা মূল্য',
                    onBuy: () =>
                        _buyPlan('yearly', 1099, '${l.yearlyPlan} (৳1099)'),
                  ),
                  const SizedBox(height: 24),
                  Text(l.purchaseHistory,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  ..._history.map((h) {
                    final status = h['status'] ?? 'pending';
                    Color statusColor;
                    String statusLabel;
                    switch (status) {
                      case 'approved':
                        statusColor = Colors.green;
                        statusLabel = 'অনুমোদিত';
                        break;
                      case 'rejected':
                        statusColor = Colors.red;
                        statusLabel = 'প্রত্যাখ্যাত';
                        break;
                      default:
                        statusColor = Colors.orange;
                        statusLabel = 'অপেক্ষমাণ';
                    }
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.receipt_long_rounded),
                        title: Text(h['plan_display'] ?? h['plan'] ?? '',
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                            '৳${h['amount']} • ${h['payment_method_display'] ?? h['payment_method'] ?? ''}\n${h['created_at'] ?? ''}',
                            style: const TextStyle(fontSize: 12)),
                        isThreeLine: true,
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(statusLabel,
                              style: TextStyle(
                                  color: statusColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    );
                  }),
                  if (_history.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(l.noPurchaseHistory,
                            style: const TextStyle(color: Colors.grey)),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

// ─── Plan Card ────────────────────────────────────────────────────────────────
class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final List<String> features;
  final Color color;
  final IconData icon;
  final String? badge;
  final VoidCallback onBuy;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    required this.features,
    required this.color,
    required this.icon,
    required this.onBuy,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color.withValues(alpha: 0.5), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 22),
                    const SizedBox(width: 8),
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const Spacer(),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                              text: price,
                              style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22)),
                          TextSpan(
                              text: period,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...features.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_rounded,
                              size: 16, color: color),
                          const SizedBox(width: 6),
                          Text(f, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    )),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onBuy,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: color, foregroundColor: Colors.white),
                    child: Text('কিনুন $price'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (badge != null)
          Positioned(
            top: 4,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(badge!,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }
}

// ─── Purchase Bottom Sheet ────────────────────────────────────────────────────
class _PurchaseSheet extends StatefulWidget {
  final String plan;
  final double amount;
  final String planLabel;
  final String token;
  final VoidCallback onSuccess;

  const _PurchaseSheet({
    required this.plan,
    required this.amount,
    required this.planLabel,
    required this.token,
    required this.onSuccess,
  });

  @override
  State<_PurchaseSheet> createState() => _PurchaseSheetState();
}

class _PurchaseSheetState extends State<_PurchaseSheet> {
  final _api = ApiService();
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

  static const _paymentNumbers = {
    'bkash': '01XXXXXXXXX (bKash)',
    'nagad': '01XXXXXXXXX (Nagad)',
    'rocket': '01XXXXXXXXX (Rocket)',
    'bank': 'Bank: XXXX | Account: XXXX',
  };

  Future<void> _submit() async {
    if (_txnCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.enterTxnId)));
      return;
    }
    setState(() => _submitting = true);
    try {
      await _api.purchaseSubscription(widget.token,
          plan: widget.plan,
          paymentMethod: _method,
          transactionId: _txnCtrl.text.trim(),
          senderNumber: _senderCtrl.text.trim());
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context)!.rechargeSubmitted)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${AppLocalizations.of(context)!.errorPrefix}: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _txnCtrl.dispose();
    _senderCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
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
          Text(l.subscriptionPurchaseTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(widget.planLabel,
              style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: InputDecoration(
                labelText: l.paymentMethod,
                border: const OutlineInputBorder(),
                isDense: true),
            items: _methods
                .map((m) => DropdownMenuItem(
                    value: m['value'], child: Text(m['label']!)))
                .toList(),
            onChanged: (v) => setState(() => _method = v!),
          ),
          const SizedBox(height: 8),
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
                    color: Colors.blue, size: 15),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '৳${widget.amount.toStringAsFixed(0)} পাঠান: ${_paymentNumbers[_method]}',
                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _senderCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
                labelText: l.senderNumberLabel,
                border: const OutlineInputBorder(),
                isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _txnCtrl,
            decoration: InputDecoration(
                labelText: l.transactionIdLabel,
                border: const OutlineInputBorder(),
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
                  : Text(l.submitRequest),
            ),
          ),
        ],
      ),
    );
  }
}
