import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key});
  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  final _api = ApiService();
  List<dynamic> _returns = [];
  bool _loading = true;
  String? _statusFilter;

  static const _statuses = [
    {'value': '', 'label': 'সব'},
    {'value': 'pending', 'label': 'অপেক্ষারত'},
    {'value': 'approved', 'label': 'অনুমোদিত'},
    {'value': 'rejected', 'label': 'প্রত্যাখ্যাত'},
    {'value': 'refunded', 'label': 'ফেরত দেওয়া হয়েছে'},
  ];

  static const _reasons = [
    {'value': 'defective', 'label': 'ত্রুটিপূর্ণ পণ্য'},
    {'value': 'wrong_item', 'label': 'ভুল পণ্য পাঠানো'},
    {'value': 'not_delivered', 'label': 'ডেলিভারি হয়নি'},
    {'value': 'size_issue', 'label': 'সাইজ/রঙ সমস্যা'},
    {'value': 'customer_request', 'label': 'গ্রাহকের অনুরোধ'},
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
    if (mounted) setState(() => _loading = true);
    try {
      final res = await _api.getReturns(_token());
      final list = res['results'] ?? res ?? [];
      if (mounted) {
        setState(() => _returns = list is List ? list : []);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('লোড করতে সমস্যা: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> get _filtered {
    if (_statusFilter == null || _statusFilter!.isEmpty) return _returns;
    return _returns.where((r) => r['status'] == _statusFilter).toList();
  }

  void _openCreateForm() {
    final searchCtrl = TextEditingController();
    final refundCtrl = TextEditingController();
    String reason = 'customer_request';
    final formKey = GlobalKey<FormState>();
    bool saving = false;
    bool searching = false;
    List<Map<String, dynamic>> searchResults = [];
    Map<String, dynamic>? selectedOrder;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => SingleChildScrollView(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              left: 16,
              right: 16,
              top: 16),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('নতুন রিটার্ন',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),

                // ── Order search ──
                if (selectedOrder == null) ...[
                  TextFormField(
                    controller: searchCtrl,
                    decoration: _dec('অর্ডার নম্বর বা কাস্টমার নাম').copyWith(
                      suffixIcon: searching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            )
                          : IconButton(
                              icon: const Icon(Icons.search_rounded),
                              onPressed: () async {
                                final q = searchCtrl.text.trim();
                                if (q.isEmpty) return;
                                setModal(() => searching = true);
                                try {
                                  final res = await _api.getOrders(_token(),
                                      search: q, page: 1);
                                  final results = (res['results'] ??
                                      res['orders'] ??
                                      []) as List;
                                  setModal(() => searchResults = results
                                      .map((o) =>
                                          Map<String, dynamic>.from(o as Map))
                                      .toList());
                                } catch (_) {
                                } finally {
                                  setModal(() => searching = false);
                                }
                              },
                            ),
                    ),
                    onFieldSubmitted: (_) async {
                      final q = searchCtrl.text.trim();
                      if (q.isEmpty) return;
                      setModal(() => searching = true);
                      try {
                        final res =
                            await _api.getOrders(_token(), search: q, page: 1);
                        final results =
                            (res['results'] ?? res['orders'] ?? []) as List;
                        setModal(() => searchResults = results
                            .map((o) => Map<String, dynamic>.from(o as Map))
                            .toList());
                      } catch (_) {
                      } finally {
                        setModal(() => searching = false);
                      }
                    },
                    validator: (_) =>
                        selectedOrder == null ? 'অর্ডার নির্বাচন করুন' : null,
                  ),
                  if (searchResults.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: searchResults.take(5).map((o) {
                          return ListTile(
                            dense: true,
                            title: Text(
                                o['order_number']?.toString() ?? '#${o['id']}'),
                            subtitle: Text(
                                '${o['customer_name'] ?? ''} · ৳${o['grand_total'] ?? 0}'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => setModal(() {
                              selectedOrder = o;
                              searchResults = [];
                            }),
                          );
                        }).toList(),
                      ),
                    ),
                  ] else if (!searching && searchCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('কোনো অর্ডার পাওয়া যায়নি',
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ] else ...[
                  // ── Selected order display ──
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green.shade200),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Colors.green, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedOrder!['order_number']?.toString() ??
                                    '#${selectedOrder!['id']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              Text(
                                '${selectedOrder!['customer_name'] ?? ''} · ৳${selectedOrder!['grand_total'] ?? 0}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 18, color: Colors.grey),
                          tooltip: 'পরিবর্তন করুন',
                          onPressed: () => setModal(() {
                            selectedOrder = null;
                            searchCtrl.clear();
                          }),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  decoration: _dec('কারণ'),
                  items: _reasons
                      .map((r) => DropdownMenuItem(
                          value: r['value'], child: Text(r['label']!)))
                      .toList(),
                  onChanged: (v) => setModal(() => reason = v!),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: refundCtrl,
                  decoration: _dec('ফেরত পরিমাণ (৳)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: saving || selectedOrder == null
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setModal(() => saving = true);
                          try {
                            await _api.createReturn(_token(), {
                              'order': selectedOrder!['id'] as int,
                              'reason': reason,
                              'refund_amount': refundCtrl.text.trim().isEmpty
                                  ? 0
                                  : double.parse(refundCtrl.text.trim()),
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                            await _load();
                          } catch (e) {
                            setModal(() => saving = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                  content: Text('ত্রুটি: $e'),
                                  backgroundColor: Colors.red));
                            }
                            return;
                          }
                          setModal(() => saving = false);
                        },
                  child: saving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('রিটার্ন তৈরি করুন'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateStatus(Map<String, dynamic> ret, String newStatus) async {
    try {
      await _api.updateReturn(_token(), ret['id'], {'status': newStatus});
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ত্রুটি: $e')));
      }
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      );

  String _reasonLabel(String? v) => _reasons.firstWhere((r) => r['value'] == v,
      orElse: () => {'label': v ?? ''})['label']!;

  static const _statusColor = {
    'pending': Colors.orange,
    'approved': Colors.blue,
    'rejected': Colors.red,
    'refunded': Colors.green,
  };

  static const _statusLabel = {
    'pending': 'অপেক্ষারত',
    'approved': 'অনুমোদিত',
    'rejected': 'প্রত্যাখ্যাত',
    'refunded': 'ফেরত দেওয়া হয়েছে',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('রিটার্ন ব্যবস্থাপনা'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _statuses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (ctx, i) {
                final opt = _statuses[i];
                final selected = (_statusFilter ?? '') == opt['value'];
                return FilterChip(
                  label: Text(opt['label']!,
                      style: TextStyle(
                          fontSize: 12, color: selected ? Colors.white : null)),
                  selected: selected,
                  selectedColor: Theme.of(context).colorScheme.primary,
                  onSelected: (_) =>
                      setState(() => _statusFilter = opt['value']),
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
                    Icon(Icons.assignment_return_outlined,
                        size: 64,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    const Text('কোনো রিটার্ন পাওয়া যায়নি'),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _filtered.length,
                  itemBuilder: (ctx, i) {
                    final r = _filtered[i] as Map<String, dynamic>;
                    final status = r['status'] ?? 'pending';
                    final color = _statusColor[status] ?? Colors.grey;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(r['return_number'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (color as Color)
                                        .withValues(alpha: 0.13),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _statusLabel[status] ?? status,
                                    style: TextStyle(
                                        color: color,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('অর্ডার: ${r['order_number'] ?? r['order']}'),
                            Text('গ্রাহক: ${r['customer_name'] ?? ''}'),
                            Text('কারণ: ${_reasonLabel(r['reason'])}'),
                            if ((r['refund_amount'] ?? 0) > 0)
                              Text('ফেরত: ৳${r['refund_amount']}',
                                  style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              children: [
                                if (status == 'pending') ...[
                                  ActionChip(
                                    label: const Text('অনুমোদন',
                                        style: TextStyle(fontSize: 11)),
                                    backgroundColor:
                                        Colors.blue.withValues(alpha: 0.13),
                                    onPressed: () =>
                                        _updateStatus(r, 'approved'),
                                  ),
                                  ActionChip(
                                    label: const Text('প্রত্যাখ্যান',
                                        style: TextStyle(fontSize: 11)),
                                    backgroundColor:
                                        Colors.red.withValues(alpha: 0.13),
                                    onPressed: () =>
                                        _updateStatus(r, 'rejected'),
                                  ),
                                ],
                                if (status == 'approved')
                                  ActionChip(
                                    label: const Text('ফেরত দিন',
                                        style: TextStyle(
                                            fontSize: 11, color: Colors.white)),
                                    backgroundColor: Colors.green,
                                    onPressed: () =>
                                        _updateStatus(r, 'refunded'),
                                  ),
                              ],
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
        onPressed: _openCreateForm,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
