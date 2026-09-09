import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recruiter_talentbay/core/config/subscription_config.dart';
import 'package:recruiter_talentbay/core/services/subscription_service.dart';

void main() {
  group('SubscriptionConfig Tests', () {
    test('StoreKit product IDs are correctly defined and mapped for all plans', () {
      expect(
        SubscriptionConfig.getStoreKitProductId('monthly_1499'),
        'com.waqttix.talentbay.recruiter.monthly',
      );
      expect(
        SubscriptionConfig.getStoreKitProductId('six_months_8549'),
        'com.waqttix.talentbay.recruiter.sixmonths',
      );
      expect(
        SubscriptionConfig.getStoreKitProductId('yearly_17089'),
        'com.waqttix.talentbay.recruiter.yearly',
      );
      expect(
        SubscriptionConfig.getStoreKitProductId('unknown_plan'),
        isNull,
      );
    });

    test('All subscription plans have matching StoreKit product IDs', () {
      for (final plan in SubscriptionService.plans) {
        final storeKitId = SubscriptionConfig.getStoreKitProductId(plan.id);
        expect(
          storeKitId,
          isNotNull,
          reason: 'Plan ${plan.id} must have a corresponding StoreKit product ID',
        );
      }
    });
  });

  group('SubscriptionService Restore State Tests', () {
    test('Initial isRestoring is false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service = container.read(subscriptionServiceProvider);
      expect(service.isRestoring, isFalse);
    });

    test('getPlanPriceDisplay returns fallback rupee formatting when no StoreKit details loaded', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service = container.read(subscriptionServiceProvider);
      expect(
        service.getPlanPriceDisplay(SubscriptionService.plans[0]),
        '₹1499',
      );
      expect(
        service.getPlanPriceDisplay(SubscriptionService.plans[1]),
        '₹8549',
      );
      expect(
        service.getPlanPriceDisplay(SubscriptionService.plans[2]),
        '₹17089',
      );
    });
  });
}
