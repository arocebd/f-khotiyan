import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:f_khotiyan/l10n/app_localizations.dart';

import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import 'registration_screen.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value, AppLocalizations l10n) {
    if (value == null || value.isEmpty) return l10n.phoneNumberRequired;
    if (value.length != 11) return l10n.phoneNumberInvalid;
    if (!value.startsWith('01')) return l10n.phoneNumberPattern;
    return null;
  }

  String? _validatePassword(String? value, AppLocalizations l10n) {
    if (value == null || value.isEmpty) return l10n.passwordRequired;
    if (value.length < 8) return l10n.passwordMinLength;
    return null;
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final result = await authProvider.login(
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else {
      final errorMsg = _parseError(result['error']?.toString() ?? '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _parseError(String raw) {
    if (raw.contains('Invalid credentials')) {
      return 'ফোন নম্বর বা পাসওয়ার্ড ভুল।';
    }
    if (raw.contains('Connection refused')) {
      return 'সার্ভারে সংযোগ করা যাচ্ছে না। পরে চেষ্টা করুন।';
    }
    return raw.replaceAll('Exception: Login failed:', '').trim();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('F-Khotiyan'),
        actions: [
          // Language toggle
          IconButton(
            icon: const Icon(Icons.language),
            tooltip: 'Toggle Language',
            onPressed: () => localeProvider.toggleLocale(),
          ),
          // Theme toggle
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Toggle Theme',
            onPressed: () => themeProvider.toggleTheme(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),

                // Logo / Icon
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.storefront_rounded,
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  l10n.login,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  l10n.loginSubtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 40),

                // Phone
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: l10n.phoneNumber,
                    hintText: '01XXXXXXXXX',
                    counterText: '',
                    prefixIcon: const Icon(Icons.phone_android_rounded),
                  ),
                  validator: (v) => _validatePhone(v, l10n),
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: l10n.password,
                    hintText: l10n.passwordHint,
                    prefixIcon: const Icon(Icons.lock_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) => _validatePassword(v, l10n),
                  onFieldSubmitted: (_) => _handleLogin(),
                ),
                const SizedBox(height: 32),

                // Login button
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            l10n.login,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Divider
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        l10n.orText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),

                // Register link
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                          builder: (_) => const RegistrationScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    l10n.noAccountRegister,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
