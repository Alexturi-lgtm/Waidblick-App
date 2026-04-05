import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentService {
  // RevenueCat API Key — wird über App-Konfiguration gesetzt
  // Alex muss auf revenuecat.com Account erstellen + API Key holen
  static const String _revenueCatApiKey = String.fromEnvironment(
    'REVENUECAT_API_KEY',
    defaultValue: 'test_LDYuPtXOugEoyNkUsyFiwKHsIJK',
  );

  static const String _monthlyProductId = 'de.waidblick.premium.monthly';
  static const String _yearlyProductId = 'de.waidblick.premium.yearly';

  /// RevenueCat initialisieren (in main.dart aufrufen)
  static Future<void> initialize() async {
    await Purchases.setLogLevel(LogLevel.debug);

    final configuration = PurchasesConfiguration(_revenueCatApiKey);
    await Purchases.configure(configuration);

    // Supabase User-ID als RevenueCat App-User-ID setzen
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await Purchases.logIn(user.id);
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
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.active.containsKey('premium');
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
  static Future<PurchaseResult> purchaseMonthly() async {
    return await _purchasePackageById(_monthlyProductId);
  }

  /// Jährliches Abo kaufen
  static Future<PurchaseResult> purchaseYearly() async {
    return await _purchasePackageById(_yearlyProductId);
  }

  static Future<PurchaseResult> _purchasePackageById(String productId) async {
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null) {
        return PurchaseResult(success: false, error: 'Keine Produkte verfügbar');
      }

      final package = current.availablePackages.firstWhere(
        (p) => p.storeProduct.productIdentifier == productId,
        orElse: () => throw Exception('Produkt nicht gefunden: $productId'),
      );

      final customerInfo = await Purchases.purchasePackage(package);
      final isPremium = customerInfo.entitlements.active.containsKey('premium');
      return PurchaseResult(success: isPremium);
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        return PurchaseResult(success: false, cancelled: true);
      }
      return PurchaseResult(success: false, error: e.toString());
    } catch (e) {
      return PurchaseResult(success: false, error: e.toString());
    }
  }

  /// Käufe wiederherstellen
  static Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      return customerInfo.entitlements.active.containsKey('premium');
    } catch (e) {
      debugPrint('RevenueCat restore error: $e');
      return false;
    }
  }
}

class PurchaseResult {
  final bool success;
  final bool cancelled;
  final String? error;

  PurchaseResult({
    required this.success,
    this.cancelled = false,
    this.error,
  });
}
