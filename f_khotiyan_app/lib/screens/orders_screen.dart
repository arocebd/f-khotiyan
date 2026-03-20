import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/native_ad_widget.dart';
import 'create_order_screen.dart';
import 'ai_order_screen.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _api = ApiService();
  List<dynamic> _orders = [];
  bool _loading = true;
  int _page = 1;
  int? _totalCount;
  String? _statusFilter;

  final List<String> _statusValues = const [
    '',
    'pending',
    'processing',
    'shipped',
    'delivered',
    'cancelled',
    'returned',
  ];

  String _token() =>
      Provider.of<AuthProvider>(context, listen: false).accessToken ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = true}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _page = 1;
      });
    }
    try {
      final res = await _api.getOrders(
        _token(),
        status: _statusFilter?.isEmpty == true ? null : _statusFilter,
        page: _page,
      );
      final results = res['results'] ?? res;
      setState(() {
        _orders = results is List ? results : [];
        _totalCount = res['count'];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text('${l.ordersTitle}${_totalCount != null ? ' ($_totalCount)' : ''}'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          // Status filter chips
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _statusValues.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (ctx, i) {
                final value = _statusValues[i];
                final labels = [
                  l.all,
                  l.statusPending,
                  l.statusProcessing,
                  l.statusShipped,
                  l.statusDelivered,
                  l.statusCancelled,
                  l.statusReturned,
                ];
                final selected = (_statusFilter ?? '') == value;
                return FilterChip(
                  label: Text(labels[i],
                      style: TextStyle(
                          fontSize: 12, color: selected ? Colors.white : null)),
                  selected: selected,
                  selectedColor: Theme.of(context).colorScheme.primary,
                  onSelected: (_) {
                    _statusFilter = value;
                    _load();
                  },
                );
              },
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_orders.isEmpty)
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
                    Text(l.noOrdersFound),
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
                  // Every 6th item (index 5, 11, 17…) is a native ad
                  itemCount: _orders.length + (_orders.length ~/ 5),
                  itemBuilder: (ctx, i) {
                    // Insert a native ad after every 5 orders
                    const adEvery = 6; // 5 orders + 1 ad slot
                    if ((i + 1) % adEvery == 0) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: NativeAdWidget(),
                      );
                    }
                    final orderIndex = i - (i ~/ adEvery);
                    if (orderIndex >= _orders.length) {
                      return const SizedBox.shrink();
                    }
                    return _OrderTile(
                      order: _orders[orderIndex],
                      onRefresh: _load,
                    );
                  },
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'ai',
            mini: true,
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AiOrderScreen()));
              _load();
            },
            backgroundColor: Colors.teal,
            child: const Icon(Icons.camera_alt_rounded),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'manual',
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CreateOrderScreen()));
              _load();
            },
            icon: const Icon(Icons.add_rounded),
            label: Text(l.newOrder),
          ),
        ],
      ),
    );
  }
}

// ─── Order Tile ───────────────────────────────────────────────────────────

class _OrderTile extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onRefresh;
  const _OrderTile({required this.order, required this.onRefresh});

  static const _statusColor = {
    'pending': Colors.orange,
    'processing': Colors.blue,
    'shipped': Colors.indigo,
    'delivered': Colors.green,
    'cancelled': Colors.red,
    'returned': Colors.purple,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final statusLabel = {
      'pending': l.statusPending,
      'processing': l.statusProcessing,
      'shipped': l.statusShipped,
      'delivered': l.statusDelivered,
      'cancelled': l.statusCancelled,
      'returned': l.statusReturned,
    };
    final st = order['order_status'] ?? 'pending';
    final color = _statusColor[st] ?? Colors.grey;
    final theme = Theme.of(context);
    final isAi = order['created_from_image'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => OrderDetailScreen(
                    orderId: order['id'], onRefresh: onRefresh)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order['order_number'] ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                  if (isAi)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('AI',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.teal,
                              fontWeight: FontWeight.bold)),
                    ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: (color as Color).withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusLabel[st] ?? st,
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                order['customer_name'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                order['customer_phone'] ?? '',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '৳${order['grand_total']}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  _smsBadge(order),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _smsBadge(Map<String, dynamic> order) {
    if (order['sms_sent'] == true) {
      return const Row(children: [
        Icon(Icons.sms_rounded, size: 14, color: Colors.green),
        SizedBox(width: 3),
        Text('SMS', style: TextStyle(fontSize: 11, color: Colors.green)),
      ]);
    }
    return const SizedBox.shrink();
  }
}
