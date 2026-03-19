import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:f_khotiyan/l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/permission_helper.dart';
import 'dashboard_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _retypePasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureRetypePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _retypePasswordController.dispose();
    super.dispose();
  }

  /// Validate phone number (must be exactly 11 digits and start with 01)
  String? _validatePhoneNumber(String? value, AppLocalizations l10n) {
    if (value == null || value.isEmpty) {
      return l10n.phoneNumberRequired;
    }
    if (value.length != 11) {
      return l10n.phoneNumberInvalid;
    }
    if (!value.startsWith('01')) {
      return l10n.phoneNumberPattern;
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return l10n.phoneNumberInvalid;
    }
    return null;
  }

  /// Validate password
  String? _validatePassword(String? value, AppLocalizations l10n) {
    if (value == null || value.isEmpty) {
      return l10n.passwordRequired;
    }
    if (value.length < 8) {
      return l10n.passwordMinLength;
    }
    return null;
  }

  /// Handle registration
  Future<void> _handleRegistration() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    // Request storage/camera in background for later use (non-blocking)
    PermissionHelper.requestAllPermissions();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;

    final result = await authProvider.register(
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
      password2: _retypePasswordController.text,
      businessName: _businessNameController.text.trim().isEmpty
          ? null
          : _businessNameController.text.trim(),
      ownerName: _ownerNameController.text.trim().isEmpty
          ? null
          : _ownerNameController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.registrationSuccess),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
          (_) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.registrationFailed}: ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.registration),
        actions: [
          // Language toggle
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: () => localeProvider.toggleLocale(),
            tooltip: localeProvider.isBangla ? 'English' : 'বাংলা',
          ),
          // Theme toggle
          IconButton(
            icon: Icon(
              themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () => themeProvider.toggleTheme(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // App Logo or Title
                const Icon(Icons.business, size: 64, color: Colors.blue),
                const SizedBox(height: 16),
                Text(
                  l10n.appName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Business Name Field (Optional)
                TextFormField(
                  controller: _businessNameController,
                  decoration: InputDecoration(
                    labelText: l10n.businessName,
                    hintText: l10n.businessNameHint,
                    prefixIcon: const Icon(Icons.store),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),

                // Owner Name Field (Optional)
                TextFormField(
                  controller: _ownerNameController,
                  decoration: InputDecoration(
                    labelText: l10n.ownerName,
                    hintText: l10n.ownerNameHint,
                    prefixIcon: const Icon(Icons.person),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),

                // Address Field (Optional)
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: l10n.address,
                    hintText: l10n.addressHint,
                    prefixIcon: const Icon(Icons.location_on),
                  ),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),

                // Phone Number Field (Required, 11 digits)
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: l10n.phoneNumber,
                    hintText: l10n.phoneNumberHint,
                    prefixIcon: const Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  validator: (value) => _validatePhoneNumber(value, l10n),
                ),
                const SizedBox(height: 16),

                // Password Field (Required, min 8 characters)
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: l10n.password,
                    hintText: l10n.passwordHint,
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                  validator: (value) => _validatePassword(value, l10n),
                ),
                const SizedBox(height: 16),

                // Retype Password Field (Required, must match)
                TextFormField(
                  controller: _retypePasswordController,
                  decoration: InputDecoration(
                    labelText: l10n.retypePassword,
                    hintText: l10n.retypePasswordHint,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureRetypePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(
                          () =>
                              _obscureRetypePassword = !_obscureRetypePassword,
                        );
                      },
                    ),
                  ),
                  obscureText: _obscureRetypePassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.passwordRequired;
                    }
                    if (value != _passwordController.text) {
                      return l10n.passwordMismatch;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Register Button
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegistration,
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(l10n.register),
                  ),
                ),
                const SizedBox(height: 16),

                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(l10n.alreadyHaveAccount),
                    TextButton(
                      onPressed: () {
                        // Navigate to login
                        // Navigator.pushReplacementNamed(context, '/login');
                      },
                      child: Text(l10n.login),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
