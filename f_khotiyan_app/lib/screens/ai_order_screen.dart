import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class AiOrderScreen extends StatefulWidget {
  const AiOrderScreen({super.key});
  @override
  State<AiOrderScreen> createState() => _AiOrderScreenState();
}

class _AiOrderScreenState extends State<AiOrderScreen> {
  final _api = ApiService();
  bool _extracting = false;
  bool _confirming = false;
  Map<String, dynamic>? _extracted;
  File? _image;
  final _textCtrl = TextEditingController();
  bool _useText = false;

  // Controllers for editing extracted data
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _deliveryCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  List<Map<String, dynamic>> _editableProducts = [];

  String _token() =>
      Provider.of<AuthProvider>(context, listen: false).accessToken ?? '';

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;
    setState(() => _image = File(picked.path));
    await _extract();
  }

  Future<void> _extract() async {
    setState(() {
      _extracting = true;
      _extracted = null;
    });
    try {
      Map<String, dynamic> result;
      if (_useText && _textCtrl.text.trim().isNotEmpty) {
        result =
            await _api.extractOrderFromText(_token(), _textCtrl.text.trim());
      } else if (_image != null) {
        result = await _api.uploadOrderImage(_token(), _image!.path);
      } else {
        return;
      }
      // Server wraps the extracted fields under 'extracted_data'
      final extracted = result['extracted_data'] as Map<String, dynamic>?;
      final data = extracted ?? result;
      setState(() {
        _extracted = data;
        _nameCtrl.text = (data['customer_name'] ?? '').toString();
        _phoneCtrl.text = (data['customer_phone'] ?? '').toString();
        _addressCtrl.text = (data['customer_address'] ?? '').toString();
        _deliveryCtrl.text = (data['delivery_charge'] ?? '').toString();
        _notesCtrl.text = (data['notes'] ?? '').toString();
        _editableProducts = ((data['products'] as List?) ?? [])
            .map<Map<String, dynamic>>((p) => {
                  'product_name': (p['product_name'] ?? '').toString(),
                  'quantity': (p['quantity'] ?? 1).toString(),
                  'price': (p['price'] ?? 0).toString(),
                })
            .toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ত্রুটি: $e')));
      }
    } finally {
      setState(() => _extracting = false);
    }
  }

  Future<void> _confirm() async {
    if (_extracted == null) return;
    setState(() => _confirming = true);
    try {
      final payload = <String, dynamic>{
        'customer_name': _nameCtrl.text.trim(),
        'customer_phone': _phoneCtrl.text.trim(),
        'customer_address': _addressCtrl.text.trim(),
        'delivery_charge': double.tryParse(_deliveryCtrl.text.trim()) ?? 0,
        'notes': _notesCtrl.text.trim(),
        'products': _editableProducts
            .map((p) => {
                  'product_name': p['product_name'],
                  'quantity': int.tryParse(p['quantity'].toString()) ?? 1,
                  'price': double.tryParse(p['price'].toString()) ?? 0,
                })
            .toList(),
        if (_extracted!['district'] != null)
          'district': _extracted!['district'],
        if (_extracted!['courier_preference'] != null)
          'courier_preference': _extracted!['courier_preference'],
        if (_extracted!['discount'] != null)
          'discount': _extracted!['discount'],
      };
      await _api.confirmAiOrder(_token(), payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('অর্ডার সফলভাবে তৈরি হয়েছে')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ত্রুটি: $e')));
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _deliveryCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI অর্ডার')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Toggle input type
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: false,
                    label: Text('ছবি'),
                    icon: Icon(Icons.camera_alt_outlined)),
                ButtonSegment(
                    value: true,
                    label: Text('টেক্সট'),
                    icon: Icon(Icons.text_fields_rounded)),
              ],
              selected: {_useText},
              onSelectionChanged: (v) => setState(() {
                _useText = v.first;
                _extracted = null;
              }),
            ),
            const SizedBox(height: 16),

            if (!_useText) ...[
              // Image input
              GestureDetector(
                onTap: () => _showImagePicker(),
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: _image == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                size: 48,
                                color: Theme.of(context).colorScheme.primary),
                            const SizedBox(height: 8),
                            const Text('ছবি বা স্ক্রিনশট আপলোড করুন'),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_image!, fit: BoxFit.cover),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text('ক্যামেরা'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('গ্যালারি'),
                  ),
                ],
              ),
            ] else ...[
              // Text input
              TextField(
                controller: _textCtrl,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'ফেসবুক মেসেজ বা অর্ডার টেক্সট পেস্ট করুন...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _extracting ? null : _extract,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(_extracting
                    ? 'বিশ্লেষণ হচ্ছে...'
                    : 'AI দিয়ে বিশ্লেষণ করুন'),
              ),
            ],

            if (_extracting) ...[
              const SizedBox(height: 24),
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text('AI বিশ্লেষণ করছে...'),
                  ],
                ),
              ),
            ],

            if (_extracted != null) ...[
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.edit_note_rounded,
                              color: Colors.green[600]),
                          const SizedBox(width: 8),
                          const Text('তথ্য সম্পাদনা করুন',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const Divider(),
                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                            labelText: 'গ্রাহকের নাম',
                            border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                            labelText: 'ফোন নম্বর',
                            border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _addressCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                            labelText: 'ঠিকানা', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _deliveryCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'ডেলিভারি চার্জ',
                            border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _notesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                            labelText: 'নোট', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('পণ্য সমূহ',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            tooltip: 'পণ্য যোগ করুন',
                            onPressed: () =>
                                setState(() => _editableProducts.add({
                                      'product_name': '',
                                      'quantity': '1',
                                      'price': '0',
                                    })),
                          ),
                        ],
                      ),
                      ..._editableProducts.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final p = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 4,
                                child: TextFormField(
                                  initialValue: p['product_name'],
                                  decoration: const InputDecoration(
                                      labelText: 'পণ্যের নাম',
                                      border: OutlineInputBorder(),
                                      isDense: true),
                                  onChanged: (v) => _editableProducts[idx]
                                      ['product_name'] = v,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue: p['quantity'],
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: 'পরিমাণ',
                                      border: OutlineInputBorder(),
                                      isDense: true),
                                  onChanged: (v) =>
                                      _editableProducts[idx]['quantity'] = v,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue: p['price'],
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: 'মূল্য',
                                      border: OutlineInputBorder(),
                                      isDense: true),
                                  onChanged: (v) =>
                                      _editableProducts[idx]['price'] = v,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red),
                                onPressed: () => setState(
                                    () => _editableProducts.removeAt(idx)),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _confirming ? null : _confirm,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green),
                        icon: _confirming
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_rounded),
                        label: Text(_confirming
                            ? 'অর্ডার তৈরি হচ্ছে...'
                            : 'অর্ডার নিশ্চিত করুন'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('ক্যামেরা'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('গ্যালারি'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}
