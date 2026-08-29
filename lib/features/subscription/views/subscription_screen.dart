import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recruiter_talentbay/features/auth/controllers/auth_controller.dart';
import 'package:recruiter_talentbay/features/subscription/views/premium_subscription_screen.dart';

/// The single entry point for subscription purchases throughout the app.
///
/// Android users who have not subscribed yet see the introductory Razorpay
/// offer on the same page as the paid plans. iOS users always see the
/// StoreKit-backed paid plans because the introductory offer is Android-only.
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider.notifier).currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in')),
      );
    }

    final profileAsync = ref.watch(recruiterProfileProvider(user.uid));
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    return profileAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Scaffold(
        body: Center(child: Text('Error loading subscription plans: $error')),
      ),
      data: (profile) {
        final canUseTrial = profile?.subscriptionPlanId == null;
        return PremiumSubscriptionScreen(
          includeTrial: !isIOS && canUseTrial,
        );
      },
    );
  }
}
