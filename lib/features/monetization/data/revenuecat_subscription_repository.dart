import 'dart:async';

import 'package:flow_music/core/config/app_environment.dart';
import 'package:flow_music/features/monetization/domain/entities/subscription_access.dart';
import 'package:flow_music/features/monetization/domain/repositories/subscription_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class RevenueCatSubscriptionRepository implements SubscriptionRepository {
  RevenueCatSubscriptionRepository();

  final _updates = StreamController<SubscriptionAccess>.broadcast();
  SubscriptionAccess _current = const SubscriptionAccess.loading();
  final _packages = <PremiumOfferKind, Package>{};
  bool _initialized = false;
  Future<void>? _initialization;
  Timer? _expiryTimer;

  late final CustomerInfoUpdateListener _customerInfoListener =
      _handleCustomerInfo;

  @override
  bool get isAvailable =>
      AppEnvironment.supportsNativeMonetization &&
      AppEnvironment.revenueCatApiKey.trim().isNotEmpty;

  @override
  Stream<SubscriptionAccess> watchAccess() async* {
    yield _current;
    yield* _updates.stream;
  }

  @override
  Future<void> initialize() => _initialization ??= _initialize().catchError((
    Object error,
    StackTrace stackTrace,
  ) {
    _initialization = null;
    Error.throwWithStackTrace(error, stackTrace);
  });

  Future<void> _initialize() async {
    if (_initialized) {
      await refresh();
      return;
    }
    if (!isAvailable) {
      _emit(const SubscriptionAccess.unavailable());
      return;
    }
    if (kDebugMode) await Purchases.setLogLevel(LogLevel.debug);
    // Sin appUserID ni logout: el SDK conserva la identidad local existente y
    // genera una anónima en instalaciones nuevas. Restaurar consulta la tienda.
    await Purchases.configure(
      PurchasesConfiguration(AppEnvironment.revenueCatApiKey),
    );
    Purchases.addCustomerInfoUpdateListener(_customerInfoListener);
    _initialized = true;
    await refresh();
  }

  @override
  Future<List<PremiumOffer>> loadOffers() async {
    await initialize();
    if (!_initialized) {
      throw const SubscriptionFailure(
        'Los aportes todavia no estan configurados.',
      );
    }
    try {
      final offerings = await Purchases.getOfferings();
      final offering = offerings.all[AppEnvironment.revenueCatOfferingId];
      // Only contribution products are offered. Historical purchases remain
      // attached to the entitlement so existing supporters retain their access.
      final productIds = {
        PremiumOfferKind.small:
            AppEnvironment.revenueCatContributionSmallProductId,
        PremiumOfferKind.medium:
            AppEnvironment.revenueCatContributionMediumProductId,
        PremiumOfferKind.large:
            AppEnvironment.revenueCatContributionLargeProductId,
      };
      _packages.clear();
      for (final entry in productIds.entries) {
        final package = _findPackage(offering, productId: entry.value);
        if (package != null) _packages[entry.key] = package;
      }
      if (_packages.isEmpty) {
        throw const SubscriptionFailure(
          'Los aportes no estan disponibles en esta tienda.',
        );
      }
      return _packages.entries
          .map(
            (entry) => PremiumOffer(
              kind: entry.key,
              productId: entry.value.storeProduct.identifier,
              priceLabel: entry.value.storeProduct.priceString,
              period: entry.value.storeProduct.subscriptionPeriod,
            ),
          )
          .toList(growable: false);
    } on PlatformException catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<SubscriptionAccess> purchase(PremiumOfferKind kind) async {
    try {
      if (!_packages.containsKey(kind)) await loadOffers();
      final selected = _packages[kind];
      if (selected == null) {
        throw SubscriptionFailure(
          'Este aporte no esta disponible en esta tienda.',
        );
      }
      final result = await Purchases.purchase(PurchaseParams.package(selected));
      return _map(result.customerInfo);
    } on PlatformException catch (error) {
      throw _failure(error);
    }
  }

  Package? _findPackage(Offering? offering, {required String productId}) {
    if (offering == null) return null;
    return offering.availablePackages.cast<Package?>().firstWhere(
      (item) =>
          item != null &&
          revenueCatProductIdentifierMatches(
            item.storeProduct.identifier,
            productId,
          ),
      orElse: () => null,
    );
  }

  @override
  Future<SubscriptionAccess> restore() async {
    await initialize();
    try {
      final info = await Purchases.restorePurchases();
      return _map(info);
    } on PlatformException catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<SubscriptionAccess> refresh() async {
    if (!_initialized) return _current;
    try {
      final info = await Purchases.getCustomerInfo();
      return _map(info);
    } on PlatformException catch (error) {
      throw _failure(error);
    }
  }

  void _handleCustomerInfo(CustomerInfo info) {
    _map(info);
  }

  SubscriptionAccess _map(CustomerInfo info) {
    final entitlement =
        info.entitlements.all[AppEnvironment.revenueCatEntitlementId];
    DateTime? monthlyExpiry;
    for (final id in info.activeSubscriptions) {
      if (!revenueCatProductIdentifierMatches(
        id,
        AppEnvironment.revenueCatMonthlyProductId,
      )) {
        continue;
      }
      final expiry = DateTime.tryParse(info.allExpirationDates[id] ?? '');
      if (expiry != null &&
          expiry.isAfter(DateTime.now()) &&
          (monthlyExpiry == null || expiry.isAfter(monthlyExpiry))) {
        monthlyExpiry = expiry;
      }
    }
    final access = SubscriptionAccess(
      isResolved: true,
      serviceAvailable: true,
      isActive: entitlement?.isActive ?? false,
      hasMonthlySubscription: monthlyExpiry != null,
      monthlyExpiresAt: monthlyExpiry,
      managementUrl: info.managementURL,
      willRenew: entitlement?.willRenew ?? false,
      productId: entitlement?.productIdentifier,
      expiresAt: entitlement?.expirationDate == null
          ? null
          : DateTime.tryParse(entitlement!.expirationDate!),
      store: entitlement?.store.name,
    );
    _emit(access);
    return access;
  }

  void _emit(SubscriptionAccess access) {
    _current = access;
    if (_updates.isClosed) return;
    _updates.add(access);
    _expiryTimer?.cancel();
    final now = DateTime.now();
    final expirations = [
      access.expiresAt,
      access.monthlyExpiresAt,
    ].whereType<DateTime>().where((date) => date.isAfter(now)).toList()..sort();
    if (access.isResolved && expirations.isNotEmpty) {
      _expiryTimer = Timer(expirations.first.difference(now), () async {
        // Refresh at the paid boundary even if the app stays in the foreground.
        try {
          await Purchases.invalidateCustomerInfoCache();
          await refresh();
        } catch (_) {
          _emit(_current);
        }
      });
    }
  }

  SubscriptionFailure _failure(PlatformException error) {
    PurchasesErrorCode code;
    try {
      code = PurchasesErrorHelper.getErrorCode(error);
    } catch (_) {
      code = PurchasesErrorCode.unknownError;
    }
    return SubscriptionFailure(
      error.message ?? 'No se pudo completar la operacion con la tienda.',
      cancelled: code == PurchasesErrorCode.purchaseCancelledError,
    );
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    if (_initialized) {
      Purchases.removeCustomerInfoUpdateListener(_customerInfoListener);
    }
    _updates.close();
  }
}

@visibleForTesting
bool revenueCatProductIdentifierMatches(
  String storeIdentifier,
  String configuredProductId,
) {
  return storeIdentifier == configuredProductId ||
      storeIdentifier.startsWith('$configuredProductId:');
}
