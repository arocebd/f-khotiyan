import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  List<dynamic> _products = [];
  bool _loading = true;
  // ignore: unused_field
  String? _error;
  String _search = '';
  final bool _showLowStock = false;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  String _token() =>
      Provider.of<AuthProvider>(context, listen: false).accessToken ?? '';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getProducts(_token(),
          search: _search.isEmpty ? null : _search,
          lowStock: _showLowStock ? true : null);
      final all = res['results'] ?? res;
      setState(() {
        _products = all is List ? all : [];
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final filtered = _tabCtrl.index == 1
        ? _products.where((p) {
            final qty = (p['quantity'] as num?) ?? 0;
            final lvl = (p['reorder_level'] as num?) ?? 10;
            return qty <= lvl;
          }).toList()
        : _products;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.productsTitle),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: [
            Tab(text: l.all),
            Tab(text: l.lowStock),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) {
                _search = v;
                _load();
              },
              decoration: InputDecoration(
                hintText: l.search,
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (filtered.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 64,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    Text(l.noProductsFound),
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
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) =>
                      _ProductCard(product: filtered[i], onRefresh: _load),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductForm(context),
        icon: const Icon(Icons.add),
        label: Text(l.newProductBtn),
      ),
    );
  }

  Future<void> _showProductForm(BuildContext context,
      [Map<String, dynamic>? existing]) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ProductFormSheet(
        existing: existing,
        onSaved: _load,
      ),
    );
  }
}

// ─── Product Card ─────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onRefresh;
  const _ProductCard({required this.product, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final qty = (product['quantity'] as num?) ?? 0;
    final reorder = (product['reorder_level'] as num?) ?? 10;
    final isLow = qty <= reorder;
    final profit = product['profit_margin'] != null
        ? double.tryParse('${product['profit_margin']}') ?? 0.0
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isLow
                ? Colors.red.withValues(alpha: 0.12)
                : theme.colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.inventory_2_rounded,
            color: isLow ? Colors.red : theme.colorScheme.primary,
            size: 22,
          ),
        ),
        title: Text(
          product['product_name'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ক্রয়: ৳${product['purchase_price']}  বিক্রয়: ৳${product['selling_price']}',
              style: theme.textTheme.bodySmall,
            ),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: isLow
                        ? Colors.red.withValues(alpha: 0.12)
                        : Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'স্টক: $qty ${product['unit'] ?? 'pcs'}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isLow ? Colors.red : Colors.green[700],
                    ),
                  ),
                ),
                if (isLow)
                  const Padding(
                    padding: EdgeInsets.only(left: 6, top: 4),
                    child: Icon(Icons.warning_amber_rounded,
                        size: 14, color: Colors.orange),
                  ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${profit.toStringAsFixed(1)}%',
              style: TextStyle(
                color: profit > 0 ? Colors.green : Colors.red,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            Text(l.marginLabel, style: const TextStyle(fontSize: 10)),
          ],
        ),
        onTap: () => _showEdit(context),
      ),
    );
  }

  void _showEdit(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ProductFormSheet(
        existing: product,
        onSaved: onRefresh,
      ),
    );
  }
}

// ─── Product Form Sheet ────────────────────────────────────────────────────

class _ProductFormSheet extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;

  const _ProductFormSheet({this.existing, required this.onSaved});

  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<_ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  bool _saving = false;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _name,
      _sku,
      _category,
      _purchasePrice,
      _sellingPrice,
      _quantity,
      _reorderLevel,
      _unit,
      _desc;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?['product_name'] ?? '');
    _sku = TextEditingController(text: e?['sku'] ?? '');
    _category = TextEditingController(text: e?['category'] ?? '');
    _purchasePrice =
        TextEditingController(text: e?['purchase_price']?.toString() ?? '');
    _sellingPrice =
        TextEditingController(text: e?['selling_price']?.toString() ?? '');
    _quantity = TextEditingController(text: e?['quantity']?.toString() ?? '0');
    _reorderLevel =
        TextEditingController(text: e?['reorder_level']?.toString() ?? '10');
    _unit = TextEditingController(text: e?['unit'] ?? 'pcs');
    _desc = TextEditingController(text: e?['description'] ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _sku,
      _category,
      _purchasePrice,
      _sellingPrice,
      _quantity,
      _reorderLevel,
      _unit,
      _desc
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final data = {
      'product_name': _name.text.trim(),
      'sku': _sku.text.trim().isEmpty ? null : _sku.text.trim(),
      'category': _category.text.trim().isEmpty ? null : _category.text.trim(),
      'purchase_price': double.parse(_purchasePrice.text),
      'selling_price': double.parse(_sellingPrice.text),
      'quantity': int.parse(_quantity.text),
      'reorder_level': int.parse(_reorderLevel.text),
      'unit': _unit.text.trim().isEmpty ? 'pcs' : _unit.text.trim(),
      'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
    };

    final auth = Provider.of<AuthProvider>(context, listen: false);

    try {
      if (widget.existing != null) {
        if (_imageFile != null) {
          await auth.callWithAutoRefresh(
            (token) => _api.updateProductWithImage(
                token, widget.existing!['id'], data, _imageFile!.path),
          );
        } else {
          await auth.callWithAutoRefresh(
            (token) => _api.updateProduct(token, widget.existing!['id'], data),
          );
        }
      } else {
        if (_imageFile != null) {
          await auth.callWithAutoRefresh(
            (token) =>
                _api.createProductWithImage(token, data, _imageFile!.path),
          );
        } else {
          await auth.callWithAutoRefresh(
            (token) => _api.createProduct(token, data),
          );
        }
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${AppLocalizations.of(context)!.errorPrefix}: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
          source: ImageSource.gallery, maxWidth: 1200, imageQuality: 80);
      if (picked != null) setState(() => _imageFile = File(picked.path));
    } catch (e) {
      // ignore
    }
  }

  Future<void> _delete() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dl = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(dl.deleteProductTitle),
          content: Text('${widget.existing!['product_name']} মুছে ফেলা হবে।'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(dl.cancel)),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(dl.deleteBtn, style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    if (ok != true) return;
    await auth.callWithAutoRefresh(
      (token) => _api.deleteProduct(token, widget.existing!['id']),
    );
    widget.onSaved();
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image picker
              Row(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                      ),
                      child: _imageFile == null
                          ? const Icon(Icons.camera_alt_outlined, size: 28)
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(_imageFile!, fit: BoxFit.cover),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(l.addImageOptional),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    widget.existing == null
                        ? 'নতুন পণ্য যোগ করুন'
                        : 'পণ্য সম্পাদনা',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  if (widget.existing != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: _delete,
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _field(_name, 'পণ্যের নাম *',
                  validator: (v) => v!.isEmpty ? 'পণ্যের নাম দিন' : null),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _field(_sku, 'SKU / কোড')),
                const SizedBox(width: 12),
                Expanded(child: _field(_category, 'ক্যাটাগরি')),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _field(_purchasePrice, 'ক্রয়মূল্য (৳) *',
                        keyboard: TextInputType.number,
                        validator: (v) => v!.isEmpty ? 'দাম দিন' : null)),
                const SizedBox(width: 12),
                Expanded(
                    child: _field(_sellingPrice, 'বিক্রয়মূল্য (৳) *',
                        keyboard: TextInputType.number,
                        validator: (v) => v!.isEmpty ? 'দাম দিন' : null)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _field(_quantity, 'পরিমাণ *',
                        keyboard: TextInputType.number,
                        validator: (v) => v!.isEmpty ? 'পরিমাণ দিন' : null)),
                const SizedBox(width: 12),
                Expanded(
                    child: _field(_reorderLevel, 'রিঅর্ডার লেভেল',
                        keyboard: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _field(_unit, 'ইউনিট')),
              ]),
              const SizedBox(height: 12),
              _field(_desc, 'বিবরণ', maxLines: 2),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(l.save,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
