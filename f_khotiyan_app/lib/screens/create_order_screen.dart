import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/ad_service.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});
  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _courierType = 'steadfast';
  double _shippingCharge = 60;
  List<dynamic> _products = [];
  final List<_OrderItemRow> _items = [_OrderItemRow()];
  bool _saving = false;

  String _token() =>
      Provider.of<AuthProvider>(context, listen: false).accessToken ?? '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
    AdService().loadInterstitialAd();
  }

  Future<void> _loadProducts() async {
    try {
      final res = await _api.getProducts(_token());
      setState(() => _products = res['results'] ?? res ?? []);
    } catch (_) {}
  }

  double get _subtotal => _items.fold(0.0, (sum, item) {
        final price = double.tryParse(item.priceCtrl.text) ?? 0;
        final qty = double.tryParse(item.qtyCtrl.text) ?? 0;
        return sum + price * qty;
      });

  double get _grandTotal => _subtotal + _shippingCharge;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.every((i) => i.selectedProduct == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('অন্তত একটি পণ্য যোগ করুন')));
      return;
    }

    setState(() => _saving = true);
    try {
      final itemsData = _items
          .where((i) => i.selectedProduct != null)
          .map((i) => {
                'product': i.selectedProduct!['id'],
                'product_name': i.selectedProduct!['product_name'] ??
                    i.selectedProduct!['name'] ??
                    '',
                'quantity': int.tryParse(i.qtyCtrl.text) ?? 1,
                'selling_price': double.tryParse(i.priceCtrl.text) ?? 0,
                'purchase_price': i.selectedProduct!['purchase_price'] ?? 0,
              })
          .toList();

      await _api.createOrder(_token(), {
        'customer_name': _customerNameCtrl.text.trim(),
        'customer_phone': _customerPhoneCtrl.text.trim(),
        'customer_address': _addressCtrl.text.trim(),
        'courier_type': _courierType,
        'delivery_charge': _shippingCharge,
        'total_amount': _subtotal,
        'grand_total': _grandTotal,
        'notes': _notesCtrl.text.trim(),
        'items': itemsData,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('অর্ডার সফলভাবে তৈরি হয়েছে')));
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final isPremium = auth.isPremium;
        if (!isPremium) {
          AdService().showInterstitialAd(onAdClosed: () {
            if (mounted) Navigator.pop(context);
          });
        } else {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ত্রুটি: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.createOrderTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Customer Info ──
            _sectionHeader('গ্রাহকের তথ্য'),
            TextFormField(
              controller: _customerNameCtrl,
              decoration: _dec('গ্রাহকের নাম', Icons.person_outline),
              validator: (v) => v == null || v.isEmpty ? 'নাম লিখুন' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _customerPhoneCtrl,
              decoration: _dec('ফোন নম্বর', Icons.phone_outlined),
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  v == null || v.isEmpty ? 'ফোন নম্বর লিখুন' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _addressCtrl,
              decoration: _dec('ঠিকানা', Icons.location_on_outlined),
              maxLines: 2,
              validator: (v) => v == null || v.isEmpty ? 'ঠিকানা লিখুন' : null,
            ),
            const SizedBox(height: 20),

            // ── Order Items ──
            _sectionHeader('পণ্য সমূহ'),
            ..._items.asMap().entries.map(
                  (e) => _ItemRow(
                    index: e.key,
                    item: e.value,
                    products: _products,
                    onRemove: _items.length > 1
                        ? () => setState(() => _items.removeAt(e.key))
                        : null,
                    onChanged: () => setState(() {}),
                  ),
                ),
            TextButton.icon(
              onPressed: () => setState(() => _items.add(_OrderItemRow())),
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('পণ্য যোগ করুন'),
            ),
            const SizedBox(height: 20),

            // ── Shipping ──
            _sectionHeader('শিপিং তথ্য'),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _courierType,
                    decoration: _dec('কুরিয়ার', Icons.local_shipping_outlined),
                    items: const [
                      DropdownMenuItem(
                          value: 'steadfast', child: Text('Steadfast')),
                      DropdownMenuItem(value: 'pathao', child: Text('Pathao')),
                      DropdownMenuItem(value: 'redx', child: Text('RedX')),
                    ],
                    onChanged: (v) => setState(() => _courierType = v!),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    initialValue: _shippingCharge.toString(),
                    decoration:
                        _dec('শিপিং চার্জ (৳)', Icons.attach_money_rounded),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setState(
                        () => _shippingCharge = double.tryParse(v) ?? 60),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _notesCtrl,
              decoration: _dec('নোট (ঐচ্ছিক)', Icons.notes_rounded),
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // ── Summary ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _summaryRow('সাবটোটাল', '৳${_subtotal.toStringAsFixed(0)}'),
                    _summaryRow(
                        'শিপিং', '৳${_shippingCharge.toStringAsFixed(0)}'),
                    const Divider(),
                    _summaryRow(
                      'মোট',
                      '৳${_grandTotal.toStringAsFixed(0)}',
                      bold: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('অর্ডার তৈরি করুন',
                        style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      );

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    final style = bold
        ? const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)
        : const TextStyle();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}

// ─── Data container for each order item row ────────────────────────────────

class _OrderItemRow {
  Map<String, dynamic>? selectedProduct;
  final qtyCtrl = TextEditingController(text: '1');
  final priceCtrl = TextEditingController();
}

// ─── Item Row Widget ───────────────────────────────────────────────────────

class _ItemRow extends StatefulWidget {
  final int index;
  final _OrderItemRow item;
  final List<dynamic> products;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;
  const _ItemRow(
      {required this.index,
      required this.item,
      required this.products,
      this.onRemove,
      required this.onChanged});

  @override
  State<_ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<_ItemRow> {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: widget.item.selectedProduct,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'পণ্য বেছে নিন',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    items: widget.products
                        .map((p) => DropdownMenuItem<Map<String, dynamic>>(
                              value: p as Map<String, dynamic>,
                              child: Text(
                                  '${p['product_name'] ?? p['name'] ?? ''} (স্টক: ${p['quantity'] ?? 0})',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (p) {
                      setState(() {
                        widget.item.selectedProduct = p;
                        if (p != null) {
                          widget.item.priceCtrl.text =
                              (p['selling_price'] ?? '').toString();
                        }
                      });
                      widget.onChanged();
                    },
                  ),
                ),
                if (widget.onRemove != null)
                  IconButton(
                    onPressed: widget.onRemove,
                    icon: const Icon(Icons.remove_circle_outline,
                        color: Colors.red),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: widget.item.qtyCtrl,
                    decoration: InputDecoration(
                      labelText: 'পরিমাণ',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => widget.onChanged(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: widget.item.priceCtrl,
                    decoration: InputDecoration(
                      labelText: 'বিক্রয় মূল্য (৳)',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => widget.onChanged(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
