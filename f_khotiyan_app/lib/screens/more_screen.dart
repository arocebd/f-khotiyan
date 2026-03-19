import 'package:flutter/material.dart';
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
    final features = [
      const _Feature(
        icon: Icons.people_rounded,
        label: 'গ্রাহক',
        color: Colors.blue,
        screen: CustomersScreen(),
      ),
      const _Feature(
        icon: Icons.payments_rounded,
        label: 'খরচ',
        color: Colors.orange,
        screen: ExpenseScreen(),
      ),
      const _Feature(
        icon: Icons.account_balance_wallet_rounded,
        label: 'মূলধন',
        color: Colors.green,
        screen: CapitalScreen(),
      ),
      const _Feature(
        icon: Icons.bar_chart_rounded,
        label: 'রিপোর্ট',
        color: Colors.teal,
        screen: ReportsScreen(),
      ),
      const _Feature(
        icon: Icons.local_shipping_rounded,
        label: 'কুরিয়ার সেটিং',
        color: Colors.indigo,
        screen: CourierConfigScreen(),
      ),
      const _Feature(
        icon: Icons.account_balance_wallet_rounded,
        label: 'ওয়ালেট',
        color: Colors.green,
        screen: WalletScreen(),
      ),
      const _Feature(
        icon: Icons.workspace_premium_rounded,
        label: 'প্রিমিয়াম',
        color: Colors.amber,
        screen: SubscriptionScreen(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('আরো')),
      body: Padding(
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
