import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recruiter_talentbay/theme/theme_provider.dart';
import '../../../theme/app_colors.dart';
import 'about_screen.dart';
import 'package:recruiter_talentbay/core/widgets/app_dialogs.dart';
import 'package:recruiter_talentbay/features/auth/controllers/auth_controller.dart';
import 'package:recruiter_talentbay/features/auth/data/auth_repository.dart';
import 'package:recruiter_talentbay/features/subscription/views/subscription_screen.dart';
import '../../../core/services/notification_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {

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
              final profileAsync = ref.watch(recruiterProfileProvider(userId));

              return profileAsync.when(
                loading: () => const SizedBox(
                  height: 56,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stackTrace) => const SizedBox.shrink(),
                data: (user) {
                  final expiry = user?.subscriptionExpiry;
                  final isExpired =
                      expiry != null && expiry.isBefore(DateTime.now());
                  final isPremiumActive =
                      user?.isSubscribed == true && !isExpired;

                  if (isPremiumActive) {
                    final isCancelled =
                        user?.isSubscriptionCancelled == true;
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.verified,
                            color: Colors.green,
                            size: 24,
                          ),
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
                                    isCancelled
                                        ? 'Cancels: ${expiry.day}/${expiry.month}/${expiry.year}'
                                        : 'Expires: ${expiry.day}/${expiry.month}/${expiry.year}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSubLight,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (!isCancelled)
                            TextButton(
                              onPressed: () =>
                                  _handleCancelSubscription(context, user),
                              style: TextButton.styleFrom(
                                foregroundColor: colorScheme.error,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                              child: const Text(
                                'CANCEL',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }

                  return SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SubscriptionScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.workspace_premium_outlined),
                      label: const Text('VIEW PREMIUM PLANS'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: colorScheme.primary),
                        foregroundColor: colorScheme.primary,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                    ),
                  );
                },
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
