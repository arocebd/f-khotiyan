import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
  ];

  // ── Registration / Auth ─────────────────────────────────
  String get appName;
  String get registration;
  String get businessName;
  String get businessNameHint;
  String get businessNameRequired;
  String get ownerName;
  String get ownerNameHint;
  String get ownerNameRequired;
  String get address;
  String get addressHint;
  String get addressRequired;
  String get phoneNumber;
  String get phoneNumberHint;
  String get phoneNumberRequired;
  String get phoneNumberInvalid;
  String get phoneNumberPattern;
  String get password;
  String get passwordHint;
  String get passwordRequired;
  String get passwordMinLength;
  String get retypePassword;
  String get retypePasswordHint;
  String get passwordMismatch;
  String get register;
  String get alreadyHaveAccount;
  String get login;
  String get registering;
  String get registrationSuccess;
  String get registrationFailed;
  String get permissionsRequired;
  String get storagePermission;
  String get cameraPermission;
  String get locationPermission;
  String get contactPermission;
  String get grantPermission;
  String get cancel;
  String get settings;
  String get loginSubtitle;
  String get noAccountRegister;
  String get orText;

  // ── Navigation ───────────────────────────────────────────
  String get navDashboard;
  String get navOrders;
  String get navProducts;
  String get navMore;
  String get navProfile;
  String get dashboardTitle;

  // ── Dashboard / Home ─────────────────────────────────────
  String get todayOrders;
  String get todayRevenue;
  String get monthRevenue;
  String get pendingOrders;
  String get customersCount;
  String get lowStock;
  String get quickActions;
  String get newOrder;
  String get aiOrder;
  String get recentOrders;
  String get seeAll;
  String get noOrdersYet;
  String get dataNotLoaded;
  String get retryBtn;
  String get ownerLabel;
  String get freePlan;
  String get premiumMember;
  String get premiumActive;
  String get freeAccount;
  String get upgradeBtn;
  String get orderStats;
  String get totalLabel;
  String get statusPending;
  String get statusProcessing;
  String get statusShipped;
  String get statusDelivered;
  String get statusCancelled;
  String get statusReturned;

  // ── Profile ──────────────────────────────────────────────
  String get profileTitle;
  String get emailLabel;
  String get walletBalanceLabel;
  String get subscriptionLabel;
  String get expiryLabel;
  String get notifications;
  String get changePasswordLabel;
  String get helpSupport;
  String get logoutTitle;
  String get logoutConfirmMsg;
  String get logoutBtn;
  String get upgradeToPremium;
  String get unlimitedBenefits;
  String get premiumLabel;
  String get freePlanLabel;

  // ── More Screen ──────────────────────────────────────────
  String get expenseLabel;
  String get capitalLabel;
  String get courierSettings;

  // ── Wallet ───────────────────────────────────────────────
  String get walletTitle;
  String get walletBalance;
  String get smsPer;
  String get aiPer;
  String get aiFreeLabel;
  String get rechargeWallet;
  String get transactionHistory;
  String get noTransactions;
  String get walletRechargeTitle;
  String get paymentMethod;
  String get amountLabel;
  String get senderNumberLabel;
  String get transactionIdLabel;
  String get sendRequest;
  String get minRecharge10;
  String get enterTxnId;
  String get rechargeSubmitted;
  String get sendTo;
  String get errorPrefix;

  // ── Orders ───────────────────────────────────────────────
  String get ordersTitle;
  String get noOrdersFound;

  // ── Products ─────────────────────────────────────────────
  String get productsTitle;
  String get noProductsFound;
  String get newProductBtn;
  String get marginLabel;
  String get deleteProductTitle;
  String get deleteBtn;
  String get addImageOptional;

  // ── Subscription ─────────────────────────────────────────
  String get subscriptionTitle;
  String get choosePlan;
  String get monthlyPlan;
  String get yearlyPlan;
  String get purchaseHistory;
  String get noPurchaseHistory;
  String get subscriptionPurchaseTitle;
  String get submitRequest;
  String get validityLabel;

  // ── Misc Screens ─────────────────────────────────────────
  String get reportsTitle;
  String get customersTitle;
  String get expenseTitle;
  String get capitalTitle;
  String get courierConfigTitle;
  String get aiOrderTitle;
  String get createOrderTitle;
  String get orderDetailTitle;
  String get orderTrackingTitle;

  // ── Common ───────────────────────────────────────────────
  String get submitting;
  String get confirm;
  String get save;
  String get close;
  String get loading;
  String get noData;
  String get search;
  String get filter;
  String get all;
  String get active;
  String get inactive;
  String get items;
  String get pieces;
  String get taka;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
  }
  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale".');
}
