import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for handling API requests
class ApiService {
  // Change this to your actual API URL
  // For real phone: Use your PC's local IP (make sure phone and PC are on same Wi-Fi)
  // For emulator/BlueStacks: Use 10.0.2.2
  static const String baseUrl = 'https://app.khotiyan.com/api';

  final http.Client _client = http.Client();

  /// Register new user
  Future<Map<String, dynamic>> register({
    required String phone,
    required String password,
    required String password2,
    String? businessName,
    String? ownerName,
    String? address,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone_number': phone,
        'password': password,
        'password_confirm': password2,
        if (businessName != null) 'business_name': businessName,
        if (ownerName != null) 'owner_name': ownerName,
        if (address != null) 'address': address,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Registration failed: ${response.body}');
    }
  }

  /// Login user
  Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone_number': phone, 'password': password}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Login failed: ${response.body}');
    }
  }

  /// Refresh JWT access token
  Future<Map<String, dynamic>> refreshAccessToken(String refreshToken) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/token/refresh/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh': refreshToken}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Token refresh failed: ${response.statusCode}');
  }

  /// Get user profile
  Future<Map<String, dynamic>> getProfile(String token) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/auth/profile/'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to get profile: ${response.body}');
  }

  // ── helpers ──────────────────────────────────────────────
  Map<String, String> _authHeaders(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> _get(String path, String token,
      {Map<String, String>? query}) async {
    var uri = Uri.parse('$baseUrl$path');
    if (query != null) uri = uri.replace(queryParameters: query);
    final r = await _client.get(uri, headers: _authHeaders(token));
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('HTTP ${r.statusCode}: ${r.body}');
    }
    return jsonDecode(r.body);
  }

  Future<Map<String, dynamic>> _post(
      String path, String token, Map<String, dynamic> body) async {
    final r = await _client.post(
      Uri.parse('$baseUrl$path'),
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('HTTP ${r.statusCode}: ${r.body}');
    }
    return jsonDecode(r.body);
  }

  Future<Map<String, dynamic>> _patch(
      String path, String token, Map<String, dynamic> body) async {
    final r = await _client.patch(
      Uri.parse('$baseUrl$path'),
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('HTTP ${r.statusCode}: ${r.body}');
    }
    return jsonDecode(r.body);
  }

  Future<Map<String, dynamic>> _delete(String path, String token) async {
    final r = await _client.delete(Uri.parse('$baseUrl$path'),
        headers: _authHeaders(token));
    if (r.statusCode == 204) return {'success': true};
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('HTTP ${r.statusCode}: ${r.body}');
    }
    return jsonDecode(r.body);
  }

  // ── Dashboard ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getDashboardStats(String token) =>
      _get('/dashboard-stats/', token);

  // ── Products ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getProducts(String token,
      {String? search, String? category, bool? lowStock}) {
    final q = <String, String>{};
    if (search != null) q['search'] = search;
    if (category != null) q['category'] = category;
    if (lowStock == true) q['low_stock'] = 'true';
    return _get('/products/', token, query: q);
  }

  Future<Map<String, dynamic>> createProduct(
          String token, Map<String, dynamic> data) =>
      _post('/products/', token, data);

  /// Create product with optional image file path (multipart)
  Future<Map<String, dynamic>> createProductWithImage(
      String token, Map<String, dynamic> data, String? imagePath) async {
    if (imagePath == null) return createProduct(token, data);
    final request =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/products/'));
    request.headers['Authorization'] = 'Bearer $token';
    data.forEach((k, v) {
      if (v != null) request.fields[k] = v.toString();
    });
    request.files.add(await http.MultipartFile.fromPath('image', imagePath));
    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    return jsonDecode(resp.body);
  }

  Future<Map<String, dynamic>> updateProduct(
          String token, int id, Map<String, dynamic> data) =>
      _patch('/products/$id/', token, data);

  /// Update product with optional image file path (multipart)
  Future<Map<String, dynamic>> updateProductWithImage(String token, int id,
      Map<String, dynamic> data, String? imagePath) async {
    if (imagePath == null) return updateProduct(token, id, data);
    final request =
        http.MultipartRequest('PATCH', Uri.parse('$baseUrl/products/$id/'));
    request.headers['Authorization'] = 'Bearer $token';
    data.forEach((k, v) {
      if (v != null) request.fields[k] = v.toString();
    });
    request.files.add(await http.MultipartFile.fromPath('image', imagePath));
    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    return jsonDecode(resp.body);
  }

  Future<Map<String, dynamic>> deleteProduct(String token, int id) =>
      _delete('/products/$id/', token);

  // ── Customers ────────────────────────────────────────────
  Future<Map<String, dynamic>> getCustomers(String token, {String? search}) {
    final q = search != null ? {'search': search} : <String, String>{};
    return _get('/customers/', token, query: q);
  }

  Future<Map<String, dynamic>> createCustomer(
          String token, Map<String, dynamic> data) =>
      _post('/customers/', token, data);

  Future<Map<String, dynamic>> updateCustomer(
          String token, int id, Map<String, dynamic> data) =>
      _patch('/customers/$id/', token, data);

  Future<Map<String, dynamic>> deleteCustomer(String token, int id) =>
      _delete('/customers/$id/', token);

  // ── Orders ───────────────────────────────────────────────
  Future<Map<String, dynamic>> getOrders(String token,
      {String? status,
      String? paymentStatus,
      String? startDate,
      String? endDate,
      String? search,
      int page = 1}) {
    final q = <String, String>{'page': '$page'};
    if (status != null) q['status'] = status;
    if (paymentStatus != null) q['payment_status'] = paymentStatus;
    if (startDate != null) q['start_date'] = startDate;
    if (endDate != null) q['end_date'] = endDate;
    if (search != null && search.isNotEmpty) q['search'] = search;
    return _get('/orders/', token, query: q);
  }

  Future<Map<String, dynamic>> getOrderDetail(String token, int id) =>
      _get('/orders/$id/', token);

  Future<Map<String, dynamic>> createOrder(
          String token, Map<String, dynamic> data) =>
      _post('/orders/', token, data);

  Future<Map<String, dynamic>> updateOrder(
          String token, int id, Map<String, dynamic> data) =>
      _patch('/orders/$id/', token, data);

  Future<Map<String, dynamic>> updateOrderItems(
          String token, int id, List<Map<String, dynamic>> items) =>
      _post('/orders/$id/update-items/', token, {'items': items});

  Future<Map<String, dynamic>> getOrderStats(String token) =>
      _get('/orders/statistics/', token);

  Future<Map<String, dynamic>> extractOrderFromText(
          String token, String text) =>
      _post('/orders/extract/', token, {'message_text': text});

  Future<Map<String, dynamic>> confirmAiOrder(
          String token, Map<String, dynamic> data) =>
      _post('/orders/confirm-ai-order/', token, data);

  Future<Map<String, dynamic>> sendOrderSms(String token, int orderId,
      {String? message}) {
    final body = message != null ? {'message': message} : <String, dynamic>{};
    return _post('/orders/$orderId/send-sms/', token, body);
  }

  Future<Map<String, dynamic>> getSmsPreview(String token, String message) =>
      _get('/sms/preview/?message=${Uri.encodeQueryComponent(message)}', token);

  Future<Map<String, dynamic>> getSmsLogs(String token) =>
      _get('/sms/logs/', token);

  Future<Map<String, dynamic>> sendBulkSms(String token,
          List<Map<String, dynamic>> recipients, String message) =>
      _post(
          '/sms/bulk/', token, {'recipients': recipients, 'message': message});

  Future<Map<String, dynamic>> trackCourier(String token, int orderId) =>
      _get('/orders/$orderId/track-courier/', token);

  Future<Map<String, dynamic>> uploadOrderImage(
      String token, String imagePath) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/orders/extract/'));
    request.headers['Authorization'] = 'Bearer $token';
    request.files
        .add(await http.MultipartFile.fromPath('screenshot', imagePath));
    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    return jsonDecode(resp.body);
  }

  // ── Expenses ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getExpenses(String token,
      {String? category, String? startDate, String? endDate}) {
    final q = <String, String>{};
    if (category != null) q['category'] = category;
    if (startDate != null) q['start_date'] = startDate;
    if (endDate != null) q['end_date'] = endDate;
    return _get('/expenses/', token, query: q);
  }

  Future<Map<String, dynamic>> createExpense(
          String token, Map<String, dynamic> data) =>
      _post('/expenses/', token, data);

  Future<Map<String, dynamic>> updateExpense(
          String token, int id, Map<String, dynamic> data) =>
      _patch('/expenses/$id/', token, data);

  Future<Map<String, dynamic>> deleteExpense(String token, int id) =>
      _delete('/expenses/$id/', token);

  // ── Returns ──────────────────────────────────────────────
  Future<Map<String, dynamic>> getReturns(String token, {String? status}) {
    final q = status != null ? {'status': status} : <String, String>{};
    return _get('/returns/', token, query: q);
  }

  Future<Map<String, dynamic>> createReturn(
          String token, Map<String, dynamic> data) =>
      _post('/returns/', token, data);

  Future<Map<String, dynamic>> updateReturn(
          String token, int id, Map<String, dynamic> data) =>
      _patch('/returns/$id/', token, data);

  // ── Capital Investment ───────────────────────────────────
  Future<Map<String, dynamic>> getCapital(String token) =>
      _get('/capital/', token);

  Future<Map<String, dynamic>> createCapital(
          String token, Map<String, dynamic> data) =>
      _post('/capital/', token, data);

  Future<Map<String, dynamic>> deleteCapital(String token, int id) =>
      _delete('/capital/$id/', token);

  // ── Courier Config ───────────────────────────────────────
  Future<Map<String, dynamic>> getCourierConfigs(String token) =>
      _get('/courier-configs/', token);

  Future<Map<String, dynamic>> saveCourierConfig(
          String token, Map<String, dynamic> data, {int? id}) =>
      id != null
          ? _patch('/courier-configs/$id/', token, data)
          : _post('/courier-configs/', token, data);

  Future<Map<String, dynamic>> deleteCourierConfig(String token, int id) =>
      _delete('/courier-configs/$id/', token);

  // ── Steadfast Courier ─────────────────────────────────────
  Future<Map<String, dynamic>> sendToSteadfast(String token, int orderId) =>
      _post('/orders/$orderId/send-to-steadfast/', token, {});

  Future<Map<String, dynamic>> getSteadfastStatus(String token, int orderId) =>
      _get('/orders/$orderId/steadfast-status/', token);

  Future<Map<String, dynamic>> getSteadfastBalance(String token) =>
      _get('/steadfast/balance/', token);

  // ── Pathao Courier ────────────────────────────────────────
  Future<Map<String, dynamic>> connectPathao(
          String token, Map<String, dynamic> data) =>
      _post('/pathao/connect/', token, data);

  Future<Map<String, dynamic>> sendToPathao(String token, int orderId) =>
      _post('/orders/$orderId/send-to-pathao/', token, {});

  Future<Map<String, dynamic>> getPathaoStatus(String token, int orderId) =>
      _get('/orders/$orderId/pathao-status/', token);

  Future<Map<String, dynamic>> getPathaoBalance(String token) =>
      _get('/pathao/balance/', token);

  Future<Map<String, dynamic>> getPathaoStores(String token) =>
      _get('/pathao/stores/', token);

  Future<Map<String, dynamic>> setPathaoStore(String token, String storeId) =>
      _post('/pathao/set-store/', token, {'store_id': storeId});

  // ── SMS Purchase ─────────────────────────────────────────
  Future<Map<String, dynamic>> getSmsPurchases(String token) =>
      _get('/sms-purchases/', token);

  Future<Map<String, dynamic>> requestSmsPurchase(
          String token, Map<String, dynamic> data) =>
      _post('/sms-purchases/', token, data);

  // ── Reports ──────────────────────────────────────────────
  Future<Map<String, dynamic>> getReports(String token,
      {String? startDate, String? endDate}) {
    final q = <String, String>{};
    if (startDate != null) q['start_date'] = startDate;
    if (endDate != null) q['end_date'] = endDate;
    return _get('/reports/', token, query: q);
  }

  // ── Wallet ────────────────────────────────────────────────
  Future<Map<String, dynamic>> getWalletInfo(String token) =>
      _get('/wallet/', token);

  Future<Map<String, dynamic>> requestTopup(String token,
          {required double amount,
          required String paymentMethod,
          required String transactionId,
          required String senderNumber}) =>
      _post('/wallet/topup/', token, {
        'amount': amount,
        'payment_method': paymentMethod,
        'transaction_id': transactionId,
        'sender_number': senderNumber,
      });

  // ── Subscription ──────────────────────────────────────────
  Future<Map<String, dynamic>> purchaseSubscription(String token,
          {required String plan,
          required String paymentMethod,
          required String transactionId,
          required String senderNumber}) =>
      _post('/subscription/purchase/', token, {
        'plan': plan,
        'payment_method': paymentMethod,
        'transaction_id': transactionId,
        'sender_number': senderNumber,
      });

  Future<List> getPurchaseHistory(String token) async {
    final res = await _get('/subscription/history/', token);
    return res['purchases'] as List? ?? [];
  }

  /// Dispose client
  void dispose() {
    _client.close();
  }
}
