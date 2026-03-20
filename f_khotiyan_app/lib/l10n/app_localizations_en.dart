// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override String get appName => 'F-Khotiyan';
  @override String get registration => 'Registration';
  @override String get businessName => 'Business Name';
  @override String get businessNameHint => 'Enter your business name';
  @override String get businessNameRequired => 'Business name is required';
  @override String get ownerName => 'Owner Name';
  @override String get ownerNameHint => 'Enter owner\'s full name';
  @override String get ownerNameRequired => 'Owner name is required';
  @override String get address => 'Address';
  @override String get addressHint => 'Enter full business address';
  @override String get addressRequired => 'Address is required';
  @override String get phoneNumber => 'Phone Number';
  @override String get phoneNumberHint => '01XXXXXXXXX';
  @override String get phoneNumberRequired => 'Phone number is required';
  @override String get phoneNumberInvalid => 'Phone number must be exactly 11 digits';
  @override String get phoneNumberPattern => 'Phone number must start with 01';
  @override String get password => 'Password';
  @override String get passwordHint => 'Enter password';
  @override String get passwordRequired => 'Password is required';
  @override String get passwordMinLength => 'Password must be at least 8 characters';
  @override String get retypePassword => 'Retype Password';
  @override String get retypePasswordHint => 'Re-enter your password';
  @override String get passwordMismatch => 'Passwords do not match';
  @override String get register => 'Register';
  @override String get alreadyHaveAccount => 'Already have an account?';
  @override String get login => 'Login';
  @override String get registering => 'Registering...';
  @override String get registrationSuccess => 'Registration successful!';
  @override String get registrationFailed => 'Registration failed';
  @override String get permissionsRequired => 'Permissions Required';
  @override String get storagePermission => 'Storage permission is needed to save data';
  @override String get cameraPermission => 'Camera permission is needed to capture images';
  @override String get locationPermission => 'Location permission is needed';
  @override String get contactPermission => 'Contact permission is needed';
  @override String get grantPermission => 'Grant Permission';
  @override String get cancel => 'Cancel';
  @override String get settings => 'Settings';
  @override String get loginSubtitle => 'Welcome back to F-Khotiyan';
  @override String get noAccountRegister => 'Don\'t have an account? Register';
  @override String get orText => 'OR';

  @override String get navDashboard => 'Home';
  @override String get navOrders => 'Orders';
  @override String get navProducts => 'Products';
  @override String get navMore => 'More';
  @override String get navProfile => 'Profile';
  @override String get dashboardTitle => 'Dashboard';

  @override String get todayOrders => 'Today\'s Orders';
  @override String get todayRevenue => 'Today\'s Revenue';
  @override String get monthRevenue => 'Monthly Revenue';
  @override String get pendingOrders => 'Pending Orders';
  @override String get customersCount => 'Customers';
  @override String get lowStock => 'Low Stock';
  @override String get quickActions => 'Quick Actions';
  @override String get newOrder => 'New Order';
  @override String get aiOrder => 'AI Order';
  @override String get recentOrders => 'Recent Orders';
  @override String get seeAll => 'See All';
  @override String get noOrdersYet => 'No orders yet';
  @override String get dataNotLoaded => 'Data not loaded';
  @override String get retryBtn => 'Retry';
  @override String get ownerLabel => 'Owner';
  @override String get freePlan => 'Free Plan';
  @override String get premiumMember => 'Premium Member';
  @override String get premiumActive => 'Premium Active';
  @override String get freeAccount => 'Free Account';
  @override String get upgradeBtn => 'Upgrade';
  @override String get orderStats => 'Order Statistics';
  @override String get totalLabel => 'Total';
  @override String get statusPending => 'Pending';
  @override String get statusProcessing => 'Processing';
  @override String get statusShipped => 'Shipped';
  @override String get statusDelivered => 'Delivered';
  @override String get statusCancelled => 'Cancelled';
  @override String get statusReturned => 'Returned';

  @override String get profileTitle => 'Profile';
  @override String get emailLabel => 'Email';
  @override String get walletBalanceLabel => 'Wallet Balance';
  @override String get subscriptionLabel => 'Subscription';
  @override String get expiryLabel => 'Expiry';
  @override String get notifications => 'Notifications';
  @override String get changePasswordLabel => 'Change Password';
  @override String get helpSupport => 'Help & Support';
  @override String get logoutTitle => 'Logout';
  @override String get logoutConfirmMsg => 'Are you sure you want to logout?';
  @override String get logoutBtn => 'Logout';
  @override String get upgradeToPremium => 'Upgrade to Premium';
  @override String get unlimitedBenefits => 'Unlimited orders + SMS benefits';
  @override String get premiumLabel => 'Premium';
  @override String get freePlanLabel => 'Free Plan';

  @override String get expenseLabel => 'Expense';
  @override String get capitalLabel => 'Capital';
  @override String get courierSettings => 'Courier Settings';

  @override String get walletTitle => 'Wallet';
  @override String get walletBalance => 'Wallet Balance';
  @override String get smsPer => 'Per SMS';
  @override String get aiPer => 'Per AI';
  @override String get aiFreeLabel => 'AI Free';
  @override String get rechargeWallet => 'Recharge Wallet';
  @override String get transactionHistory => 'Transaction History';
  @override String get noTransactions => 'No transactions';
  @override String get walletRechargeTitle => 'Wallet Recharge';
  @override String get paymentMethod => 'Payment Method';
  @override String get amountLabel => 'Amount (৳)';
  @override String get senderNumberLabel => 'Sender Number';
  @override String get transactionIdLabel => 'Transaction ID';
  @override String get sendRequest => 'Send Request';
  @override String get minRecharge10 => 'Minimum recharge ৳10';
  @override String get enterTxnId => 'Enter Transaction ID';
  @override String get rechargeSubmitted => 'Recharge request submitted. Balance will be credited after admin verification.';
  @override String get sendTo => 'Send to';
  @override String get errorPrefix => 'Error';

  @override String get ordersTitle => 'Orders';
  @override String get noOrdersFound => 'No orders found';

  @override String get productsTitle => 'Stock Management';
  @override String get noProductsFound => 'No products found';
  @override String get newProductBtn => 'New Product';
  @override String get marginLabel => 'Margin';
  @override String get deleteProductTitle => 'Delete Product?';
  @override String get deleteBtn => 'Delete';
  @override String get addImageOptional => 'Add Image (Optional)';

  @override String get subscriptionTitle => 'Premium Subscription';
  @override String get choosePlan => 'Choose Plan';
  @override String get monthlyPlan => 'Monthly Plan';
  @override String get yearlyPlan => 'Yearly Plan';
  @override String get purchaseHistory => 'Purchase History';
  @override String get noPurchaseHistory => 'No purchase history';
  @override String get subscriptionPurchaseTitle => 'Subscription Purchase';
  @override String get submitRequest => 'Submit Request';
  @override String get validityLabel => 'Validity';

  @override String get reportsTitle => 'Reports';
  @override String get customersTitle => 'Customers';
  @override String get expenseTitle => 'Expense';
  @override String get capitalTitle => 'Capital';
  @override String get courierConfigTitle => 'Courier Settings';
  @override String get aiOrderTitle => 'AI Order';
  @override String get createOrderTitle => 'Create Order';
  @override String get orderDetailTitle => 'Order Detail';
  @override String get orderTrackingTitle => 'Order Tracking';

  @override String get submitting => 'Submitting...';
  @override String get confirm => 'Confirm';
  @override String get save => 'Save';
  @override String get close => 'Close';
  @override String get loading => 'Loading...';
  @override String get noData => 'No data available';
  @override String get search => 'Search';
  @override String get filter => 'Filter';
  @override String get all => 'All';
  @override String get active => 'Active';
  @override String get inactive => 'Inactive';
  @override String get items => ' items';
  @override String get pieces => ' pcs';
  @override String get taka => '৳';
}
