import 'package:cloud_functions/cloud_functions.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../config/app_flags.dart';

/// Thin wrapper around `in_app_purchase` (Google Play Billing) plus the
/// server-side verification call — the paywall UI drives this, but never
/// grants premium itself; only `verifySubscriptionPurchase` (Cloud
/// Function) may do that. See docs/BILLING_SETUP.md for the Play Console
/// side this depends on.
class SubscriptionService {
  SubscriptionService({InAppPurchase? inAppPurchase})
      : _iap = inAppPurchase ?? InAppPurchase.instance;

  final InAppPurchase _iap;

  Stream<List<PurchaseDetails>> get purchaseUpdates => _iap.purchaseStream;

  Future<bool> isAvailable() => _iap.isAvailable();

  /// Looks up the monthly premium product from Play Console. Returns null
  /// if billing isn't available or the product id isn't found there yet
  /// (e.g. Play Console setup from docs/BILLING_SETUP.md isn't done).
  Future<ProductDetails?> queryPremiumProduct() async {
    if (!await isAvailable()) return null;
    final response = await _iap.queryProductDetails({AppFlags.premiumMonthlyProductId});
    if (response.error != null || response.productDetails.isEmpty) return null;
    return response.productDetails.first;
  }

  Future<void> buyPremium(ProductDetails product) {
    final param = PurchaseParam(productDetails: product);
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restorePurchases() => _iap.restorePurchases();

  /// Sends the purchase token to `verifySubscriptionPurchase` — the only
  /// thing that actually unlocks premium (writes `families/{fid}` via the
  /// admin SDK once Google Play confirms the purchase is real and active).
  Future<void> verifyWithBackend({
    required String familyId,
    required PurchaseDetails purchase,
  }) async {
    await FirebaseFunctions.instance.httpsCallable('verifySubscriptionPurchase').call(
      <String, dynamic>{
        'familyId': familyId,
        'productId': purchase.productID,
        'purchaseToken': purchase.verificationData.serverVerificationData,
      },
    );
  }

  /// Play requires acknowledging (or "completing," in this package's terms)
  /// a purchase within 3 days or it's automatically refunded — always call
  /// this after a successful `verifyWithBackend`, regardless of whether the
  /// purchase is brand new or a restore.
  Future<void> completePurchase(PurchaseDetails purchase) {
    if (purchase.pendingCompletePurchase) {
      return _iap.completePurchase(purchase);
    }
    return Future.value();
  }
}
