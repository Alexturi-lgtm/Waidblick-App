import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentService {
  // RevenueCat API Key — wird über App-Konfiguration gesetzt
  // Alex muss auf revenuecat.com Account erstellen + API Key holen
  static const String _revenueCatApiKey = String.fromEnvironment(
    'REVENUECAT_API_KEY',
    defaultValue: 'appl_xAlJiDlFeBlKCpXtJmYTBqlbKuN',
  );

  static const String _monthlyProductId = 'monthly';
  static const String _yearlyProductId = 'yearly';

  /// RevenueCat initialisieren (in main.dart aufrufen)
  static Future<void> initialize() async {
    try {
      await Purchases.setLogLevel(LogLevel.debug);
      final configuration = PurchasesConfiguration(_revenueCatApiKey);
      await Purchases.configure(configuration);
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Purchases.logIn(user.id);
      }
    } catch (e) {
      // RevenueCat nicht verfügbar — App läuft trotzdem
      debugPrint('RevenueCat init failed: $e');
    }
  }

  /// User in RevenueCat einloggen (nach Supabase-Login aufrufen)
  static Future<void> loginUser(String userId) async {
    try {
      await Purchases.logIn(userId);
    } catch (e) {
      debugPrint('RevenueCat login error: $e');
    }
  }

  /// User ausloggen
  static Future<void> logoutUser() async {
    try {
      await Purchases.logOut();
    } catch (e) {
      debugPrint('RevenueCat logout error: $e');
    }
  }

  /// Aktuellen Subscription-Status holen
  static Future<bool> isPremium() async {
    // 🧪 TESTFLIGHT-MODUS: Paywall deaktiviert für Beta-Test
    // TODO: Vor App Store Launch entfernen!
    return true;

    // ignore: dead_code
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.active.containsKey('Waidblick Premium');
    } catch (e) {
      debugPrint('RevenueCat isPremium error: $e');
      return false;
    }
  }

  /// Verfügbare Produkte laden
  static Future<List<StoreProduct>> getProducts() async {
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null) return [];
      return current.availablePackages
          .map((p) => p.storeProduct)
          .toList();
    } catch (e) {
      debugPrint('RevenueCat getProducts error: $e');
      return [];
    }
  }

  /// Monatliches Abo kaufen
  static Future<PaymentResult> purchaseMonthly() async {
    return await _purchasePackageById(_monthlyProductId);
  }

  /// Jährliches Abo kaufen
  static Future<PaymentResult> purchaseYearly() async {
    return await _purchasePackageById(_yearlyProductId);
  }

  static Future<PaymentResult> _purchasePackageById(String productId) async {
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null) {
        return PaymentResult(success: false, error: 'Keine Produkte verfügbar');
      }

      final package = current.availablePackages.firstWhere(
        (p) => p.storeProduct.identifier == productId,
        orElse: () => throw Exception('Produkt nicht gefunden: $productId'),
      );

      final result = await Purchases.purchase(PurchaseParams.package(package));
      final isPremium = result.customerInfo.entitlements.active.containsKey('Waidblick Premium');
      return PaymentResult(success: isPremium);
    } on PurchasesError catch (e) {
      if (e.code == PurchasesErrorCode.purchaseCancelledError) {
        return PaymentResult(success: false, cancelled: true);
      }
      return PaymentResult(success: false, error: e.toString());
    } catch (e) {
      return PaymentResult(success: false, error: e.toString());
    }
  }

  /// Käufe wiederherstellen
  static Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      return customerInfo.entitlements.active.containsKey('Waidblick Premium');
    } catch (e) {
      debugPrint('RevenueCat restore error: $e');
      return false;
    }
  }
}

class PaymentResult {
  final bool success;
  final bool cancelled;
  final String? error;

  PaymentResult({
    required this.success,
    this.cancelled = false,
    this.error,
  });
}
