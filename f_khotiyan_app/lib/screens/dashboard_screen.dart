import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../services/firebase_service.dart';
import 'login_screen.dart';
import 'orders_screen.dart';
import 'products_screen.dart';
import 'more_screen.dart';
import 'create_order_screen.dart';
import 'ai_order_screen.dart';
import 'customers_screen.dart';
import 'reports_screen.dart';
import 'subscription_screen.dart';
import '../widgets/native_ad_widget.dart';
import '../l10n/app_localizations.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _loadingDashboard = false;
  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? _profileData;
  String? _errorMsg;

  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Fetch initial data once UI is ready
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchData());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _fetchData();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _loadingDashboard = true;
      _errorMsg = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      // Use callWithAutoRefresh so token refresh is handled automatically
      final results = await Future.wait([
        authProvider.callWithAutoRefresh((t) => _api.getDashboardStats(t)),
        authProvider.callWithAutoRefresh((t) => _api.getProfile(t)),
      ]);

      if (!mounted) return;
      final dashData = results[0] as Map<String, dynamic>?;
      // Update premium status in AuthProvider from fresh stats
      final statsMap = dashData?['stats'] as Map<String, dynamic>? ?? {};
      authProvider.updatePremiumStatus(statsMap['is_premium'] == true);
      final freshProfile = (results[1] as Map<String, dynamic>?)?['user'];

      // Try to explicitly fetch wallet info and merge wallet_balance
      try {
        final walletInfo = await authProvider
            .callWithAutoRefresh((t) => _api.getWalletInfo(t));
        if (walletInfo['wallet_balance'] != null) {
          statsMap['wallet_balance'] = walletInfo['wallet_balance'];
          if (dashData != null) {
            dashData['stats'] = Map<String, dynamic>.from(statsMap);
          }
        }
      } catch (e) {
        // Log wallet fetch error but continue
        debugPrint('Wallet fetch failed: $e');
      }

      setState(() {
        _dashboardData = dashData;
        _profileData = freshProfile;
      });

      // Update provider cached user data and sync latest profile to Firebase
      if (freshProfile != null) {
        final profileMap = freshProfile as Map<String, dynamic>;
        await authProvider.setUserData(profileMap);
        FirebaseService.syncProfile(profileMap);
      }
    } catch (e) {
      debugPrint('Dashboard fetch failed: $e');
      _errorMsg = e.toString();
    } finally {
      if (mounted) setState(() => _loadingDashboard = false);
    }
  }

  Future<void> _logout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final l = AppLocalizations.of(context)!;

    final pages = [
      _HomeTab(
        profileData: _profileData,
        dashboardData: _dashboardData,
        loading: _loadingDashboard,
        error: _errorMsg,
        onRefresh: _fetchData,
        authProvider: authProvider,
      ),
      const OrdersScreen(),
      const ProductsScreen(),
      const MoreScreen(),
      _ProfileTab(
        profileData: _profileData,
        onLogout: _logout,
        authProvider: authProvider,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text([
          l.dashboardTitle,
          l.navOrders,
          l.navProducts,
          l.navMore,
          l.navProfile,
        ][_selectedIndex]),
        actions: [
          InkWell(
            onTap: () {
              localeProvider.toggleLocale();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(localeProvider.isBangla
                    ? 'Language: English'
                    : 'ভাষা: বাংলা'),
                duration: const Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ));
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.language, size: 20),
                  const SizedBox(width: 3),
                  Text(
                    localeProvider.isBangla ? 'EN' : 'বাংলা',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => themeProvider.toggleTheme(),
          ),
          if (_selectedIndex == 0)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _fetchData,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard_rounded),
            label: l.navDashboard,
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long_rounded),
            label: l.navOrders,
          ),
          NavigationDestination(
            icon: const Icon(Icons.inventory_2_outlined),
            selectedIcon: const Icon(Icons.inventory_2_rounded),
            label: l.navProducts,
          ),
          NavigationDestination(
            icon: const Icon(Icons.apps_rounded),
            selectedIcon: const Icon(Icons.apps_rounded),
            label: l.navMore,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: l.navProfile,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── HOME TAB ─────────────────────────────────────

class _HomeTab extends StatelessWidget {
  final Map<String, dynamic>? profileData;
  final Map<String, dynamic>? dashboardData;
  final bool loading;
  final String? error;
  final VoidCallback onRefresh;
  final AuthProvider authProvider;

  const _HomeTab({
    required this.profileData,
    required this.dashboardData,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.authProvider,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text(l.dataNotLoaded, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: Text(l.retryBtn),
            ),
          ],
        ),
      );
    }

    final businessName = profileData?['business_name'] ??
        authProvider.businessName ??
        l.businessName;
    final ownerName =
        profileData?['owner_name'] ?? authProvider.ownerName ?? '';
    final subscriptionType = profileData?['subscription_type'] ?? 'free';
    final stats = dashboardData?['stats'] as Map<String, dynamic>? ?? {};
    final todayOrders = stats['today_orders'] ?? 0;
    final todayRevenue = stats['today_revenue'] ?? 0;
    final monthRevenue = stats['month_revenue'] ?? 0;
    final pendingOrders = stats['pending_orders'] ?? 0;
    final lowStockCount = stats['low_stock_count'] ?? 0;
    final totalCustomers = stats['total_customers'] ?? 0;
    final recentOrders =
        (dashboardData?['recent_orders'] as List<dynamic>?) ?? [];

    // Order status breakdown for donut chart
    final orderStatusCounts = {
      'pending': (stats['pending_orders'] ?? 0) as int,
      'processing': (stats['processing_orders'] ?? 0) as int,
      'shipped': (stats['shipped_orders'] ?? 0) as int,
      'delivered': (stats['delivered_orders'] ?? 0) as int,
      'cancelled': (stats['cancelled_orders'] ?? 0) as int,
      'returned': (stats['returned_orders'] ?? 0) as int,
    };

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Greeting card
          _GreetingCard(
            businessName: businessName,
            ownerName: ownerName,
            subscriptionType: subscriptionType,
          ),
          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.receipt_long_rounded,
                  label: l.todayOrders,
                  value: '$todayOrders',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.currency_exchange_rounded,
                  label: l.todayRevenue,
                  value: '৳$todayRevenue',
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.calendar_month_rounded,
                  label: l.monthRevenue,
                  value: '৳$monthRevenue',
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.pending_actions_rounded,
                  label: l.pendingOrders,
                  value: '$pendingOrders',
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.people_rounded,
                  label: l.customersCount,
                  value: '$totalCustomers',
                  color: Colors.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.inventory_rounded,
                  label: l.lowStock,
                  value: '$lowStockCount${l.pieces}',
                  color: lowStockCount > 0 ? Colors.red : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Native ad (free users only)
          const NativeAdWidget(),

          // Wallet & subscription status
          _WalletStatusCard(stats: stats),
          const SizedBox(height: 20),

          // Order Status Donut Chart
          _OrderStatusDonut(statusCounts: orderStatusCounts),
          const SizedBox(height: 20),

          // Quick actions
          Text(l.quickActions,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.05,
            children: [
              _QuickAction(
                icon: Icons.add_box_rounded,
                label: l.newOrder,
                color: Colors.blue,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CreateOrderScreen())),
              ),
              _QuickAction(
                icon: Icons.camera_alt_rounded,
                label: l.aiOrder,
                color: Colors.teal,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AiOrderScreen())),
              ),
              _QuickAction(
                icon: Icons.person_add_rounded,
                label: l.customersTitle,
                color: Colors.orange,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CustomersScreen())),
              ),
              _QuickAction(
                icon: Icons.add_shopping_cart_rounded,
                label: l.navProducts,
                color: Colors.purple,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProductsScreen())),
              ),
              _QuickAction(
                icon: Icons.bar_chart_rounded,
                label: l.reportsTitle,
                color: Colors.indigo,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ReportsScreen())),
              ),
              _QuickAction(
                icon: Icons.apps_rounded,
                label: l.navMore,
                color: Colors.green,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MoreScreen())),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Recent orders section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l.recentOrders,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              TextButton(
                onPressed: () {},
                child: Text(l.seeAll),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (recentOrders.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.noOrdersYet,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...recentOrders.take(5).map((order) => _OrderTile(order: order)),
        ],
      ),
    );
  }
}

// ─────────────────────────── GREETING CARD ────────────────────────────────

class _GreetingCard extends StatelessWidget {
  final String businessName;
  final String ownerName;
  final String subscriptionType;

  const _GreetingCard({
    required this.businessName,
    required this.ownerName,
    required this.subscriptionType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final isPremium = subscriptionType != 'free';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPremium
              ? [Colors.amber[700]!, Colors.orange[800]!]
              : [theme.colorScheme.primary, theme.colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      businessName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isPremium) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          subscriptionType.toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                if (ownerName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${l.ownerLabel} $ownerName',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  isPremium ? l.premiumMember : l.freePlan,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.storefront_rounded, size: 48, color: Colors.white30),
        ],
      ),
    );
  }
}

// ─────────────────────────── WALLET STATUS CARD ───────────────────────────

class _WalletStatusCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _WalletStatusCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isPremium = stats['is_premium'] == true;
    final walletBalance = double.tryParse(stats['wallet_balance']?.toString() ?? '0') ?? 0.0;
    final aiRemaining = (stats['ai_free_uses_remaining'] ?? 0) as int;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isPremium
                  ? Colors.amber.withValues(alpha: 0.15)
                  : Colors.blue.withValues(alpha: 0.1),
              child: Icon(
                isPremium
                    ? Icons.workspace_premium_rounded
                    : Icons.account_balance_wallet_rounded,
                color: isPremium ? Colors.amber.shade700 : Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPremium ? l.premiumActive : l.freeAccount,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  Text(
                    '${l.walletBalance}: ৳${walletBalance.toStringAsFixed(2)} • ${l.aiFreeLabel}: $aiRemaining${l.pieces}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (!isPremium)
              TextButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SubscriptionScreen())),
                child: Text(l.upgradeBtn),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── STAT CARD ────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── QUICK ACTION ─────────────────────────────────

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── ORDER TILE ───────────────────────────────────

class _OrderTile extends StatelessWidget {
  final Map<String, dynamic> order;
  const _OrderTile({required this.order});

  Color _statusColor(String status) {
    switch (status) {
      case 'delivered':
        return Colors.green;
      case 'shipped':
        return Colors.blue;
      case 'processing':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = order['order_status'] ?? 'pending';
    final statusColor = _statusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.15),
          child: Icon(Icons.receipt_long_rounded, color: statusColor, size: 20),
        ),
        title: Text(
          order['customer_name'] ?? '—',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${order['order_number'] ?? ''} • ৳${order['grand_total'] ?? 0}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: statusColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// _OrdersTab and _ProductsTab replaced by OrdersScreen and ProductsScreen

// ─────────────────────────── PROFILE TAB ──────────────────────────────────

class _ProfileTab extends StatelessWidget {
  final Map<String, dynamic>? profileData;
  final VoidCallback onLogout;
  final AuthProvider authProvider;

  const _ProfileTab({
    required this.profileData,
    required this.onLogout,
    required this.authProvider,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final businessName =
        profileData?['business_name'] ?? authProvider.businessName ?? '—';
    final ownerName =
        profileData?['owner_name'] ?? authProvider.ownerName ?? '—';
    final phone =
        profileData?['phone_number'] ?? authProvider.phoneNumber ?? '—';
    final subscription = profileData?['subscription_type'] ?? 'free';
    final email = profileData?['email'] ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Avatar section
        Center(
          child: Column(
            children: [
              const SizedBox(height: 8),
              CircleAvatar(
                radius: 44,
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.15),
                child: Icon(
                  Icons.storefront_rounded,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                businessName,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (ownerName != '—')
                Text(
                  ownerName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: subscription == 'free'
                      ? Colors.grey.withValues(alpha: 0.15)
                      : Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  subscription == 'free' ? l.freePlanLabel : l.premiumLabel,
                  style: TextStyle(
                    color: subscription == 'free'
                        ? Colors.grey[600]
                        : Colors.amber[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Info cards
        Card(
          child: Column(
            children: [
              _ProfileTile(
                icon: Icons.phone_android_rounded,
                label: l.phoneNumber,
                value: phone,
              ),
              if (email.isNotEmpty) ...[
                const Divider(height: 1, indent: 56),
                _ProfileTile(
                  icon: Icons.email_rounded,
                  label: l.emailLabel,
                  value: email,
                ),
              ],
              const Divider(height: 1, indent: 56),
              _ProfileTile(
                icon: Icons.account_balance_wallet_rounded,
                label: l.walletBalanceLabel,
                value:
                    '৳${(double.tryParse(profileData?['wallet_balance']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}',
                valueColor: Colors.green.shade700,
              ),
              const Divider(height: 1, indent: 56),
              _ProfileTile(
                icon: subscription == 'free'
                    ? Icons.person_outline_rounded
                    : Icons.workspace_premium_rounded,
                label: l.subscriptionLabel,
                value: subscription == 'free' ? l.freePlanLabel : l.premiumLabel,
                valueColor:
                    subscription == 'free' ? null : Colors.amber.shade700,
              ),
              if (subscription != 'free' &&
                  profileData?['subscription_end_date'] != null) ...[
                const Divider(height: 1, indent: 56),
                _ProfileTile(
                  icon: Icons.calendar_today_rounded,
                  label: l.expiryLabel,
                  value: _formatSubDate(
                      profileData!['subscription_end_date'].toString()),
                  valueColor: Colors.teal,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Settings section
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: Text(l.notifications),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.lock_outline_rounded),
                title: Text(l.changePasswordLabel),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.help_outline_rounded),
                title: Text(l.helpSupport),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Premium banner (only for free users)
        if (subscription == 'free')
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber[700]!, Colors.orange[800]!],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, color: Colors.white, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.upgradeToPremium,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l.unlimitedBenefits,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),

        // Logout button
        OutlinedButton.icon(
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) {
              final lCtx = AppLocalizations.of(ctx)!;
              return AlertDialog(
                title: Text(lCtx.logoutTitle),
                content: Text(lCtx.logoutConfirmMsg),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(lCtx.cancel),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onLogout();
                    },
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: Text(lCtx.logoutBtn,
                        style: const TextStyle(color: Colors.white)),
                  ),
                ],
              );
            },
            );
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.logout_rounded),
          label: Text(l.logoutBtn,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

String _formatSubDate(String iso) {
  try {
    final d = DateTime.parse(iso).toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  } catch (_) {
    return iso;
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(label,
          style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55))),
      subtitle: Text(value,
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600, color: valueColor)),
    );
  }
}

// ─────────────────────────── ORDER STATUS DONUT ────────────────────────────

class _OrderStatusDonut extends StatelessWidget {
  final Map<String, int> statusCounts;

  const _OrderStatusDonut({required this.statusCounts});

  static const _colors = {
    'pending': Color(0xFFFF9800),
    'processing': Color(0xFF2196F3),
    'shipped': Color(0xFF3F51B5),
    'delivered': Color(0xFF4CAF50),
    'cancelled': Color(0xFFF44336),
    'returned': Color(0xFF9C27B0),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final labels = {
      'pending': l.statusPending,
      'processing': l.statusProcessing,
      'shipped': l.statusShipped,
      'delivered': l.statusDelivered,
      'cancelled': l.statusCancelled,
      'returned': l.statusReturned,
    };
    final total = statusCounts.values.fold(0, (a, b) => a + b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.orderStats,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Donut ring
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CustomPaint(
                    painter: _DonutPainter(
                      statusCounts: statusCounts,
                      colors: _colors,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$total',
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            l.totalLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Legend
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: labels.entries.map((entry) {
                      final count = statusCounts[entry.key] ?? 0;
                      final color = _colors[entry.key] ?? Colors.grey;
                      final pct = total > 0 ? (count * 100 / total).round() : 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: count > 0
                                    ? color
                                    : color.withValues(alpha: 0.25),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: count > 0
                                      ? null
                                      : theme.colorScheme.onSurface
                                          .withValues(alpha: 0.4),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '$count${total > 0 ? ' ($pct%)' : ''}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: count > 0 ? color : null,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final Map<String, int> statusCounts;
  final Map<String, Color> colors;

  const _DonutPainter({required this.statusCounts, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final total = statusCounts.values.fold(0, (a, b) => a + b);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 12;
    const strokeWidth = 22.0;
    const gap = 0.04; // radian gap between segments

    if (total == 0) {
      final paint = Paint()
        ..color = Colors.grey.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius, paint);
      return;
    }

    double startAngle = -math.pi / 2;
    for (final entry in statusCounts.entries) {
      if (entry.value == 0) continue;
      final sweep = (entry.value / total) * 2 * math.pi;
      final paint = Paint()
        ..color = colors[entry.key] ?? Colors.grey
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + gap / 2,
        sweep - gap,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.statusCounts != statusCounts;
}
