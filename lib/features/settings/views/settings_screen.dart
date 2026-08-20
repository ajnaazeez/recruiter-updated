import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recruiter_talentbay/core/config/subscription_config.dart';
import 'package:recruiter_talentbay/core/services/subscription_service.dart';
import 'package:recruiter_talentbay/theme/theme_provider.dart';
import '../../../theme/app_colors.dart';
import 'about_screen.dart';
import 'package:recruiter_talentbay/core/widgets/app_dialogs.dart';
import 'package:recruiter_talentbay/features/auth/controllers/auth_controller.dart';
import 'package:recruiter_talentbay/features/auth/data/auth_repository.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/notification_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _selectedPlanIndex = 0;
  bool _isLoading = false;
  bool _initializedPlanIndex = false;

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final userId = ref.watch(authControllerProvider.notifier).currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          // Theme Settings Section
          _buildSectionTitle(context, 'APPEARANCE'),
          const SizedBox(height: 16),
          _buildThemeOption(
            context: context,
            ref: ref,
            title: 'Light Theme',
            icon: Icons.wb_sunny_outlined,
            value: ThemeMode.light,
            groupValue: themeMode,
            onTap: () => ref.read(themeModeProvider.notifier).setLight(),
          ),
          const Divider(height: 1),
          _buildThemeOption(
            context: context,
            ref: ref,
            title: 'Dark Theme',
            icon: Icons.nightlight_outlined,
            value: ThemeMode.dark,
            groupValue: themeMode,
            onTap: () => ref.read(themeModeProvider.notifier).setDark(),
          ),
          const Divider(height: 1),
          _buildThemeOption(
            context: context,
            ref: ref,
            title: 'System Default',
            icon: Icons.phone_android_outlined,
            value: ThemeMode.system,
            groupValue: themeMode,
            onTap: () => ref.read(themeModeProvider.notifier).setSystem(),
          ),

          const SizedBox(height: 24),

          // Subscription Section
          _buildSectionTitle(context, 'SUBSCRIPTION'),
          const SizedBox(height: 16),
          Consumer(
            builder: (context, ref, child) {
              final userAsync = ref.watch(recruiterProfileProvider(userId));

              return userAsync.when(
                data: (user) {
                  final rawIsSubscribed = user?.isSubscribed ?? false;
                  final expiry = user?.subscriptionExpiry;
                  final isSubscriptionCancelled = user?.isSubscriptionCancelled ?? false;
                  final planId = user?.subscriptionPlanId;

                  final now = DateTime.now();
                  final hasExpired = expiry != null && expiry.isBefore(now);
                  final isSubscribed = rawIsSubscribed && !hasExpired;
                  final isTrial = planId == 'trial_60_days_1_rupee';

                  final isPremiumActive = isSubscribed && !isTrial;

                  // 1. If Premium Active, show active subscription status card
                  if (isPremiumActive) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified, color: Colors.green, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PREMIUM ACTIVE',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                if (expiry != null)
                                  Text(
                                    isSubscriptionCancelled
                                        ? 'Cancels: ${expiry.day}/${expiry.month}/${expiry.year}'
                                        : 'Expires: ${expiry.day}/${expiry.month}/${expiry.year}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSubLight,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (!isSubscriptionCancelled)
                            TextButton(
                              onPressed: () => _handleCancelSubscription(context, user),
                              style: TextButton.styleFrom(
                                foregroundColor: colorScheme.error,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                        ],
                      ),
                    );
                  }

                  // 2. If NOT premium active (FREE PLAN, TRIAL ACTIVE, or PLAN EXPIRED)
                  final isEligibleForTrial = planId == null;
                  final plans = isEligibleForTrial
                      ? [SubscriptionService.trialPlan, ...SubscriptionService.plans]
                      : SubscriptionService.plans;

                  // Initialize selected index once
                  if (!_initializedPlanIndex) {
                    _selectedPlanIndex = isEligibleForTrial ? 0 : 2;
                    _initializedPlanIndex = true;
                  }

                  // Safeguard index bounds
                  if (_selectedPlanIndex >= plans.length) {
                    _selectedPlanIndex = 0;
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // If trial is currently active, show Trial Active card
                      if (isSubscribed && isTrial) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.verified, color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'TRIAL ACTIVE',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              if (expiry != null) ...[
                                const Spacer(),
                                Text(
                                  'Expires: ${expiry.day}/${expiry.month}/${expiry.year}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSubLight,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ] else if (hasExpired) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: colorScheme.error.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colorScheme.error.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: colorScheme.error, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'PLAN EXPIRED',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.error,
                                ),
                              ),
                              if (expiry != null) ...[
                                const Spacer(),
                                Text(
                                  'Expired: ${expiry.day}/${expiry.month}/${expiry.year}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSubLight,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],

                      // Render selectable cards
                      for (int i = 0; i < plans.length; i++) ...[
                        _buildPlanCard(context, plans[i], i),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 16),

                      // Continue / Subscribe Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          elevation: 0,
                          minimumSize: const Size(double.infinity, 50),
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        onPressed: _isLoading
                            ? null
                            : () => _handleSubscribe(context, ref, plans),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'SUBSCRIBE - ₹${plans[_selectedPlanIndex].amountInRupees.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  letterSpacing: 1.2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Recurring billing. Cancel anytime.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSubLight,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () async {
                              final Uri url = Uri.parse('https://www.apple.com/legal/internet-services/itunes/dev/stdeula/');
                              if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Could not launch Terms of Use')),
                                  );
                                }
                              }
                            },
                            child: Text(
                              'Terms of Use (EULA)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          Text(
                            '  |  ',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSubLight,
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              final Uri url = Uri.parse('https://www.waqtixllp.com/privacy-and-policy');
                              if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Could not launch Privacy Policy')),
                                  );
                                }
                              }
                            },
                            child: Text(
                              'Privacy Policy',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, s) => const SizedBox(),
              );
            },
          ),
          const SizedBox(height: 40),

          // About Section
          _buildSectionTitle(context, 'ABOUT'),
          const SizedBox(height: 16),
          _buildListTile(
            context: context,
            title: 'Version',
            subtitle: '1.0.0',
            icon: Icons.info_outline,
          ),
          const Divider(height: 1),
          _buildListTile(
            context: context,
            title: 'App Name',
            subtitle: 'Talent Bay Recruiter',
            icon: Icons.business_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AboutScreen()),
            ),
          ),

          const SizedBox(height: 40),

          // Preferences
          _buildSectionTitle(context, 'PREFERENCES'),
          const SizedBox(height: 16),
          Consumer(
            builder: (context, ref, child) {
              final isEnabled = ref.watch(notificationsEnabledProvider);
              return SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                title: Text(
                  'Notifications',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                subtitle: Text(
                  isEnabled ? 'On' : 'Off',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSubLight),
                ),
                value: isEnabled,
                onChanged: (val) {
                  ref.read(notificationsEnabledProvider.notifier).toggle(val);
                },
                secondary: Icon(
                  isEnabled ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                activeColor: Theme.of(context).colorScheme.primary,
              );
            },
          ),
          const Divider(height: 1),
          _buildListTile(
            context: context,
            title: 'Language',
            subtitle: 'English',
            icon: Icons.language_outlined,
            enabled: false,
          ),

          const SizedBox(height: 40),

          // Logout
          OutlinedButton(
            onPressed: () async {
              final shouldLogout = await showLogoutDialog(context);
              if (shouldLogout) {
                ref.read(authControllerProvider.notifier).logout();
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.error,
              side: BorderSide(color: colorScheme.error),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
            child: const Text('LOG OUT'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPlanCard(
    BuildContext context,
    SubscriptionPlan plan,
    int index,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _selectedPlanIndex == index;
    final isYearly = plan.id == 'yearly_17089';

    BoxDecoration cardDecoration;
    if (isSelected) {
      cardDecoration = BoxDecoration(
        color: colorScheme.primary.withOpacity(0.08),
        border: Border.all(
          color: colorScheme.primary,
          width: 2.0,
        ),
        borderRadius: BorderRadius.zero,
      );
    } else if (isYearly) {
      cardDecoration = BoxDecoration(
        color: colorScheme.primary.withOpacity(0.02),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.4),
          width: 1.5,
        ),
        borderRadius: BorderRadius.zero,
      );
    } else {
      cardDecoration = BoxDecoration(
        color: Colors.transparent,
        border: Border.all(
          color: AppColors.borderLight,
          width: 1.0,
        ),
        borderRadius: BorderRadius.zero,
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedPlanIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: cardDecoration,
        child: Row(
          children: [
            // Custom Radio Indicator
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? colorScheme.primary
                      : AppColors.textSubLight,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        plan.name.toUpperCase(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (plan.discountLabel != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.zero,
                          ),
                          child: Text(
                            plan.discountLabel!.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 8,
                            ),
                          ),
                        ),
                      ],
                      if (isYearly) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.zero,
                          ),
                          child: Text(
                            'RECOMMENDED',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 8,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    plan.durationDisplay.toUpperCase(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSubLight,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '₹${plan.amountInRupees.toStringAsFixed(0)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: colorScheme.onSurface,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSubscribe(
    BuildContext context,
    WidgetRef ref,
    List<SubscriptionPlan> plans,
  ) async {
    final selectedPlan = plans[_selectedPlanIndex];

    // Proceed to checkout flow
    // The SubscriptionService internally handles the platform split (iOS vs Android)
    setState(() => _isLoading = true);
    final user = ref.read(authControllerProvider.notifier).currentUser;
    final recruiter = await ref
        .read(authControllerProvider.notifier)
        .getRecruiterProfile(user?.uid ?? '');

    if (!context.mounted) return;

    if (recruiter == null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: User profile not found')),
      );
      return;
    }

    final subscriptionService = ref.read(subscriptionServiceProvider);

    subscriptionService.startSubscriptionCheckout(
      user: recruiter,
      plan: selectedPlan,
      context: context,
      onResult: (success, message) {
        if (context.mounted) {
          setState(() => _isLoading = false);
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message), backgroundColor: Colors.green),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message), backgroundColor: Colors.red),
            );
          }
        }
      },
    );
  }

  void _handleCancelSubscription(BuildContext context, dynamic user) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Subscription'),
        content: const Text(
          'Are you sure you want to cancel your subscription? You will still have premium access until your current billing cycle ends.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('NO', style: TextStyle(color: colorScheme.onSurface)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('YES, CANCEL', style: TextStyle(color: colorScheme.error)),
          ),
        ],
      ),
    );

    if (shouldCancel == true && user != null) {
      try {
        await ref.read(authRepositoryProvider).updateRecruiterProfile(
          user.uid,
          {'isSubscriptionCancelled': true},
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Subscription successfully cancelled.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to cancel subscription: $e'),
              backgroundColor: colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required IconData icon,
    required ThemeMode value,
    required ThemeMode groupValue,
    required VoidCallback onTap,
  }) {
    final isSelected = value == groupValue;
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      leading: Icon(
        icon,
        color: isSelected ? colorScheme.primary : AppColors.textSubLight,
        size: 24,
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }

  Widget _buildListTile({
    required BuildContext context,
    required String title,
    required IconData icon,
    String? subtitle,
    bool enabled = true,
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = enabled ? colorScheme.onSurface : AppColors.textSubLight;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      enabled: enabled,
      onTap: onTap,
      leading: Icon(
        icon,
        color: enabled ? colorScheme.primary : AppColors.disabledLight,
        size: 24,
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSubLight),
            )
          : null,
    );
  }
}
