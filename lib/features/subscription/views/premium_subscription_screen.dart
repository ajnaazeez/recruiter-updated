import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:recruiter_talentbay/core/services/subscription_service.dart';
import 'package:recruiter_talentbay/features/auth/controllers/auth_controller.dart';
import 'package:recruiter_talentbay/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class PremiumSubscriptionScreen extends ConsumerStatefulWidget {
  const PremiumSubscriptionScreen({super.key});

  @override
  ConsumerState<PremiumSubscriptionScreen> createState() => _PremiumSubscriptionScreenState();
}

class _PremiumSubscriptionScreenState extends ConsumerState<PremiumSubscriptionScreen> {
  bool _isLoading = false;
  int _selectedPlanIndex = 2; // Default to Yearly Plan (best value)

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final plans = SubscriptionService.plans;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.workspace_premium_rounded, size: 80, color: colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                'PREMIUM SUBSCRIPTION',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'CHOOSE A PLAN TO UNLOCK ALL FEATURES',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSubLight,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Plans List
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: plans.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  return _buildPlanCard(context, plans[index], index);
                },
              ),

              const SizedBox(height: 40),
              _buildFeatureSection(context),
              const SizedBox(height: 40),

              // Dynamic summary of selected plan's benefits
              _buildPurchaseDetailsSummary(context, plans[_selectedPlanIndex]),

              // Subscribe Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 56),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero, // Sharp corners
                  ),
                ),
                onPressed: _isLoading
                    ? null
                    : () => _handleSubscribe(context, ref, plans),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'SUBSCRIBE - ₹${plans[_selectedPlanIndex].amountInRupees.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
              ),
              const SizedBox(height: 24),
              Text(
                'Recurring billing. Cancel anytime.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSubLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 24),
            ],
          ),
        ),
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

    // Build decoration based on whether it is selected or Yearly (best value)
    BoxDecoration cardDecoration;
    if (isSelected) {
      cardDecoration = BoxDecoration(
        color: colorScheme.primary.withOpacity(0.08),
        border: Border.all(
          color: colorScheme.primary,
          width: 2.5,
        ),
        borderRadius: BorderRadius.zero,
      );
    } else if (isYearly) {
      // Highlight the recommended plan even if not selected
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: cardDecoration,
        child: Row(
          children: [
            // Custom Radio Indicator
            Container(
              width: 20,
              height: 20,
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
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        plan.name.toUpperCase(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      if (plan.discountLabel != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
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
                              fontSize: 9,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                      if (isYearly) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
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
                              fontSize: 9,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plan.durationDisplay.toUpperCase(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSubLight,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '₹${plan.amountInRupees.toStringAsFixed(0)}',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: colorScheme.onSurface,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFeatureItem(context, 'POST UNLIMITED JOBS'),
        _buildFeatureItem(context, 'VIEW ALL APPLICANTS'),
        _buildFeatureItem(context, 'CHAT WITH CANDIDATES'),
        _buildFeatureItem(context, 'REPOST CLOSED JOBS'),
        _buildFeatureItem(context, 'PRIORITY SUPPORT'),
      ],
    );
  }

  Widget _buildFeatureItem(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(
            Icons.check,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 16),
          Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseDetailsSummary(BuildContext context, SubscriptionPlan selectedPlan) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SELECTED PLAN DETAILS',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: colorScheme.primary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${selectedPlan.name.toUpperCase()} (${selectedPlan.durationDisplay.toUpperCase()})',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '₹${selectedPlan.amountInRupees.toStringAsFixed(0)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 1),
          Text(
            'WHAT YOU WILL RECEIVE FOR ₹${selectedPlan.amountInRupees.toStringAsFixed(0)}:',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textSubDark : AppColors.textSubLight,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildDetailBenefitItem(context, 'Full access to post unlimited job vacancies'),
          _buildDetailBenefitItem(context, 'Unlock and view all profiles of applied candidates'),
          _buildDetailBenefitItem(context, 'Message and chat directly with candidates within the app'),
          _buildDetailBenefitItem(context, 'Shortlist, hire, or reject candidate applications'),
          _buildDetailBenefitItem(context, 'Send direct invitations to candidates to apply for your jobs'),
          _buildDetailBenefitItem(context, 'Reopen and repost closed job positions'),
        ],
      ),
    );
  }

  Widget _buildDetailBenefitItem(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            color: theme.colorScheme.primary,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSubscribe(
    BuildContext context,
    WidgetRef ref,
    List<SubscriptionPlan> plans,
  ) async {
    final selectedPlan = plans[_selectedPlanIndex];

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
        if (mounted) {
          setState(() => _isLoading = false);
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message), backgroundColor: Colors.green),
            );
            context.pop(); // Close premium screen
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message), backgroundColor: Colors.red),
            );
          }
        }
      },
    );
  }
}
