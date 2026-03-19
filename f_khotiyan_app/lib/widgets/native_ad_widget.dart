import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/ad_service.dart';

/// Displays a native advanced ad card. Only shown for non-premium users.
/// Loads and disposes its own ad automatically.
class NativeAdWidget extends StatefulWidget {
  const NativeAdWidget({super.key});

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    AdService.createNativeAd(
      onLoaded: (ad) {
        if (mounted) {
          setState(() {
            _ad = ad;
            _loaded = true;
          });
        }
      },
      onFailed: () {
        if (mounted) {
          setState(() {
            _loaded = false;
            _ad = null;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Never show ads to premium users
    final isPremium =
        Provider.of<AuthProvider>(context, listen: false).isPremium;
    if (isPremium || !_loaded || _ad == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: 80,
            maxHeight: 320,
          ),
          child: AdWidget(ad: _ad!),
        ),
      ),
    );
  }
}
