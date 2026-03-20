// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override String get appName => 'এফ-খতিয়ান';
  @override String get registration => 'নিবন্ধন';
  @override String get businessName => 'ব্যবসার নাম';
  @override String get businessNameHint => 'আপনার ব্যবসার নাম লিখুন';
  @override String get businessNameRequired => 'ব্যবসার নাম প্রয়োজন';
  @override String get ownerName => 'মালিকের নাম';
  @override String get ownerNameHint => 'মালিকের সম্পূর্ণ নাম লিখুন';
  @override String get ownerNameRequired => 'মালিকের নাম প্রয়োজন';
  @override String get address => 'ঠিকানা';
  @override String get addressHint => 'সম্পূর্ণ ব্যবসার ঠিকানা লিখুন';
  @override String get addressRequired => 'ঠিকানা প্রয়োজন';
  @override String get phoneNumber => 'ফোন নম্বর';
  @override String get phoneNumberHint => '০১XXXXXXXXX';
  @override String get phoneNumberRequired => 'ফোন নম্বর প্রয়োজন';
  @override String get phoneNumberInvalid => 'ফোন নম্বর ঠিক ১১ সংখ্যার হতে হবে';
  @override String get phoneNumberPattern => 'ফোন নম্বর অবশ্যই ০১ দিয়ে শুরু হতে হবে';
  @override String get password => 'পাসওয়ার্ড';
  @override String get passwordHint => 'পাসওয়ার্ড লিখুন';
  @override String get passwordRequired => 'পাসওয়ার্ড প্রয়োজন';
  @override String get passwordMinLength => 'পাসওয়ার্ড কমপক্ষে ৮ অক্ষরের হতে হবে';
  @override String get retypePassword => 'পাসওয়ার্ড পুনরায় লিখুন';
  @override String get retypePasswordHint => 'আপনার পাসওয়ার্ড পুনরায় লিখুন';
  @override String get passwordMismatch => 'পাসওয়ার্ড মিলছে না';
  @override String get register => 'নিবন্ধন করুন';
  @override String get alreadyHaveAccount => 'ইতিমধ্যে একাউন্ট আছে?';
  @override String get login => 'লগইন';
  @override String get registering => 'নিবন্ধন হচ্ছে...';
  @override String get registrationSuccess => 'নিবন্ধন সফল হয়েছে!';
  @override String get registrationFailed => 'নিবন্ধন ব্যর্থ হয়েছে';
  @override String get permissionsRequired => 'অনুমতি প্রয়োজন';
  @override String get storagePermission => 'ডেটা সংরক্ষণের জন্য স্টোরেজ অনুমতি প্রয়োজন';
  @override String get cameraPermission => 'ছবি তোলার জন্য কেমেরা অনুমতি প্রয়োজন';
  @override String get locationPermission => 'অবস্থান অনুমতি প্রয়োজন';
  @override String get contactPermission => 'যোগাযোগ অনুমতি প্রয়োজন';
  @override String get grantPermission => 'অনুমতি দিন';
  @override String get cancel => 'বাতিল';
  @override String get settings => 'সেটিংস';
  @override String get loginSubtitle => 'এফ-খতিয়ানে আবার স্বাগতম';
  @override String get noAccountRegister => 'অ্যাকাউন্ট নেই? নিবন্ধন করুন';
  @override String get orText => 'অথবা';

  @override String get navDashboard => 'হোম';
  @override String get navOrders => 'অর্ডার';
  @override String get navProducts => 'পণ্য';
  @override String get navMore => 'আরো';
  @override String get navProfile => 'প্রোফাইল';
  @override String get dashboardTitle => 'ড্যাশবোর্ড';

  @override String get todayOrders => 'আজকের অর্ডার';
  @override String get todayRevenue => 'আজকের আয়';
  @override String get monthRevenue => 'মাসের আয়';
  @override String get pendingOrders => 'অপেক্ষারত অর্ডার';
  @override String get customersCount => 'গ্রাহক';
  @override String get lowStock => 'কম স্টক';
  @override String get quickActions => 'দ্রুত কাজ';
  @override String get newOrder => 'নতুন অর্ডার';
  @override String get aiOrder => 'AI অর্ডার';
  @override String get recentOrders => 'সাম্প্রতিক অর্ডার';
  @override String get seeAll => 'সব দেখুন';
  @override String get noOrdersYet => 'এখনো কোনো অর্ডার নেই';
  @override String get dataNotLoaded => 'ডেটা লোড হয়নি';
  @override String get retryBtn => 'পুনরায় চেষ্টা';
  @override String get ownerLabel => 'মালিকঃ';
  @override String get freePlan => 'ফ্রি প্ল্যান';
  @override String get premiumMember => 'প্রিমিয়াম সদস্য';
  @override String get premiumActive => 'প্রিমিয়াম সক্রিয়';
  @override String get freeAccount => 'ফ্রি অ্যাকাউন্ট';
  @override String get upgradeBtn => 'আপগ্রেড';
  @override String get orderStats => 'অর্ডার পরিসংখ্যান';
  @override String get totalLabel => 'মোট';
  @override String get statusPending => 'অপেক্ষারত';
  @override String get statusProcessing => 'প্রক্রিয়াকরণ';
  @override String get statusShipped => 'পাঠানো হয়েছে';
  @override String get statusDelivered => 'ডেলিভারি হয়েছে';
  @override String get statusCancelled => 'বাতিল';
  @override String get statusReturned => 'ফেরত';

  @override String get profileTitle => 'প্রোফাইল';
  @override String get emailLabel => 'ইমেইল';
  @override String get walletBalanceLabel => 'ওয়ালেট ব্যালেন্স';
  @override String get subscriptionLabel => 'সাবস্ক্রিপশন';
  @override String get expiryLabel => 'মেয়াদ শেষ';
  @override String get notifications => 'নোটিফিকেশন';
  @override String get changePasswordLabel => 'পাসওয়ার্ড পরিবর্তন';
  @override String get helpSupport => 'সাহায্য ও সহায়তা';
  @override String get logoutTitle => 'লগআউট';
  @override String get logoutConfirmMsg => 'আপনি কি নিশ্চিতভাবে লগআউট করতে চান?';
  @override String get logoutBtn => 'লগআউট';
  @override String get upgradeToPremium => 'প্রিমিয়ামে আপগ্রেড করুন';
  @override String get unlimitedBenefits => 'সীমাহীন অর্ডার + SMS সুবিধা পান';
  @override String get premiumLabel => 'প্রিমিয়াম';
  @override String get freePlanLabel => 'ফ্রি প্ল্যান';

  @override String get expenseLabel => 'খরচ';
  @override String get capitalLabel => 'মূলধন';
  @override String get courierSettings => 'কুরিয়ার সেটিং';

  @override String get walletTitle => 'ওয়ালেট';
  @override String get walletBalance => 'ওয়ালেট ব্যালেন্স';
  @override String get smsPer => 'SMS প্রতি';
  @override String get aiPer => 'AI প্রতি';
  @override String get aiFreeLabel => 'AI ফ্রি';
  @override String get rechargeWallet => 'ওয়ালেট রিচার্জ করুন';
  @override String get transactionHistory => 'লেনদেনের ইতিহাস';
  @override String get noTransactions => 'কোনো লেনদেন নেই';
  @override String get walletRechargeTitle => 'ওয়ালেট রিচার্জ';
  @override String get paymentMethod => 'পেমেন্ট পদ্ধতি';
  @override String get amountLabel => 'পরিমাণ (৳)';
  @override String get senderNumberLabel => 'প্রেরকের নম্বর';
  @override String get transactionIdLabel => 'ট্রানজেকশন আইডি';
  @override String get sendRequest => 'অনুরোধ পাঠান';
  @override String get minRecharge10 => 'সর্বনিম্ন রিচার্জ ৳10';
  @override String get enterTxnId => 'ট্রানজেকশন আইডি দিন';
  @override String get rechargeSubmitted => 'রিচার্জ অনুরোধ জমা হয়েছে। অ্যাডমিন যাচাইয়ের পর ব্যালেন্স যোগ হবে।';
  @override String get sendTo => 'পাঠান';
  @override String get errorPrefix => 'ত্রুটি';

  @override String get ordersTitle => 'অর্ডার';
  @override String get noOrdersFound => 'কোনো অর্ডার পাওয়া যায়নি';

  @override String get productsTitle => 'স্টক ম্যানেজমেন্ট';
  @override String get noProductsFound => 'কোনো পণ্য পাওয়া যায়নি';
  @override String get newProductBtn => 'নতুন পণ্য';
  @override String get marginLabel => 'মার্জিন';
  @override String get deleteProductTitle => 'পণ্য মুছবেন?';
  @override String get deleteBtn => 'মুছুন';
  @override String get addImageOptional => 'ছবি যোগ (ঐচ্ছিক)';

  @override String get subscriptionTitle => 'প্রিমিয়াম সাবস্ক্রিপশন';
  @override String get choosePlan => 'প্ল্যান বেছে নিন';
  @override String get monthlyPlan => 'মাসিক প্ল্যান';
  @override String get yearlyPlan => 'বার্ষিক প্ল্যান';
  @override String get purchaseHistory => 'ক্রয়ের ইতিহাস';
  @override String get noPurchaseHistory => 'কোনো ক্রয়ের ইতিহাস নেই';
  @override String get subscriptionPurchaseTitle => 'সাবস্ক্রিপশন ক্রয়';
  @override String get submitRequest => 'অনুরোধ জমা দিন';
  @override String get validityLabel => 'মেয়াদ';

  @override String get reportsTitle => 'রিপোর্ট';
  @override String get customersTitle => 'গ্রাহক';
  @override String get expenseTitle => 'খরচ';
  @override String get capitalTitle => 'মূলধন';
  @override String get courierConfigTitle => 'কুরিয়ার সেটিং';
  @override String get aiOrderTitle => 'AI অর্ডার';
  @override String get createOrderTitle => 'অর্ডার তৈরি';
  @override String get orderDetailTitle => 'অর্ডার বিবরণ';
  @override String get orderTrackingTitle => 'অর্ডার ট্র্যাকিং';

  @override String get submitting => 'জমা হচ্ছে...';
  @override String get confirm => 'নিশ্চিত করুন';
  @override String get save => 'সংরক্ষণ করুন';
  @override String get close => 'বন্ধ করুন';
  @override String get loading => 'লোড হচ্ছে...';
  @override String get noData => 'কোনো ডেটা নেই';
  @override String get search => 'খুঁজুন';
  @override String get filter => 'ফিল্টার';
  @override String get all => 'সব';
  @override String get active => 'সক্রিয়';
  @override String get inactive => 'নিষ্ক্রিয়';
  @override String get items => 'টি';
  @override String get pieces => ' টি';
  @override String get taka => '৳';
}
