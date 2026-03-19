import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class OrderTrackingScreen extends StatefulWidget {
  final int orderId;
  final String orderNumber;
  const OrderTrackingScreen(
      {super.key, required this.orderId, required this.orderNumber});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final _api = ApiService();
  bool _loading = true;
  Map<String, dynamic>? _data;
  String? _error;

  String _token() =>
      Provider.of<AuthProvider>(context, listen: false).accessToken ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.trackCourier(_token(), widget.orderId);
      setState(() => _data = res);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _openTrackingUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('লিঙ্ক খোলা যাচ্ছে না।')));
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$label কপি হয়েছে')));
  }

  Color _courierColor(String courier) {
    switch (courier) {
      case 'steadfast':
        return Colors.deepPurple;
      case 'pathao':
        return Colors.orange.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  IconData _courierIcon(String courier) {
    switch (courier) {
      case 'steadfast':
        return Icons.local_shipping_rounded;
      case 'pathao':
        return Icons.delivery_dining_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  String _courierLabel(String courier) {
    switch (courier) {
      case 'steadfast':
        return 'Steadfast';
      case 'pathao':
        return 'Pathao';
      default:
        return 'নিজস্ব ডেলিভারি';
    }
  }

  String _statusBn(String? status) {
    if (status == null || status.isEmpty) return 'অজানা';
    const map = {
      'pending': 'অপেক্ষারত',
      'in_review': 'রিভিউতে আছে',
      'delivered': 'ডেলিভারি সম্পন্ন',
      'delivered_approval_pending': 'ডেলিভারি অ্যাপ্রুভাল পেন্ডিং',
      'partial_delivered': 'আংশিক ডেলিভারি',
      'partial_delivered_approval_pending': 'আংশিক ডেলিভারি পেন্ডিং',
      'cancelled': 'বাতিল',
      'cancelled_approval_pending': 'বাতিল পেন্ডিং',
      'hold': 'হোল্ড',
      'unknown': 'অজানা',
      'processing': 'প্রক্রিয়াকরণ',
      'shipped': 'পাঠানো হয়েছে',
      'Pending': 'অপেক্ষারত',
      'Delivered': 'ডেলিভারি সম্পন্ন',
      'Cancelled': 'বাতিল',
    };
    return map[status] ?? status;
  }

  Color _statusColor(String? status) {
    if (status == null) return Colors.grey;
    if (status.contains('delivered') || status == 'Delivered') {
      return Colors.green;
    }
    if (status.contains('cancel') || status == 'Cancelled') return Colors.red;
    if (status.contains('hold')) return Colors.orange;
    if (status.contains('pending') || status == 'Pending') return Colors.blue;
    return Colors.teal;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ট্র্যাকিং — ${widget.orderNumber}'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildBody(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
              onPressed: _load, child: const Text('আবার চেষ্টা করুন')),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final d = _data!;
    final courier = d['courier']?.toString() ?? 'self';
    final consignmentId = d['consignment_id']?.toString() ?? '';
    final trackingCode = d['tracking_code']?.toString() ?? '';
    final trackingUrl = d['tracking_url']?.toString();
    final status = d['status']?.toString();
    final cachedStatus = d['cached_status']?.toString();
    final liveData = d['live_data'] as Map<String, dynamic>?;
    final hasConsignment = consignmentId.isNotEmpty;
    final color = _courierColor(courier);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Courier Header Card ──
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.85), color],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(_courierIcon(courier), color: Colors.white, size: 40),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_courierLabel(courier),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700)),
                        if (status != null && status.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(_statusBn(status),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                  ),
                  if (status != null)
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: _statusColor(status),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── No Consignment ──
          if (!hasConsignment)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 40, color: Colors.grey),
                    const SizedBox(height: 8),
                    Text(
                        d['message'] ??
                            'এই অর্ডারে এখনো কোনো কুরিয়ার কনসাইনমেন্ট নেই।',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),

          // ── Consignment Details ──
          if (hasConsignment) ...[
            _detailCard('কনসাইনমেন্ট বিবরণ', [
              if (consignmentId.isNotEmpty)
                _detailRow('Consignment ID', consignmentId,
                    copyable: true,
                    onCopy: () =>
                        _copyToClipboard(consignmentId, 'Consignment ID')),
              if (trackingCode.isNotEmpty && trackingCode != consignmentId)
                _detailRow('Tracking Code', trackingCode,
                    copyable: true,
                    onCopy: () =>
                        _copyToClipboard(trackingCode, 'Tracking Code')),
              if (status != null && status.isNotEmpty)
                _detailRow('লাইভ স্ট্যাটাস', _statusBn(status),
                    valueColor: _statusColor(status)),
              if (cachedStatus != null &&
                  cachedStatus.isNotEmpty &&
                  cachedStatus != status)
                _detailRow('সংরক্ষিত স্ট্যাটাস', _statusBn(cachedStatus),
                    valueColor: Colors.grey),
            ]),
            const SizedBox(height: 12),
          ],

          // ── Live Courier Data ──
          if (liveData != null && liveData.isNotEmpty) ...[
            _detailCard(
              courier == 'steadfast'
                  ? 'Steadfast লাইভ তথ্য'
                  : 'Pathao লাইভ তথ্য',
              _buildLiveDataRows(courier, liveData),
            ),
            const SizedBox(height: 12),
          ],

          // ── Tracking URL ──
          if (trackingUrl != null) ...[
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('ট্র্যাকিং লিঙ্ক',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              trackingUrl,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.blue.shade700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            tooltip: 'কপি করুন',
                            onPressed: () => _copyToClipboard(
                                trackingUrl, 'ট্র্যাকিং লিঙ্ক'),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _openTrackingUrl(trackingUrl),
                            icon: const Icon(Icons.open_in_browser_rounded),
                            label: const Text('ব্রাউজারে খুলুন'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: color,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Refresh note ──
          Center(
            child: Text(
              'রিফ্রেশ করুন সর্বশেষ স্ট্যাটাস দেখতে',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<Widget> _buildLiveDataRows(String courier, Map<String, dynamic> data) {
    final rows = <Widget>[];
    if (courier == 'steadfast') {
      final fields = {
        'consignment_id': 'Consignment ID',
        'tracking_code': 'Tracking Code',
        'delivery_status': 'ডেলিভারি স্ট্যাটাস',
        'recipient_name': 'প্রাপক',
        'recipient_address': 'ঠিকানা',
        'cod_amount': 'COD পরিমাণ',
        'note': 'নোট',
      };
      for (final e in fields.entries) {
        final val = data[e.key]?.toString();
        if (val != null && val.isNotEmpty) {
          rows.add(_detailRow(
            e.value,
            e.key == 'delivery_status' ? _statusBn(val) : val,
            valueColor: e.key == 'delivery_status' ? _statusColor(val) : null,
          ));
        }
      }
    } else if (courier == 'pathao') {
      final fields = {
        'consignment_id': 'Consignment ID',
        'order_status': 'অর্ডার স্ট্যাটাস',
        'order_status_slug': 'স্ট্যাটাস কোড',
        'recipient_name': 'প্রাপক',
        'recipient_phone': 'ফোন',
        'recipient_address': 'ঠিকানা',
        'amount_to_collect': 'কালেকশন পরিমাণ',
        'delivery_fee': 'ডেলিভারি ফি',
        'merchant_order_id': 'অর্ডার নং',
      };
      for (final e in fields.entries) {
        final val = data[e.key]?.toString();
        if (val != null && val.isNotEmpty) {
          rows.add(_detailRow(
            e.value,
            e.key.contains('status') ? _statusBn(val) : val,
            valueColor: e.key.contains('status') ? _statusColor(val) : null,
          ));
        }
      }
    }
    return rows.isEmpty
        ? [
            const Text('তথ্য পাওয়া যায়নি',
                style: TextStyle(color: Colors.grey))
          ]
        : rows;
  }

  Widget _detailCard(String title, List<Widget> children) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const Divider(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    bool copyable = false,
    VoidCallback? onCopy,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: valueColor,
              ),
            ),
          ),
          if (copyable && onCopy != null)
            GestureDetector(
              onTap: onCopy,
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.copy_rounded, size: 15, color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }
}
