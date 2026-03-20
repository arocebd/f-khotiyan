import 'package:flutter/material.dart';
import 'package:f_khotiyan/l10n/app_localizations.dart';
import 'customers_screen.dart';
import 'expense_screen.dart';
import 'capital_screen.dart';
import 'reports_screen.dart';
import 'courier_config_screen.dart';
import 'wallet_screen.dart';
import 'subscription_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final features = [
      _Feature(icon: Icons.people_rounded,          label: l.customersTitle,    color: Colors.blue,   screen: const CustomersScreen()),
      _Feature(icon: Icons.payments_rounded,         label: l.expenseLabel,      color: Colors.orange, screen: const ExpenseScreen()),
      _Feature(icon: Icons.account_balance_wallet_rounded, label: l.capitalLabel, color: Colors.green,  screen: const CapitalScreen()),
      _Feature(icon: Icons.bar_chart_rounded,        label: l.reportsTitle,      color: Colors.teal,   screen: const ReportsScreen()),
      _Feature(icon: Icons.local_shipping_rounded,   label: l.courierSettings,   color: Colors.indigo, screen: const CourierConfigScreen()),
      _Feature(icon: Icons.account_balance_wallet_rounded, label: l.walletTitle,  color: Colors.green,  screen: const WalletScreen()),
      _Feature(icon: Icons.workspace_premium_rounded, label: l.premiumLabel,     color: Colors.amber,  screen: const SubscriptionScreen()),
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.2,
        ),
        itemCount: features.length,
        itemBuilder: (ctx, i) {
          final f = features[i];
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => f.screen),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: f.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: f.color.withValues(alpha: 0.3)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(f.icon, size: 40, color: f.color),
                  const SizedBox(height: 10),
                  Text(
                    f.label,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: f.color),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Feature {
  final IconData icon;
  final String label;
  final Color color;
  final Widget screen;
  const _Feature(
      {required this.icon,
      required this.label,
      required this.color,
      required this.screen});
}
