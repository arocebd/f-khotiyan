import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

/// Provider for managing authentication state
class AuthProvider with ChangeNotifier {
  static const String _tokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';
  static const String _phoneKey = 'user_phone';
  static const String _businessNameKey = 'business_name';
  static const String _ownerNameKey = 'owner_name';

  String? _accessToken;
  String? _refreshToken;
  int? _userId;
  String? _phoneNumber;
  String? _businessName;
  String? _ownerName;
  bool _isLoading = false;
  bool _isPremium = false;
  Map<String, dynamic>? _userData;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  int? get userId => _userId;
  String? get phoneNumber => _phoneNumber;
  String? get businessName => _businessName;
  String? get ownerName => _ownerName;
  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;
  bool get isPremium => _isPremium;
  bool get isAuthenticated => _accessToken != null;

  final ApiService _apiService = ApiService();

  /// Initialize authentication from saved data
  Future<void> loadAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_tokenKey);
    _refreshToken = prefs.getString(_refreshTokenKey);
    _userId = prefs.getInt(_userIdKey);
    _phoneNumber = prefs.getString(_phoneKey);
    _businessName = prefs.getString(_businessNameKey);
    _ownerName = prefs.getString(_ownerNameKey);
    notifyListeners();
  }

  /// Register new user
  Future<Map<String, dynamic>> register({
    required String phone,
    required String password,
    required String password2,
    String? businessName,
    String? ownerName,
    String? address,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.register(
        phone: phone,
        password: password,
        password2: password2,
        businessName: businessName,
        ownerName: ownerName,
        address: address,
      );

      final tokens = response['tokens'] as Map<String, dynamic>?;
      if (tokens != null) {
        _userData = response['user'] as Map<String, dynamic>?;
        await _saveAuthData(
          accessToken: tokens['access'],
          refreshToken: tokens['refresh'],
          userId: response['user']['id'],
          phone: response['user']['phone_number'] ?? '',
          businessName: response['user']['business_name'] ?? '',
          ownerName: response['user']['owner_name'] ?? '',
        );
      }

      _isLoading = false;
      notifyListeners();

      return {'success': true, 'data': response};
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Login user
  Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.login(
        phone: phone,
        password: password,
      );

      final tokens = response['tokens'] as Map<String, dynamic>?;
      if (tokens != null) {
        _userData = response['user'] as Map<String, dynamic>?;
        await _saveAuthData(
          accessToken: tokens['access'],
          refreshToken: tokens['refresh'],
          userId: response['user']['id'],
          phone: response['user']['phone_number'] ?? '',
          businessName: response['user']['business_name'] ?? '',
          ownerName: response['user']['owner_name'] ?? '',
        );
      }

      _isLoading = false;
      notifyListeners();

      return {'success': true, 'data': response};
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Refresh the access token using the stored refresh token
  Future<bool> tryRefreshToken() async {
    if (_refreshToken == null) return false;
    try {
      final response = await _apiService.refreshAccessToken(_refreshToken!);
      final newAccess = response['access'] as String?;
      if (newAccess == null) return false;
      _accessToken = newAccess;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, newAccess);
      // SimpleJWT token rotation — save new refresh token if returned
      final newRefresh = response['refresh'] as String?;
      if (newRefresh != null) {
        _refreshToken = newRefresh;
        await prefs.setString(_refreshTokenKey, newRefresh);
      }
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Execute an API call, auto-refreshing token on 401. Forces logout if
  /// refresh also fails.
  Future<T> callWithAutoRefresh<T>(
    Future<T> Function(String token) call,
  ) async {
    if (_accessToken == null) throw Exception('Not authenticated');
    try {
      return await call(_accessToken!);
    } catch (e) {
      if (e.toString().contains('401')) {
        final refreshed = await tryRefreshToken();
        if (refreshed && _accessToken != null) {
          return await call(_accessToken!);
        } else {
          await logout();
          throw Exception('Session expired. Please login again.');
        }
      }
      rethrow;
    }
  }

  /// Update premium status from dashboard stats
  void updatePremiumStatus(bool isPremium) {
    if (_isPremium != isPremium) {
      _isPremium = isPremium;
      notifyListeners();
    }
  }

  /// Logout user
  Future<void> logout() async {
    await _clearAuthData();
    notifyListeners();
  }

  /// Save authentication data
  Future<void> _saveAuthData({
    required String accessToken,
    required String refreshToken,
    required int userId,
    required String phone,
    String? businessName,
    String? ownerName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
    await prefs.setInt(_userIdKey, userId);
    await prefs.setString(_phoneKey, phone);
    if (businessName != null) {
      await prefs.setString(_businessNameKey, businessName);
    }
    if (ownerName != null) await prefs.setString(_ownerNameKey, ownerName);

    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _userId = userId;
    _phoneNumber = phone;
    _businessName = businessName;
    _ownerName = ownerName;
  }

  /// Clear authentication data
  Future<void> _clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_phoneKey);
    await prefs.remove(_businessNameKey);
    await prefs.remove(_ownerNameKey);

    _accessToken = null;
    _refreshToken = null;
    _userId = null;
    _phoneNumber = null;
    _businessName = null;
    _ownerName = null;
    _userData = null;
  }
}
