import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../data/local_repository.dart';

const monthlyProductId = String.fromEnvironment('ASCEND_RC_MONTHLY_PRODUCT_ID');
const annualProductId = String.fromEnvironment('ASCEND_RC_ANNUAL_PRODUCT_ID');
const proEntitlementId = String.fromEnvironment('ASCEND_RC_PRO_ENTITLEMENT_ID');

class SubscriptionStatus {
  const SubscriptionStatus({required this.isPro, required this.verified, this.expiresAt, this.message});
  final bool isPro;
  final bool verified;
  final DateTime? expiresAt;
  final String? message;
}

enum PurchaseState { purchased, pending, cancelled, failed, unavailable }

class PurchaseOutcome {
  const PurchaseOutcome(this.state, {this.message});
  final PurchaseState state;
  final String? message;
}

class SubscriptionService {
  SubscriptionService({required this.repository, String? publicSdkKey})
      : _publicSdkKey = publicSdkKey ?? const String.fromEnvironment('ASCEND_RC_ANDROID_KEY');

  final LocalRepository repository;
  final String _publicSdkKey;
  bool _configured = false;
  String? configurationMessage;

  bool get configured => _configured;

  Future<void> openSubscriptionManagement() async {
    const channel = MethodChannel('ascend/store');
    await channel.invokeMethod<void>('manageSubscriptions');
  }

  /// Invalidate the SDK-managed customer-info cache during local data erasure.
  /// Play purchase records remain with the store and can be restored explicitly.
  Future<void> invalidateLocalCustomerInfoCache() async {
    if (_configured) await Purchases.invalidateCustomerInfoCache();
  }

  Future<void> initialize() async {
    if (_publicSdkKey.trim().isEmpty || monthlyProductId.trim().isEmpty ||
        annualProductId.trim().isEmpty || proEntitlementId.trim().isEmpty) {
      configurationMessage = 'RevenueCat, Google Play product, or entitlement identifiers are not configured for this build.';
      return;
    }
    try {
      await Purchases.configure(PurchasesConfiguration(_publicSdkKey.trim()));
      _configured = true;
    } on PlatformException catch (error) {
      configurationMessage = error.message ?? 'Google Play subscriptions could not be initialized.';
      _configured = false;
    } on MissingPluginException {
      configurationMessage = 'Google Play billing is not available on this build.';
      _configured = false;
    } on Object {
      configurationMessage = 'Google Play billing could not be initialized.';
      _configured = false;
    }
  }

  Future<List<Package>> loadProPackages() async {
    if (!_configured) return const [];
    final offerings = await Purchases.getOfferings();
    final packages = offerings.current?.availablePackages ?? const <Package>[];
    return packages.where((package) =>
        package.storeProduct.identifier == monthlyProductId ||
        package.storeProduct.identifier == annualProductId).toList(growable: false);
  }

  Future<PurchaseOutcome> purchase(Package package) async {
    if (!_configured) return const PurchaseOutcome(PurchaseState.unavailable, message: 'Purchases are not configured.');
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      final status = await _saveCustomerInfo(result.customerInfo);
      return status.isPro
          ? const PurchaseOutcome(PurchaseState.purchased)
          : const PurchaseOutcome(PurchaseState.pending, message: 'The store has not confirmed this purchase yet.');
    } on PlatformException catch (error) {
      final code = PurchasesErrorHelper.getErrorCode(error);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return const PurchaseOutcome(PurchaseState.cancelled);
      }
      if (code == PurchasesErrorCode.paymentPendingError) {
        return const PurchaseOutcome(PurchaseState.pending, message: 'Google Play is processing the purchase. Pro access will start only after the store confirms it.');
      }
      return PurchaseOutcome(PurchaseState.failed, message: error.message ?? 'The purchase could not be completed.');
    } on MissingPluginException {
      return const PurchaseOutcome(PurchaseState.unavailable, message: 'Billing is available on supported Android builds only.');
    } on Object {
      return const PurchaseOutcome(PurchaseState.failed, message: 'The store purchase could not be verified. No Pro access was granted.');
    }
  }

  Future<PurchaseOutcome> restore() async {
    if (!_configured) return const PurchaseOutcome(PurchaseState.unavailable, message: 'Purchases are not configured.');
    try {
      final info = await Purchases.restorePurchases();
      final status = await _saveCustomerInfo(info);
      return status.isPro
          ? const PurchaseOutcome(PurchaseState.purchased, message: 'Purchases restored.')
          : const PurchaseOutcome(PurchaseState.failed, message: 'No active ASCEND Pro purchase was found for this store account.');
    } on PlatformException catch (error) {
      return PurchaseOutcome(PurchaseState.failed, message: error.message ?? 'Restore could not be completed.');
    } on MissingPluginException {
      return const PurchaseOutcome(PurchaseState.unavailable, message: 'Restore is available on supported Android builds only.');
    } on Object {
      return const PurchaseOutcome(PurchaseState.failed, message: 'The store restore could not be verified.');
    }
  }

  Future<SubscriptionStatus> refreshStatus() async {
    if (_configured) {
      try {
        return await _saveCustomerInfo(await Purchases.getCustomerInfo());
      } on PlatformException {
        return _cachedStatus();
      } on MissingPluginException {
        return _cachedStatus();
      } on Object {
        return _cachedStatus();
      }
    }
    return _cachedStatus();
  }

  Future<SubscriptionStatus> _saveCustomerInfo(CustomerInfo info) async {
    final entitlement = info.entitlements.active[proEntitlementId];
    final expiration = entitlement?.expirationDate == null
        ? null
        : DateTime.tryParse(entitlement!.expirationDate!)?.toUtc();
    final active = entitlement?.isActive == true &&
        (expiration == null || expiration.isAfter(DateTime.now().toUtc()));
    await repository.saveSubscriptionSnapshot({
      'active': active,
      'verifiedAt': DateTime.now().toUtc().toIso8601String(),
      'expiresAt': expiration?.toIso8601String(),
      'productIdentifier': entitlement?.productIdentifier,
      'periodType': entitlement?.periodType.name,
    });
    return SubscriptionStatus(isPro: active, verified: true, expiresAt: expiration);
  }

  Future<SubscriptionStatus> _cachedStatus() async {
    final snapshot = await repository.readSubscriptionSnapshot();
    if (snapshot == null) return const SubscriptionStatus(isPro: false, verified: false);
    final verifiedAt = DateTime.tryParse(snapshot['verifiedAt'] as String? ?? '')?.toUtc();
    final expiresAt = DateTime.tryParse(snapshot['expiresAt'] as String? ?? '')?.toUtc();
    final cacheAge = verifiedAt == null ? null : DateTime.now().toUtc().difference(verifiedAt);
    final fresh = cacheAge != null && !cacheAge.isNegative && cacheAge <= const Duration(hours: 72);
    final cachedProduct = snapshot['productIdentifier'] as String?;
    final knownProduct = cachedProduct != null &&
        (cachedProduct == monthlyProductId || cachedProduct == annualProductId) &&
        proEntitlementId.isNotEmpty;
    // The configured catalog contains renewable subscriptions only; an offline cache
    // without a matching configured product and known future expiration cannot grant access.
    final active = snapshot['active'] == true && knownProduct && fresh &&
        expiresAt != null && expiresAt.isAfter(DateTime.now().toUtc());
    return SubscriptionStatus(
      isPro: active,
      verified: false,
      expiresAt: expiresAt,
      message: active ? 'Using a recent verified offline entitlement.' : null,
    );
  }
}
