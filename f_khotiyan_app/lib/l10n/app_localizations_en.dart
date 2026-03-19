// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'F-Khotiyan';

  @override
  String get registration => 'Registration';

  @override
  String get businessName => 'Business Name';

  @override
  String get businessNameHint => 'Enter your business name';

  @override
  String get businessNameRequired => 'Business name is required';

  @override
  String get ownerName => 'Owner Name';

  @override
  String get ownerNameHint => 'Enter owner\'s full name';

  @override
  String get ownerNameRequired => 'Owner name is required';

  @override
  String get address => 'Address';

  @override
  String get addressHint => 'Enter full business address';

  @override
  String get addressRequired => 'Address is required';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get phoneNumberHint => '01XXXXXXXXX';

  @override
  String get phoneNumberRequired => 'Phone number is required';

  @override
  String get phoneNumberInvalid => 'Phone number must be exactly 11 digits';

  @override
  String get phoneNumberPattern => 'Phone number must start with 01';

  @override
  String get password => 'Password';

  @override
  String get passwordHint => 'Enter password';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get passwordMinLength => 'Password must be at least 8 characters';

  @override
  String get retypePassword => 'Retype Password';

  @override
  String get retypePasswordHint => 'Re-enter your password';

  @override
  String get passwordMismatch => 'Passwords do not match';

  @override
  String get register => 'Register';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get login => 'Login';

  @override
  String get registering => 'Registering...';

  @override
  String get registrationSuccess => 'Registration successful!';

  @override
  String get registrationFailed => 'Registration failed';

  @override
  String get permissionsRequired => 'Permissions Required';

  @override
  String get storagePermission => 'Storage permission is needed to save data';

  @override
  String get cameraPermission =>
      'Camera permission is needed to capture images';

  @override
  String get locationPermission => 'Location permission is needed';

  @override
  String get contactPermission => 'Contact permission is needed';

  @override
  String get grantPermission => 'Grant Permission';

  @override
  String get cancel => 'Cancel';

  @override
  String get settings => 'Settings';

  @override
  String get loginSubtitle => 'Welcome back to F-Khotiyan';

  @override
  String get noAccountRegister => 'Don\'t have an account? Register';

  @override
  String get orText => 'OR';
}
