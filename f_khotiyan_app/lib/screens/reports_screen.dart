import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _report;
  bool _loading = false;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

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
      final res = await _api.getReports(_token(),
          startDate: _fmt(_startDate), endDate: _fmt(_endDate));
      // Normalize nested API response into a flat map the UI expects
      final overview = res['overview'] as Map<String, dynamic>? ?? {};
      final revenue = res['revenue'] as Map<String, dynamic>? ?? {};
      final profitLoss = res['profit_loss'] as Map<String, dynamic>? ?? {};
      final capital = res['capital'] as Map<String, dynamic>? ?? {};
      final stock = res['stock'] as Map<String, dynamic>? ?? {};
      final expenses = res['expenses'] as Map<String, dynamic>? ?? {};
      final returns = res['returns'] as Map<String, dynamic>? ?? {};
      final dailyTrend = res['daily_trend'] as List<dynamic>? ?? [];

      setState(() => _report = {
            // Summary cards
            'total_revenue': revenue['gross_revenue'] ?? 0,
            'total_profit': profitLoss['gross_profit'] ?? 0,
            'total_expenses':
                profitLoss['total_expenses'] ?? expenses['total'] ?? 0,
            'net_profit': profitLoss['net_profit'] ?? 0,
            // Orders
            'total_orders': overview['total_orders'] ?? 0,
            'delivered_orders': overview['delivered_orders'] ?? 0,
            'cancelled_orders': overview['cancelled_orders'] ?? 0,
            'returned_orders': overview['returned_orders'] ?? 0,
            'pending_orders': overview['pending_orders'] ?? 0,
            'delivery_success_rate': overview['delivery_success_rate'] ?? 0,
            // Revenue detail
            'sales_revenue': revenue['sales_revenue'] ?? 0,
            'delivery_revenue': revenue['delivery_revenue'] ?? 0,
            'discount_given': revenue['discount_given'] ?? 0,
            'cogs': profitLoss['cogs'] ?? 0,
            'operating_profit': profitLoss['operating_profit'] ?? 0,
            // Capital
            'total_capital': capital['net_capital'] ?? 0,
            'total_invested': capital['total_invested'] ?? 0,
            'total_withdrawn': capital['total_withdrawn'] ?? 0,
            'roi': capital['roi'] ?? 0,
            // Expenses
            'expenses_by_category': expenses['by_category'] ?? [],
            // Stock
            'stock_report': (stock['products'] as List<dynamic>? ?? [])
                .map<Map<String, dynamic>>((p) => {
                      'name': (p['product_name'] ?? p['name'] ?? '').toString(),
                      'quantity': p['quantity'] ?? 0,
                      'sku': p['sku'] ?? '',
                    })
                .toList(),
            'stock_value': stock['stock_value'] ?? 0,
            'low_stock_count': stock['low_stock_count'] ?? 0,
            // Returns
            'total_returns': returns['total'] ?? 0,
            'total_refund_amount': returns['total_refunded'] ?? 0,
            // Daily trend
            'daily_trend': dailyTrend,
          });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ত্রুটি: $e')));
      }
    }
    setState(() => _loading = false);
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('রিপোর্ট'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          // Date range picker
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(true),
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: Text(_fmt(_startDate),
                        style: const TextStyle(fontSize: 12)),
                  ),
                ),
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('থেকে')),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(false),
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: Text(_fmt(_endDate),
                        style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_report == null)
            const Expanded(child: Center(child: Text('ডেটা পাওয়া যায়নি')))
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    // ── Summary Cards ──
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.6,
                      children: [
                        _summaryCard('মোট রাজস্ব',
                            '৳${_report!['total_revenue'] ?? 0}', Colors.blue),
                        _summaryCard('মোট লাভ',
                            '৳${_report!['total_profit'] ?? 0}', Colors.green),
                        _summaryCard(
                            'মোট খরচ',
                            '৳${_report!['total_expenses'] ?? 0}',
                            Colors.orange),
                        _summaryCard(
                            'নিট লাভ',
                            '৳${_report!['net_profit'] ?? 0}',
                            double.tryParse((_report!['net_profit'] ?? 0)
                                            .toString()) !=
                                        null &&
                                    double.parse((_report!['net_profit'] ?? 0)
                                            .toString()) >=
                                        0
                                ? Colors.teal
                                : Colors.red),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Orders ──
                    _section('অর্ডার সামারি', [
                      _row2('মোট অর্ডার',
                          (_report!['total_orders'] ?? 0).toString()),
                      _row2('ডেলিভারি সফল',
                          (_report!['delivered_orders'] ?? 0).toString()),
                      _row2('বাতিল',
                          (_report!['cancelled_orders'] ?? 0).toString()),
                      _row2('রিটার্ন',
                          (_report!['returned_orders'] ?? 0).toString()),
                    ]),
                    const SizedBox(height: 12),

                    // ── Expenses by Category ──
                    if (_report!['expenses_by_category'] != null) ...[
                      _sectionHeader('ক্যাটাগরি অনুযায়ী খরচ'),
                      ...(_report!['expenses_by_category'] as List).map(
                        (e) => _rowTile(
                          e['category'] ?? '',
                          '৳${e['total'] ?? e['amount'] ?? 0}',
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── Capital & ROI ──
                    _section('মূলধন ও ROI', [
                      _row2(
                          'মোট বিনিয়োগ', '৳${_report!['total_capital'] ?? 0}'),
                      _row2('ROI', '${_report!['roi'] ?? 0}%'),
                    ]),
                    const SizedBox(height: 12),

                    // ── Stock Summary ──
                    if (_report!['stock_report'] != null) ...[
                      _sectionHeader('স্টক সামারি'),
                      ...(_report!['stock_report'] as List).map(
                        (s) => _rowTile(
                          s['name'] ?? '',
                          'স্টক: ${s['quantity'] ?? 0}',
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── Returns Summary ──
                    _section('রিটার্ন সামারি', [
                      _row2('মোট রিটার্ন',
                          (_report!['total_returns'] ?? 0).toString()),
                      _row2('ফেরত পরিমাণ',
                          '৳${_report!['total_refund_amount'] ?? 0}'),
                    ]),
                    const SizedBox(height: 12),

                    // ── Revenue Detail ──
                    _section('রাজস্ব বিবরণ', [
                      _row2(
                          'পণ্য বিক্রয়', '৳${_report!['sales_revenue'] ?? 0}'),
                      _row2('ডেলিভারি চার্জ',
                          '৳${_report!['delivery_revenue'] ?? 0}'),
                      _row2(
                          'ছাড় দেওয়া', '৳${_report!['discount_given'] ?? 0}'),
                      _row2('COGS (পণ্য খরচ)', '৳${_report!['cogs'] ?? 0}'),
                      _row2('অপারেটিং লাভ',
                          '৳${_report!['operating_profit'] ?? 0}'),
                    ]),
                    const SizedBox(height: 12),

                    // ── Daily Trend ──
                    if ((_report!['daily_trend'] as List?)?.isNotEmpty ==
                        true) ...[
                      _sectionHeader('দৈনিক ট্রেন্ড'),
                      ...(_report!['daily_trend'] as List).map(
                        (d) => _rowTile(
                          d['date']?.toString() ?? '',
                          '${d['count'] ?? 0} অর্ডার · ৳${d['revenue'] ?? 0}',
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8))),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      );

  Widget _section(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row2(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      );

  Widget _rowTile(String label, String value) => ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(label, style: const TextStyle(fontSize: 13)),
        trailing: Text(value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      );
}
