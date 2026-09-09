import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:recruiter_talentbay/core/config/subscription_config.dart';
import 'package:recruiter_talentbay/features/auth/data/auth_repository.dart';
import 'package:recruiter_talentbay/features/auth/models/recruiter_model.dart';
import 'package:recruiter_talentbay/features/auth/controllers/auth_controller.dart';

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService(ref);
});

class SubscriptionPlan {
  final String id;
  final String name;
  final int amountInPaise;
  final int durationInDays; // for expiry calculation
  final String durationDisplay; // e.g. "1 Month", "6 Months"
  final String? discountLabel; // e.g. "Save 5%"
  final String paymentLinkId;
  final String paymentLinkUrl;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.amountInPaise,
    required this.durationInDays,
    required this.durationDisplay,
    this.discountLabel,
    required this.paymentLinkId,
    required this.paymentLinkUrl,
  });

  double get amountInRupees => amountInPaise / 100.0;
}

class SubscriptionService {
  final Ref _ref;
  Razorpay? _razorpay;
  StreamSubscription<List<PurchaseDetails>>? _iapSubscription;
  Function(bool success, String message)? _onPaymentResult;

  static const String _razorpayKey = 'rzp_live_TIywUmGVFfdXXf';

  static const SubscriptionPlan trialPlan = SubscriptionPlan(
    id: 'trial_60_days_1_rupee',
    name: '60 Days Trial',
    amountInPaise: 100,
    durationInDays: 60,
    durationDisplay: '60 Days',
    discountLabel: 'Introductory Offer',
    paymentLinkId: 'plink_TKBiS1mNIb8s2V',
    paymentLinkUrl: 'https://rzp.io/rzp/I1CFdIg6',
  );

  // Define available plans
  static const List<SubscriptionPlan> plans = [
    SubscriptionPlan(
      id: 'monthly_1499',
      name: 'Monthly Plan',
      amountInPaise: 149900,
      durationInDays: 30,
      durationDisplay: '1 Month',
      paymentLinkId:
          'plink_TKBkf5W9XdX4FZ', // Old plan, maybe no link ID provided in prompt
      paymentLinkUrl: 'https://rzp.io/rzp/kfTA7ukQ',
    ),
    SubscriptionPlan(
      id: 'six_months_8549',
      name: '6 Months Plan',
      amountInPaise: 854900,
      durationInDays: 180,
      durationDisplay: '6 Months',
      discountLabel: 'Save 5%',
      paymentLinkId: 'plink_TKBlySr1QEr2yF',
      paymentLinkUrl: 'https://rzp.io/rzp/sUO0PuA',
    ),
    SubscriptionPlan(
      id: 'yearly_17089',
      name: 'Yearly Plan',
      amountInPaise: 1708900,
      durationInDays: 365,
      durationDisplay: '1 Year',
      discountLabel: 'Save 5%',
      paymentLinkId: 'plink_TKBn3lHxKW9N9V',
      paymentLinkUrl: 'https://rzp.io/rzp/o4Qy54f',
    ),
  ];

  // Helper to get a specific plan if needed, default to monthly
  static SubscriptionPlan get defaultPlan => plans[0];

  SubscriptionService(this._ref) {
    if (Platform.isAndroid) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    } else if (Platform.isIOS) {
      _initInAppPurchase();
    }
  }

  void dispose() {
    _razorpay?.clear();
    _iapSubscription?.cancel();
  }

  // Track the plan being purchased
  SubscriptionPlan? _currentPlan;
  bool _isRestoring = false;
  Function(bool success, String message)? _onRestoreResult;

  bool get isRestoring => _isRestoring;

  void _initInAppPurchase() {
    final Stream<List<PurchaseDetails>> purchaseUpdated =
        InAppPurchase.instance.purchaseStream;
    _iapSubscription = purchaseUpdated.listen(
      (purchaseDetailsList) {
        _handlePurchaseUpdates(purchaseDetailsList);
      },
      onDone: () {
        _iapSubscription?.cancel();
      },
      onError: (error) {
        debugPrint('IAP Purchase Stream Error: $error');
      },
    );
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        _onPaymentResult?.call(false, 'Purchase is pending...');
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        debugPrint('IAP Purchase Error: ${purchaseDetails.error}');
        if (_isRestoring && _onRestoreResult != null) {
          final callback = _onRestoreResult;
          _onRestoreResult = null;
          _isRestoring = false;
          callback?.call(
            false,
            'Unable to restore purchases. Please try again.',
          );
        } else {
          _onPaymentResult?.call(
            false,
            'Purchase failed. Please try again.',
          );
        }
        if (purchaseDetails.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchaseDetails);
        }
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        if (_isRestoring && _onRestoreResult != null) {
          final callback = _onRestoreResult;
          _onRestoreResult = null;
          _isRestoring = false;
          callback?.call(false, 'Restore cancelled by user.');
        } else {
          _onPaymentResult?.call(false, 'Purchase cancelled by user.');
        }
        if (purchaseDetails.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchaseDetails);
        }
      } else if (purchaseDetails.status == PurchaseStatus.restored) {
        final plan = _getPlanByStoreKitId(purchaseDetails.productID);
        if (plan != null) {
          try {
            await _activateAppleSubscription(purchaseDetails.purchaseID, plan);
            if (_isRestoring && _onRestoreResult != null) {
              final callback = _onRestoreResult;
              _onRestoreResult = null;
              _isRestoring = false;
              callback?.call(
                true,
                'Purchases restored successfully. Premium subscription activated.',
              );
            } else {
              _onPaymentResult?.call(
                true,
                'Purchases restored successfully. Premium subscription activated.',
              );
            }
          } catch (e) {
            debugPrint('Error activating restored Apple subscription: $e');
            if (_isRestoring && _onRestoreResult != null) {
              final callback = _onRestoreResult;
              _onRestoreResult = null;
              _isRestoring = false;
              callback?.call(
                false,
                'Unable to restore purchases. Please try again.',
              );
            } else {
              _onPaymentResult?.call(
                false,
                'Subscription restored but activation failed. Please contact support.',
              );
            }
          }
        } else {
          debugPrint('Restored product ${purchaseDetails.productID} not matched to plan');
          if (_isRestoring && _onRestoreResult != null) {
            final callback = _onRestoreResult;
            _onRestoreResult = null;
            _isRestoring = false;
            callback?.call(
              false,
              'Restored purchase found, but matching plan was not recognized.',
            );
          } else {
            _onPaymentResult?.call(
              false,
              'Restored purchase found, but matching plan was not recognized.',
            );
          }
        }
        if (purchaseDetails.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchaseDetails);
        }
      } else if (purchaseDetails.status == PurchaseStatus.purchased) {
        final plan = _currentPlan ?? _getPlanByStoreKitId(purchaseDetails.productID);
        if (plan != null) {
          try {
            await _activateAppleSubscription(purchaseDetails.purchaseID, plan);
            _onPaymentResult?.call(
              true,
              'Purchase successful! Premium subscription activated.',
            );
          } catch (e) {
            debugPrint('Error activating Apple subscription: $e');
            _onPaymentResult?.call(
              false,
              'Purchase successful but activation failed. Please contact support.',
            );
          }
        } else {
          _onPaymentResult?.call(
            false,
            'Purchase successful but matching plan not found.',
          );
        }
        if (purchaseDetails.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchaseDetails);
        }
      }
    }
  }

  /// Manually restores completed StoreKit purchases on iOS.
  Future<void> restorePurchases({
    required Function(bool success, String message) onResult,
  }) async {
    if (!Platform.isIOS) {
      onResult(false, 'Restore Purchases is only available on iOS.');
      return;
    }

    if (_isRestoring) {
      onResult(false, 'Restore is already in progress. Please wait.');
      return;
    }

    _isRestoring = true;
    _onRestoreResult = onResult;

    try {
      final bool available = await InAppPurchase.instance.isAvailable();
      if (!available) {
        _isRestoring = false;
        _onRestoreResult = null;
        onResult(
          false,
          'In-App Purchases are currently unavailable on this device.',
        );
        return;
      }

      await InAppPurchase.instance.restorePurchases();

      // Allow a reasonable grace period for StoreKit to deliver restored transactions
      // through the purchaseStream before concluding that no purchases exist.
      await Future.delayed(const Duration(milliseconds: 2500));

      if (_isRestoring && _onRestoreResult != null) {
        final callback = _onRestoreResult;
        _onRestoreResult = null;
        _isRestoring = false;
        callback?.call(false, 'No previous purchases found.');
      }
    } catch (e) {
      debugPrint('Error during StoreKit restorePurchases: $e');
      if (_isRestoring && _onRestoreResult != null) {
        final callback = _onRestoreResult;
        _onRestoreResult = null;
        _isRestoring = false;
        callback?.call(
          false,
          'Unable to restore purchases. Please try again.',
        );
      }
    } finally {
      _isRestoring = false;
      _onRestoreResult = null;
    }
  }

  Map<String, ProductDetails> _storeKitProductDetails = {};
  Map<String, ProductDetails> get storeKitProductDetails => _storeKitProductDetails;

  /// Loads dynamic StoreKit product details (including localized pricing and currency).
  Future<void> fetchProductDetails() async {
    if (!Platform.isIOS) return;
    try {
      final available = await InAppPurchase.instance.isAvailable();
      if (!available) return;

      final storeKitIds = SubscriptionConfig.planStoreKitIds.values.toSet();
      final response = await InAppPurchase.instance.queryProductDetails(storeKitIds);
      if (response.productDetails.isNotEmpty) {
        _storeKitProductDetails = {
          for (var p in response.productDetails) p.id: p,
        };
      }
    } catch (e) {
      debugPrint('Error loading StoreKit product details: $e');
    }
  }

  /// Returns localized StoreKit price on iOS if available, otherwise returns fallback rupee price.
  String getPlanPriceDisplay(SubscriptionPlan plan) {
    if (Platform.isIOS) {
      final storeKitId = SubscriptionConfig.getStoreKitProductId(plan.id);
      if (storeKitId != null && _storeKitProductDetails.containsKey(storeKitId)) {
        return _storeKitProductDetails[storeKitId]!.price;
      }
    }
    return '₹${plan.amountInRupees.toStringAsFixed(0)}';
  }

  SubscriptionPlan? _getPlanByStoreKitId(String storeKitId) {
    for (var plan in plans) {
      if (SubscriptionConfig.getStoreKitProductId(plan.id) == storeKitId) {
        return plan;
      }
    }
    return null;
  }

  Future<void> _startAppleSubscriptionCheckout(SubscriptionPlan plan) async {
    try {
      final bool available = await InAppPurchase.instance.isAvailable();
      if (!available) {
        _onPaymentResult?.call(
          false,
          'In-App Purchases are not available on this device.',
        );
        return;
      }

      final storeKitId = SubscriptionConfig.getStoreKitProductId(plan.id);
      if (storeKitId == null) {
        _onPaymentResult?.call(
          false,
          'StoreKit product ID not configured for plan: ${plan.id}',
        );
        return;
      }

      final ProductDetailsResponse response =
          await InAppPurchase.instance.queryProductDetails({storeKitId});
      
      if (response.notFoundIDs.contains(storeKitId) ||
          response.productDetails.isEmpty) {
        _onPaymentResult?.call(
          false,
          'Subscription product could not be found on the App Store.',
        );
        return;
      }

      final purchaseParam = PurchaseParam(
        productDetails: response.productDetails.first,
      );
      
      await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
    } catch (e) {
      debugPrint('Error during StoreKit checkout: $e');
      _onPaymentResult?.call(
        false,
        'Failed to start App Store checkout: $e',
      );
    }
  }

  Future<void> _activateAppleSubscription(
    String? transactionId,
    SubscriptionPlan plan,
  ) async {
    final user = _ref.read(authControllerProvider.notifier).currentUser;
    if (user != null) {
      final expiryDate = DateTime.now().add(
        Duration(days: plan.durationInDays),
      );
      await _ref.read(authRepositoryProvider).updateRecruiterProfile(user.uid, {
        'isSubscribed': true,
        'subscriptionExpiry': expiryDate,
        'appleSubscriptionId': transactionId,
        'subscriptionPlanId': plan.id,
        'subscriptionAmount': plan.amountInPaise,
        'subscriptionDate': DateTime.now(),
      });
      // Force reload or state update
      _ref.invalidate(recruiterProfileProvider(user.uid));
    }
  }

  void startSubscriptionCheckout({
    required RecruiterModel user,
    required SubscriptionPlan plan,
    required Function(bool success, String message) onResult,
    required BuildContext context,
  }) {
    _onPaymentResult = onResult;
    _currentPlan = plan;

    if (Platform.isIOS) {
      _startAppleSubscriptionCheckout(plan);
      return;
    }

    final prefill = <String, String>{};
    if (user.phoneNumber.isNotEmpty && user.phoneNumber.length >= 10) {
      prefill['contact'] = user.phoneNumber;
    } else {
      prefill['contact'] = '9999999999'; // Dummy valid contact to bypass validation crashes
    }
    
    if (user.officialEmail.isNotEmpty && user.officialEmail.contains('@')) {
      prefill['email'] = user.officialEmail;
    } else {
      prefill['email'] = 'test@example.com'; // Dummy valid email
    }

    var options = {
      'key': _razorpayKey,
      'amount': plan.amountInPaise,
      'name': 'Talent Bay',
      'description': plan.name,
      'prefill': prefill,
      'theme': {
        'color': '#000000'
      }
    };

    // If using Payment Links via Razorpay Standard Checkout, usually 'subscription_id' is used for recurring.
    // However, the prompt gives "payment link id" and "payment link url".
    // If the intention is to use the standard checkout with a one-time payment that acts as a subscription manually (since we handle expiry locally),
    // we just pass the amount.
    // If the user wanted to use the actual Subscription ID (recurring auto-debit), we would need 'subscription_id'.
    // Given the prompt implementation was just amount-based one-time payment for 30 days previously,
    // we will stick to that logic but with different amounts/durations.
    // The "payment link" info might be for reference or if we were redirecting to a webview,
    // but here we are using the SDK. We'll use the amount from the plan.

    try {
      _razorpay?.open(options);
    } catch (e) {
      debugPrint('Error: $e');
      _onPaymentResult?.call(false, 'Failed to start payment: $e');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    // Payment Successful
    final paymentId = response.paymentId;
    final signature = response.signature;
    final orderId = response.orderId;
    debugPrint(
      "Payment Success: $paymentId, Signature: $signature, OrderId: $orderId",
    );

    // In a real app, verify signature on backend:
    // https://razorpay.com/docs/payment-gateway/web-integration/standard/verification/

    // Activate subscription in Firestore
    if (_currentPlan != null) {
      try {
        await _activateSubscription(paymentId, _currentPlan!);
        _onPaymentResult?.call(
          true,
          'Payment Successful! Subscription activated.',
        );
      } catch (e) {
        _onPaymentResult?.call(
          false,
          'Payment successful but activation failed: $e',
        );
      }
    } else {
      _onPaymentResult?.call(
        false,
        'Payment successful but plan details missing.',
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    // Payment Failed
    String msg = "ERROR: ${response.code} - ${response.message}";
    _onPaymentResult?.call(false, msg);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    // External Wallet Selected
    _onPaymentResult?.call(false, "Wallet selected: ${response.walletName}");
  }

  Future<void> _activateSubscription(
    String? paymentId,
    SubscriptionPlan plan,
  ) async {
    final user = _ref.read(authControllerProvider.notifier).currentUser;
    if (user != null) {
      final expiryDate = DateTime.now().add(
        Duration(days: plan.durationInDays),
      );
      await _ref.read(authRepositoryProvider).updateRecruiterProfile(user.uid, {
        'isSubscribed': true,
        'subscriptionExpiry': expiryDate,
        'razorpaySubscriptionId': paymentId,
        'subscriptionPlanId': plan.id,
        'subscriptionAmount': plan.amountInPaise,
        'subscriptionDate': DateTime.now(),
      });
      // Force reload or state update
      _ref.invalidate(recruiterProfileProvider(user.uid));
    }
  }
}
