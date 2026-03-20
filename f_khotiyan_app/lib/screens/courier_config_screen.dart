import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';

class CourierConfigScreen extends StatefulWidget {
  const CourierConfigScreen({super.key});
  @override
  State<CourierConfigScreen> createState() => _CourierConfigScreenState();
}

class _CourierConfigScreenState extends State<CourierConfigScreen> {
  final _api = ApiService();
  List<dynamic> _configs = [];
  bool _loading = true;
  bool _checkingBalance = false;
  String? _balanceMsg;
  bool _checkingPathaoBalance = false;
  String? _pathaoBalanceMsg;
  bool _pathaoConfigExists = false;

  static const _courierOptions = [
    {'value': 'steadfast', 'label': 'Steadfast'},
    {'value': 'pathao', 'label': 'Pathao'},
    {'value': 'redx', 'label': 'RedX'},
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
      final res = await _api.getCourierConfigs(_token());
      final list = res['results'] ?? res ?? [];
      setState(() {
        _configs = list is List ? list : [];
        _pathaoConfigExists =
            _configs.any((c) => c['courier_name'] == 'pathao');
      });
    } catch (_) {}
    setState(() => _loading = false);
    // Auto-load balance if steadfast config exists
    _checkSteadfastBalance();
    _checkPathaoBalance();
  }

  Future<void> _checkSteadfastBalance() async {
    setState(() => _checkingBalance = true);
    try {
      final res = await _api.getSteadfastBalance(_token());
      if (!mounted) return;
      if (res['success'] == true) {
        setState(() => _balanceMsg = '৳${res['current_balance'] ?? 0}');
      } else {
        setState(() => _balanceMsg = null);
      }
    } catch (_) {
      if (mounted) setState(() => _balanceMsg = null);
    } finally {
      if (mounted) setState(() => _checkingBalance = false);
    }
  }

  Future<void> _checkPathaoBalance() async {
    setState(() => _checkingPathaoBalance = true);
    try {
      final res = await _api.getPathaoBalance(_token());
      if (!mounted) return;
      if (res['success'] == true) {
        setState(() => _pathaoBalanceMsg =
            '৳${res['current_balance'] ?? 0}  (উইথড্র: ৳${res['withdraw_balance'] ?? 0})');
      } else {
        // Show the error/unavailable message in the card
        setState(() => _pathaoBalanceMsg = res['message'] ?? 'N/A');
      }
    } catch (_) {
      if (mounted) setState(() => _pathaoBalanceMsg = 'N/A');
    } finally {
      if (mounted) setState(() => _checkingPathaoBalance = false);
    }
  }

  void _openForm({Map<String, dynamic>? config}) {
    String courierType = config?['courier_name'] ?? 'steadfast';
    // Steadfast fields
    final apiKeyCtrl = TextEditingController(text: config?['api_key'] ?? '');
    final secretCtrl = TextEditingController(text: config?['api_secret'] ?? '');
    // Pathao fields
    final clientIdCtrl =
        TextEditingController(text: config?['client_id'] ?? '');
    final clientSecretCtrl =
        TextEditingController(text: config?['client_secret'] ?? '');
    final usernameCtrl = TextEditingController(); // always blank for security
    final passwordCtrl = TextEditingController(); // always blank for security
    final storeIdCtrl =
        TextEditingController(text: config?['store_id']?.toString() ?? '');
    bool isSandbox = config?['pathao_is_sandbox'] ?? false;
    bool isActive = config?['is_active'] ?? true;
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    // Pathao store picker state
    List<Map<String, dynamic>> storeList = [];
    String? selectedStoreId = config?['store_id']?.toString();
    String? selectedStoreName;

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
                Text(
                  config == null
                      ? 'কুরিয়ার কনফিগ যোগ করুন'
                      : 'কুরিয়ার কনফিগ সম্পাদনা',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: courierType,
                  decoration: _dec('কুরিয়ার'),
                  items: _courierOptions
                      .map((c) => DropdownMenuItem(
                          value: c['value'], child: Text(c['label']!)))
                      .toList(),
                  onChanged: (v) => setModal(() => courierType = v!),
                ),
                const SizedBox(height: 10),
                // ── Steadfast fields ──
                if (courierType == 'steadfast') ...[
                  TextFormField(
                    controller: apiKeyCtrl,
                    decoration: _dec('API Key'),
                    validator: (v) =>
                        v?.isEmpty == true ? 'API Key লিখুন' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: secretCtrl,
                    decoration: _dec('Secret Key'),
                    obscureText: true,
                  ),
                ],
                // ── Pathao fields ──
                if (courierType == 'pathao') ...[
                  TextFormField(
                    controller: clientIdCtrl,
                    decoration: _dec('Client ID'),
                    validator: (v) =>
                        v?.isEmpty == true ? 'Client ID লিখুন' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: clientSecretCtrl,
                    decoration: _dec('Client Secret'),
                    obscureText: true,
                    validator: (v) =>
                        v?.isEmpty == true ? 'Client Secret লিখুন' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: usernameCtrl,
                    decoration: _dec('ইমেইল (username)'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v?.isEmpty == true ? 'ইমেইল লিখুন' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: passwordCtrl,
                    decoration: _dec('পাসওয়ার্ড'),
                    obscureText: true,
                    validator: (v) =>
                        v?.isEmpty == true ? 'পাসওয়ার্ড লিখুন' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: storeIdCtrl,
                    decoration: _dec('Store ID'),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        v?.isEmpty == true ? 'Store ID লিখুন' : null,
                  ),
                  const SizedBox(height: 10),
                  // Store dropdown — shows after connecting to auto-fill Store ID
                  if (storeList.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      key: ValueKey(selectedStoreId),
                      initialValue: selectedStoreId,
                      decoration: _dec('স্টোর নির্বাচন করুন'),
                      items: storeList
                          .map((s) => DropdownMenuItem<String>(
                                value: s['store_id'].toString(),
                                child: Text(
                                    '${s['store_name']} (ID: ${s['store_id']})'),
                              ))
                          .toList(),
                      onChanged: (v) {
                        setModal(() {
                          selectedStoreId = v;
                          storeIdCtrl.text = v ?? '';
                          selectedStoreName = storeList
                              .firstWhere((s) => s['store_id'].toString() == v,
                                  orElse: () => {})['store_name']
                              ?.toString();
                        });
                      },
                    ),
                    const SizedBox(height: 4),
                  ],
                  SwitchListTile(
                    title: const Text('Sandbox Mode (টেস্ট)'),
                    subtitle: const Text('প্রোডাকশনে বন্ধ করুন'),
                    value: isSandbox,
                    onChanged: (v) => setModal(() => isSandbox = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
                const SizedBox(height: 4),
                SwitchListTile(
                  title: const Text('সক্রিয়'),
                  value: isActive,
                  onChanged: (v) => setModal(() => isActive = v),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setModal(() => saving = true);
                          try {
                            if (courierType == 'pathao' &&
                                storeList.isNotEmpty &&
                                storeIdCtrl.text.trim().isNotEmpty) {
                              // Second press: save selected store
                              await _api.setPathaoStore(
                                  _token(), storeIdCtrl.text.trim());
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              _load();
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'স্টোর সেভ হয়েছে: ${selectedStoreName ?? storeIdCtrl.text}'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else if (courierType == 'pathao') {
                              // First press: Connect and get stores
                              final res = await _api.connectPathao(_token(), {
                                'client_id': clientIdCtrl.text.trim(),
                                'client_secret': clientSecretCtrl.text.trim(),
                                'username': usernameCtrl.text.trim(),
                                'password': passwordCtrl.text.trim(),
                                'store_id': storeIdCtrl.text.trim(),
                                'is_sandbox': isSandbox,
                              });
                              if (!ctx.mounted) return;
                              if (res['success'] != true) {
                                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                  content: Text(
                                      'ত্রুটি: ${res['message'] ?? res.toString()}'),
                                  backgroundColor: Colors.red,
                                ));
                                return;
                              }

                              // Parse stores from response
                              final stores = (res['stores'] as List?)
                                      ?.map((s) =>
                                          Map<String, dynamic>.from(s as Map))
                                      .toList() ??
                                  [];

                              if (stores.isNotEmpty) {
                                setModal(() {
                                  storeList = stores;
                                  // Prefer store matching manually entered ID, else default
                                  final manualId = storeIdCtrl.text.trim();
                                  final matched = manualId.isNotEmpty
                                      ? stores.firstWhere(
                                          (s) =>
                                              s['store_id'].toString() ==
                                              manualId,
                                          orElse: () => <String, dynamic>{})
                                      : <String, dynamic>{};
                                  final defaultStore = matched.isNotEmpty
                                      ? matched
                                      : stores.firstWhere(
                                          (s) => s['is_default_store'] == true,
                                          orElse: () => stores.first);
                                  selectedStoreId =
                                      defaultStore['store_id'].toString();
                                  selectedStoreName =
                                      defaultStore['store_name']?.toString();
                                  storeIdCtrl.text = selectedStoreId!;
                                });
                                if (stores.length == 1) {
                                  // Auto-save single store
                                  final sid =
                                      stores.first['store_id'].toString();
                                  await _api.setPathaoStore(_token(), sid);
                                  if (!ctx.mounted) return;
                                  Navigator.pop(ctx);
                                  _load();
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Pathao সংযোগ সফল! স্টোর: ${stores.first['store_name']}'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'সংযোগ সফল! স্টোর নির্বাচন করে "স্টোর সেভ করুন" চাপুন।'),
                                      backgroundColor: Colors.blue,
                                    ),
                                  );
                                }
                              } else {
                                Navigator.pop(ctx);
                                _load();
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Pathao সংযোগ সফল!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } else {
                              final data = {
                                'courier_name': courierType,
                                'api_key': apiKeyCtrl.text.trim(),
                                'api_secret': secretCtrl.text.trim(),
                                'is_active': isActive,
                              };
                              await _api.saveCourierConfig(_token(), data,
                                  id: config?['id']);
                              if (ctx.mounted) Navigator.pop(ctx);
                              _load();
                            }
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
                      : Text(
                          courierType == 'pathao' && storeList.isNotEmpty
                              ? 'স্টোর সেভ করুন'
                              : (config == null ? 'যোগ করুন' : 'আপডেট করুন'),
                        ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> config) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('মুছে ফেলবেন?'),
        content: Text('${config['courier_type']} কনফিগ মুছে ফেলতে চান?'),
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
        await _api.deleteCourierConfig(_token(), config['id']);
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.courierConfigTitle),
        actions: [
          IconButton(
            icon: _checkingBalance
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh_rounded),
            tooltip: 'রিফ্রেশ',
            onPressed: _checkingBalance ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Balance Card ──
                if (_checkingBalance || _balanceMsg != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.account_balance_wallet_rounded,
                            color: Colors.green.shade700, size: 28),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Steadfast ব্যালেন্স',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                            if (_checkingBalance)
                              const SizedBox(
                                  width: 80,
                                  height: 20,
                                  child: LinearProgressIndicator())
                            else
                              Text(
                                _balanceMsg ?? '',
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.green.shade800),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                // ── Pathao Balance Card ──
                if (_pathaoConfigExists &&
                    (_checkingPathaoBalance || _pathaoBalanceMsg != null))
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.account_balance_wallet_rounded,
                            color: Colors.orange.shade700, size: 28),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Pathao ব্যালেন্স',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                            if (_checkingPathaoBalance)
                              const SizedBox(
                                  width: 80,
                                  height: 20,
                                  child: LinearProgressIndicator())
                            else
                              Text(
                                _pathaoBalanceMsg ?? '',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.orange.shade800),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _configs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.local_shipping_outlined,
                                  size: 64,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.3)),
                              const SizedBox(height: 12),
                              Text(l.noData),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _openForm,
                                child: const Text('যোগ করুন'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _configs.length,
                          itemBuilder: (ctx, i) {
                            final c = _configs[i] as Map<String, dynamic>;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: (c['is_active'] == true
                                          ? Colors.green
                                          : Colors.grey)
                                      .withValues(alpha: 0.13),
                                  child: Icon(
                                    Icons.local_shipping_rounded,
                                    color: c['is_active'] == true
                                        ? Colors.green
                                        : Colors.grey,
                                  ),
                                ),
                                title: Text(
                                  (c['courier_name'] ?? c['courier_type'] ?? '')
                                      .toString()
                                      .toUpperCase(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(
                                  c['is_active'] == true
                                      ? 'সক্রিয়'
                                      : 'নিষ্ক্রিয়',
                                  style: TextStyle(
                                    color: c['is_active'] == true
                                        ? Colors.green
                                        : Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 20),
                                      onPressed: () => _openForm(config: c),
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
                ), // Expanded
              ],
            ), // Column
      floatingActionButton: FloatingActionButton(
        onPressed: _openForm,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
