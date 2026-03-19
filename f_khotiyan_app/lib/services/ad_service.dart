import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Handles loading and showing interstitial + native advanced ads.
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // ── Ad Unit IDs ───────────────────────────────────────────
  static const String _interstitialAdUnitId =
      'ca-app-pub-1388226619737490/4781345197';
  static const String _nativeAdUnitId =
      'ca-app-pub-1388226619737490/2466173040';

  // ── Interstitial ──────────────────────────────────────────
  InterstitialAd? _interstitialAd;
  bool _isLoading = false;

  /// Call once at app startup.
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  /// Load an interstitial ad into memory so it's ready to show.
  void loadInterstitialAd() {
    if (_isLoading || _interstitialAd != null) return;
    _isLoading = true;

    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isLoading = false;
          _interstitialAd!.setImmersiveMode(true);
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          _interstitialAd = null;
        },
      ),
    );
  }

  /// Show the loaded interstitial ad.
  /// [onAdClosed] is called regardless of whether an ad was shown.
  Future<void> showInterstitialAd({void Function()? onAdClosed}) async {
    if (_interstitialAd == null) {
      onAdClosed?.call();
      loadInterstitialAd();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd();
        onAdClosed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd();
        onAdClosed?.call();
      },
    );

    await _interstitialAd!.show();
  }

  // ── Native Advanced ───────────────────────────────────────

  /// Creates and loads a NativeAd. The caller is responsible for disposing it.
  /// [onLoaded] is called with the loaded ad; [onFailed] if it fails.
  static NativeAd createNativeAd({
    required void Function(NativeAd) onLoaded,
    void Function()? onFailed,
  }) {
    late final NativeAd ad;
    ad = NativeAd(
      adUnitId: _nativeAdUnitId,
      factoryId: 'listTile',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (_) => onLoaded(ad),
        onAdFailedToLoad: (_, __) => onFailed?.call(),
      ),
    );
    ad.load();
    return ad;
  }

  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}
