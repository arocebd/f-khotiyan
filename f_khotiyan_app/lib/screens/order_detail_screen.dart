import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/ad_service.dart';
import '../services/api_service.dart';
import '../services/invoice_service.dart';
import 'order_tracking_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;
  final VoidCallback? onRefresh;
  const OrderDetailScreen({super.key, required this.orderId, this.onRefresh});
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _order;
  bool _loading = true;
  bool _sendingSms = false;
  bool _sendingSteadfast = false;
  bool _checkingStatus = false;
  bool _sendingPathao = false;
  bool _checkingPathaoStatus = false;

  static const _statusOptions = [
    {'value': 'pending', 'label': 'অপেক্ষারত'},
    {'value': 'processing', 'label': 'প্রক্রিয়াকরণ'},
    {'value': 'shipped', 'label': 'পাঠানো হয়েছে'},
    {'value': 'delivered', 'label': 'ডেলিভারি হয়েছে'},
    {'value': 'cancelled', 'label': 'বাতিল'},
    {'value': 'returned', 'label': 'ফেরত'},
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
      final o = await _api.getOrderDetail(_token(), widget.orderId);
      setState(() => _order = o);
    } catch (_) {}
    setState(() => _loading = false);
  }

  static const _returnReasons = [
    {'value': 'defective', 'label': 'ত্রুটিপূর্ণ পণ্য'},
    {'value': 'wrong_item', 'label': 'ভুল পণ্য পাঠানো হয়েছে'},
    {'value': 'not_delivered', 'label': 'ডেলিভারি হয়নি'},
    {'value': 'size_issue', 'label': 'সাইজ / রঙ সমস্যা'},
    {'value': 'customer_request', 'label': 'গ্রাহকের অনুরোধ'},
    {'value': 'other', 'label': 'অন্যান্য'},
  ];

  Future<void> _updateStatus(String newStatus) async {
    if (newStatus == 'returned') {
      await _showReturnReasonDialog();
      return;
    }
    try {
      await _api
          .updateOrder(_token(), widget.orderId, {'order_status': newStatus});
      await _load();
      widget.onRefresh?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ত্রুটি: $e')));
      }
    }
  }

  Future<void> _showReturnReasonDialog() async {
    String? selectedReason;
    final descCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('ফেরতের কারণ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'কারণ নির্বাচন করুন',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedReason,
                    isExpanded: true,
                    isDense: true,
                    hint: const Text('নির্বাচন করুন'),
                    items: _returnReasons
                        .map((r) => DropdownMenuItem(
                              value: r['value'],
                              child: Text(r['label']!),
                            ))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedReason = v),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'বিবরণ (ঐচ্ছিক)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('বাতিল'),
            ),
            ElevatedButton(
              onPressed: selectedReason == null
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: const Text('নিশ্চিত করুন'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || selectedReason == null) {
      descCtrl.dispose();
      return;
    }
    final reason = selectedReason!;
    final description = descCtrl.text.trim();
    descCtrl.dispose();
    try {
      await _api.updateOrder(_token(), widget.orderId, {
        'order_status': 'returned',
        'return_reason': reason,
        'return_description': description,
      });
      await _load();
      widget.onRefresh?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ত্রুটি: $e')));
      }
    }
  }

  Future<void> _sendSms() async {
    setState(() => _sendingSms = true);
    try {
      final res = await _api.sendOrderSms(_token(), widget.orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'SMS পাঠানো হয়েছে')));
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('SMS ত্রুটি: $e')));
      }
    } finally {
      if (mounted) setState(() => _sendingSms = false);
    }
  }

  Future<void> _openInvoice(Map<String, dynamic> order) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final profile = <String, dynamic>{
      'business_name': authProvider.businessName ?? '',
      'owner_name': authProvider.ownerName ?? '',
      'phone_number': authProvider.phoneNumber ?? '',
      'location': '',
    };
    // Fetch full profile for location
    try {
      final p = await _api.getProfile(_token());
      profile.addAll(p['user'] as Map<String, dynamic>? ?? {});
    } catch (_) {}

    if (!mounted) return;

    Future<void> showTheInvoice() async {
      if (!mounted) return;
      await InvoiceService.showInvoice(context, order, profile);
    }

    final isPremium = authProvider.isPremium;
    if (!isPremium) {
      AdService().loadInterstitialAd();
      AdService().showInterstitialAd(onAdClosed: showTheInvoice);
    } else {
      await showTheInvoice();
    }
  }

  Future<void> _sendToSteadfast() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sendingSteadfast = true);
    try {
      final res = await _api.sendToSteadfast(_token(), widget.orderId);
      if (!mounted) return;
      if (res['success'] == true) {
        await _load();
        widget.onRefresh?.call();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
                'Steadfast-এ পাঠানো হয়েছে! Consignment: ${res['consignment_id']}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        messenger.showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'ত্রুটি হয়েছে')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('ত্রুটি: $e')));
    } finally {
      if (mounted) setState(() => _sendingSteadfast = false);
    }
  }

  Future<void> _checkSteadfastStatus() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _checkingStatus = true);
    try {
      final res = await _api.getSteadfastStatus(_token(), widget.orderId);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      final status = res['delivery_status'] ?? 'unknown';
      final statusBn = _steadfastStatusBn(status);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Steadfast ডেলিভারি স্ট্যাটাস'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('স্ট্যাটাস: $statusBn',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              Text('Consignment ID: ${res['consignment_id'] ?? '-'}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text('Tracking Code: ${res['tracking_code'] ?? '-'}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('বন্ধ করুন')),
          ],
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('ত্রুটি: $e')));
    } finally {
      if (mounted) setState(() => _checkingStatus = false);
    }
  }

  String _steadfastStatusBn(String status) {
    const map = {
      'pending': 'অপেক্ষারত',
      'delivered_approval_pending': 'ডেলিভারি অ্যাপ্রুভাল পেন্ডিং',
      'partial_delivered_approval_pending': 'আংশিক ডেলিভারি পেন্ডিং',
      'cancelled_approval_pending': 'বাতিল অ্যাপ্রুভাল পেন্ডিং',
      'delivered': 'ডেলিভারি সম্পন্ন',
      'partial_delivered': 'আংশিক ডেলিভারি',
      'cancelled': 'বাতিল',
      'hold': 'হোল্ড',
      'in_review': 'রিভিউতে আছে',
      'unknown': 'অজানা',
    };
    return map[status] ?? status;
  }

  Future<void> _sendToPathao() async {
    setState(() => _sendingPathao = true);
    try {
      final res = await _api.sendToPathao(_token(), widget.orderId);
      if (!mounted) return;
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Pathao-তে পাঠানো হয়েছে! Consignment: ${res['consignment_id']}'),
          backgroundColor: Colors.green,
        ));
        _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Pathao ত্রুটি: ${res['message'] ?? res.toString()}'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ত্রুটি: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _sendingPathao = false);
    }
  }

  Future<void> _checkPathaoStatus() async {
    setState(() => _checkingPathaoStatus = true);
    try {
      final res = await _api.getPathaoStatus(_token(), widget.orderId);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Pathao ডেলিভারি স্ট্যাটাস'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Consignment: ${res['consignment_id'] ?? '-'}'),
              const SizedBox(height: 8),
              Text('স্ট্যাটাস: ${res['order_status'] ?? '-'}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ঠিক আছে'))
          ],
        ),
      );
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ত্রুটি: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _checkingPathaoStatus = false);
    }
  }

  Future<void> _trackCourier() async {
    final o = _order;
    if (o == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderTrackingScreen(
          orderId: widget.orderId,
          orderNumber: o['order_number']?.toString() ?? '#${widget.orderId}',
        ),
      ),
    );
    // Refresh order after returning from tracking screen
    _load();
  }

  Future<void> _setManualConsignment() async {
    final cidCtrl = TextEditingController(
        text: _order?['consignment_id']?.toString() ?? '');
    final trkCtrl = TextEditingController(
        text: _order?['steadfast_tracking_code']?.toString() ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Steadfast Consignment সেট করুন'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Steadfast ওয়েবসাইট থেকে ম্যানুয়ালি তৈরি করা Consignment ID এখানে লিখুন।',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cidCtrl,
              decoration: const InputDecoration(
                labelText: 'Consignment ID',
                hintText: 'যেমন: 231140091',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: trkCtrl,
              decoration: const InputDecoration(
                labelText: 'Tracking Code (ঐচ্ছিক)',
                hintText: 'যেমন: SFR260314STEE29ACEBD',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('বাতিল')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('সংরক্ষণ')),
        ],
      ),
    );
    if (result != true) return;
    final consignmentId = cidCtrl.text.trim();
    if (consignmentId.isEmpty) return;
    try {
      await _api.updateOrder(_token(), widget.orderId, {
        'consignment_id': consignmentId,
        'steadfast_tracking_code': trkCtrl.text.trim(),
        'steadfast_status': 'in_review',
        'courier_type': 'steadfast',
      });
      await _load();
      widget.onRefresh?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Consignment ID সংরক্ষণ হয়েছে'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ত্রুটি: $e')));
      }
    }
  }

  Future<void> _editOrder() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _OrderEditPage(
          orderId: widget.orderId,
          order: _order!,
          token: _token(),
        ),
      ),
    );
    if (result == true) {
      await _load();
      widget.onRefresh?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_order?['order_number'] ?? 'অর্ডার বিবরণ'),
        actions: [
          if (_order?['order_status'] == 'pending')
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              tooltip: 'অর্ডার সম্পাদনা',
              onPressed: _editOrder,
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _order == null
              ? const Center(child: Text('তথ্য পাওয়া যায়নি'))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final o = _order!;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Status ──
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('স্ট্যাটাস পরিবর্তন',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _statusOptions.map((opt) {
                    final selected = o['order_status'] == opt['value'];
                    return ChoiceChip(
                      label: Text(opt['label']!,
                          style: TextStyle(
                              fontSize: 12,
                              color: selected ? Colors.white : null)),
                      selected: selected,
                      selectedColor: theme.colorScheme.primary,
                      onSelected: (_) => _updateStatus(opt['value']!),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Customer ──
        _infoCard('গ্রাহকের তথ্য', [
          _row('নাম', o['customer_name'] ?? ''),
          _row('ফোন', o['customer_phone'] ?? ''),
          _row('ঠিকানা', o['customer_address'] ?? ''),
        ]),
        const SizedBox(height: 12),

        // ── Items ──
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('পণ্য সমূহ',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const Divider(),
                ...(o['items'] as List? ?? []).map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item['product_name'] ??
                                  'পণ্য #${item['product']}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Text(
                            '${item['quantity']} × ৳${item['selling_price']}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Totals ──
        _infoCard('মূল্য বিবরণ', [
          _row('সাবটোটাল', '৳${o['subtotal'] ?? 0}'),
          _row('শিপিং', '৳${o['delivery_charge'] ?? 0}'),
          _row('মোট', '৳${o['grand_total'] ?? 0}', bold: true),
          _row('কুরিয়ার', o['courier_type'] ?? ''),
          if ((o['tracking_number'] ?? '').toString().isNotEmpty)
            _row('ট্র্যাকিং নং', o['tracking_number']),
        ]),
        const SizedBox(height: 12),

        // ── Steadfast Status ──
        if ((o['consignment_id'] ?? '').toString().isNotEmpty)
          _infoCard('Steadfast কুরিয়ার', [
            _row('Consignment ID', o['consignment_id'] ?? ''),
            if ((o['steadfast_tracking_code'] ?? '').toString().isNotEmpty)
              _row('Tracking Code', o['steadfast_tracking_code'] ?? ''),
            if ((o['steadfast_status'] ?? '').toString().isNotEmpty)
              _row('ডেলিভারি স্ট্যাটাস',
                  _steadfastStatusBn(o['steadfast_status'] ?? '')),
          ]),
        const SizedBox(height: 12),

        // ── Return Info ──
        if (o['order_status'] == 'returned' &&
            (o['return_reason'] ?? '').toString().isNotEmpty)
          _infoCard('ফেরতের তথ্য', [
            _row(
              'কারণ',
              _returnReasons.firstWhere(
                    (r) => r['value'] == o['return_reason'],
                    orElse: () => {'label': o['return_reason'].toString()},
                  )['label'] ??
                  '',
            ),
            if ((o['return_description'] ?? '').toString().isNotEmpty)
              _row('বিবরণ', o['return_description']),
          ]),
        if (o['order_status'] == 'returned' &&
            (o['return_reason'] ?? '').toString().isNotEmpty)
          const SizedBox(height: 12),

        // ── Actions ──
        _infoCard('অ্যাকশন', []),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _sendingSms ? null : _sendSms,
                icon: _sendingSms
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(
                        o['sms_sent'] == true
                            ? Icons.sms_rounded
                            : Icons.sms_outlined,
                        color: o['sms_sent'] == true ? Colors.green : null,
                      ),
                label: Text(
                    o['sms_sent'] == true ? 'SMS পাঠানো হয়েছে' : 'SMS পাঠান'),
              ),
              OutlinedButton.icon(
                onPressed: _trackCourier,
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('ট্র্যাক করুন'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openInvoice(o),
                icon: const Icon(Icons.receipt_long_rounded,
                    color: Colors.indigo),
                label: const Text('ইনভয়েস'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.indigo),
              ),
              // ── Courier Buttons ──
              // Show Steadfast send/status when not yet sent, or already sent via Steadfast
              if ((o['consignment_id'] ?? '').toString().isEmpty ||
                  (o['courier_type'] ?? '') == 'steadfast')
                if ((o['consignment_id'] ?? '').toString().isEmpty)
                  ElevatedButton.icon(
                    onPressed: _sendingSteadfast ? null : _sendToSteadfast,
                    icon: _sendingSteadfast
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded),
                    label: const Text('Steadfast-এ পাঠান'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _checkingStatus ? null : _checkSteadfastStatus,
                    icon: _checkingStatus
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.track_changes_rounded,
                            color: Colors.deepPurple),
                    label: const Text('Steadfast স্ট্যাটাস'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.deepPurple),
                  ),
              // Show Pathao send/status when not yet sent, or already sent via Pathao
              if ((o['consignment_id'] ?? '').toString().isEmpty ||
                  (o['courier_type'] ?? '') == 'pathao')
                if ((o['consignment_id'] ?? '').toString().isEmpty)
                  ElevatedButton.icon(
                    onPressed: _sendingPathao ? null : _sendToPathao,
                    icon: _sendingPathao
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded),
                    label: const Text('Pathao-তে পাঠান'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white),
                  )
                else
                  OutlinedButton.icon(
                    onPressed:
                        _checkingPathaoStatus ? null : _checkPathaoStatus,
                    icon: _checkingPathaoStatus
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.track_changes_rounded,
                            color: Colors.orange),
                    label: const Text('Pathao স্ট্যাটাস'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade700),
                  ),
              // Manual consignment ID entry
              OutlinedButton.icon(
                onPressed: _setManualConsignment,
                icon: const Icon(Icons.edit_note_rounded, color: Colors.teal),
                label: Text(
                  (o['consignment_id'] ?? '').toString().isNotEmpty
                      ? 'Consignment সম্পাদনা'
                      : 'ম্যানুয়াল Consignment',
                ),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.teal),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _infoCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (children.isNotEmpty) ...[
              const Divider(),
              ...children,
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, dynamic value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text('$label:',
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value.toString(),
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ================== FULL ORDER EDIT PAGE ==================

class _EditableItem {
  final int? productId;
  final String productName;
  final double purchasePrice;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;

  _EditableItem({
    this.productId,
    required this.productName,
    required this.purchasePrice,
    required this.qtyCtrl,
    required this.priceCtrl,
  });

  void dispose() {
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

class _OrderEditPage extends StatefulWidget {
  final int orderId;
  final Map<String, dynamic> order;
  final String token;

  const _OrderEditPage(
      {required this.orderId, required this.order, required this.token});

  @override
  State<_OrderEditPage> createState() => _OrderEditPageState();
}

class _OrderEditPageState extends State<_OrderEditPage> {
  final _api = ApiService();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _deliveryCtrl;
  late final TextEditingController _notesCtrl;
  final List<_EditableItem> _items = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final o = widget.order;
    _nameCtrl =
        TextEditingController(text: (o['customer_name'] ?? '').toString());
    _phoneCtrl =
        TextEditingController(text: (o['customer_phone'] ?? '').toString());
    _addressCtrl =
        TextEditingController(text: (o['customer_address'] ?? '').toString());
    _deliveryCtrl =
        TextEditingController(text: (o['delivery_charge'] ?? '0').toString());
    _notesCtrl = TextEditingController(text: (o['notes'] ?? '').toString());

    for (final item in (o['items'] as List? ?? [])) {
      _items.add(_EditableItem(
        productId: item['product'],
        productName: (item['product_name'] ?? 'পণ্য').toString(),
        purchasePrice:
            double.tryParse((item['purchase_price'] ?? '0').toString()) ?? 0,
        qtyCtrl:
            TextEditingController(text: (item['quantity'] ?? 1).toString()),
        priceCtrl: TextEditingController(
            text: (item['selling_price'] ?? 0).toString()),
      ));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _deliveryCtrl.dispose();
    _notesCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  double get _subtotal => _items.fold(0.0, (sum, item) {
        final qty = double.tryParse(item.qtyCtrl.text) ?? 0;
        final price = double.tryParse(item.priceCtrl.text) ?? 0;
        return sum + qty * price;
      });

  double get _grandTotal =>
      _subtotal + (double.tryParse(_deliveryCtrl.text) ?? 0);

  Future<void> _addProduct() async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProductSearchSheet(token: widget.token, api: _api),
    );
    if (selected != null) {
      setState(() {
        _items.add(_EditableItem(
          productId: selected['id'],
          productName: (selected['product_name'] ?? '').toString(),
          purchasePrice:
              double.tryParse((selected['purchase_price'] ?? '0').toString()) ??
                  0,
          qtyCtrl: TextEditingController(text: '1'),
          priceCtrl: TextEditingController(
              text: (selected['selling_price'] ?? '0').toString()),
        ));
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _api.updateOrder(widget.token, widget.orderId, {
        'customer_name': _nameCtrl.text.trim(),
        'customer_phone': _phoneCtrl.text.trim(),
        'customer_address': _addressCtrl.text.trim(),
        'delivery_charge': double.tryParse(_deliveryCtrl.text.trim()) ?? 0,
        'notes': _notesCtrl.text.trim(),
      });
      final itemsPayload = _items
          .map((item) => {
                'product': item.productId,
                'product_name': item.productName,
                'quantity': int.tryParse(item.qtyCtrl.text) ?? 1,
                'selling_price': double.tryParse(item.priceCtrl.text) ?? 0,
                'purchase_price': item.purchasePrice,
              })
          .toList();
      await _api.updateOrderItems(widget.token, widget.orderId, itemsPayload);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ত্রুটি: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('অর্ডার সম্পাদনা'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('সংরক্ষণ',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // ─ Customer Info ─
          _card('গ্রাহকের তথ্য', [
            TextField(controller: _nameCtrl, decoration: _dec('নাম')),
            const SizedBox(height: 10),
            TextField(
                controller: _phoneCtrl,
                decoration: _dec('ফোন'),
                keyboardType: TextInputType.phone),
            const SizedBox(height: 10),
            TextField(
                controller: _addressCtrl,
                decoration: _dec('ঠিকানা'),
                maxLines: 2),
            const SizedBox(height: 10),
            TextField(
                controller: _deliveryCtrl,
                decoration: _dec('ডেলিভারি চার্জ'),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {})),
            const SizedBox(height: 10),
            TextField(
                controller: _notesCtrl, decoration: _dec('নোট'), maxLines: 2),
          ]),
          const SizedBox(height: 12),

          // ─ Items ─
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('পণ্য সমূহ',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      TextButton.icon(
                        onPressed: _addProduct,
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text('পণ্য যোগ'),
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      ),
                    ],
                  ),
                  const Divider(),
                  if (_items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                          child: Text('কোনো পণ্য নেই',
                              style: TextStyle(color: Colors.grey))),
                    ),
                  ...List.generate(_items.length, (i) {
                    final item = _items[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.productName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.redAccent, size: 20),
                                onPressed: () =>
                                    setState(() => _items.removeAt(i)),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: item.qtyCtrl,
                                  decoration: _dec('পরিমাণ'),
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: item.priceCtrl,
                                  decoration: _dec('বিক্রয় মূল্য ৳'),
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                          if (i < _items.length - 1)
                            const Padding(
                                padding: EdgeInsets.only(top: 10),
                                child: Divider(height: 1)),
                        ],
                      ),
                    );
                  }),
                  if (_items.isNotEmpty) ...[
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('সাবটোটাল:', style: TextStyle(fontSize: 13)),
                        Text('৳${_subtotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('মোট:',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        Text('৳${_grandTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _card(String title, List<Widget> children) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              const Divider(),
              ...children,
            ],
          ),
        ),
      );
}

// ================== PRODUCT SEARCH SHEET ==================

class _ProductSearchSheet extends StatefulWidget {
  final String token;
  final ApiService api;

  const _ProductSearchSheet({required this.token, required this.api});

  @override
  State<_ProductSearchSheet> createState() => _ProductSearchSheetState();
}

class _ProductSearchSheetState extends State<_ProductSearchSheet> {
  final _searchCtrl = TextEditingController();
  List<dynamic> _products = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final res = await widget.api
          .getProducts(widget.token, search: query.isEmpty ? null : query);
      final list = res['results'] ?? res;
      setState(() => _products = list is List ? list : []);
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          const SizedBox(height: 12),
          const Text('পণ্য খুঁজুন',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'নাম বা সার্চ করুন',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _search,
            ),
          ),
          if (_loading)
            const CircularProgressIndicator()
          else
            Expanded(
              child: ListView.builder(
                itemCount: _products.length,
                itemBuilder: (_, i) {
                  final p = _products[i] as Map<String, dynamic>;
                  return ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text(p['product_name'] ?? ''),
                    subtitle: Text(
                        'স্টক: ${p['quantity'] ?? 0} · ৳${p['selling_price'] ?? 0}'),
                    trailing: const Icon(Icons.add_circle_outline,
                        color: Colors.green),
                    onTap: () => Navigator.pop(context, p),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
