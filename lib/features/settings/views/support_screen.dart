import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../theme/app_colors.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'SUPPORT',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),

              // 1. Header Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border.all(color: AppColors.borderLight),
                  borderRadius: BorderRadius.zero,
                ),
                child: Icon(
                  Icons.support_agent_outlined,
                  size: 64,
                  color: colorScheme.primary,
                ),
              ),

              const SizedBox(height: 32),

              // 2. Title
              Text(
                "WE'RE HERE TO HELP",
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // 3. Description
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Have questions, feedback, or need assistance?\nReach out to our support team.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                    color: AppColors.textSubLight,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 48),

              // 4. Contact Options
              _buildContactItem(
                context,
                icon: Icons.email_outlined,
                label: 'EMAIL US',
                value: 'support@talentbay.com',
                onTap: () async {
                  final Uri emailUri = Uri(
                    scheme: 'mailto',
                    path: 'support@talentbay.com',
                    queryParameters: {'subject': 'TalentBay Recruiter Support Request'},
                  );
                  try {
                    await launchUrl(emailUri, mode: LaunchMode.externalApplication);
                  } catch (_) {}
                },
              ),
              const SizedBox(height: 32),
              _buildContactItem(
                context,
                icon: Icons.language_outlined,
                label: 'VISIT WEBSITE',
                value: 'www.waqtixllp.com',
                onTap: () async {
                  final Uri webUri = Uri.parse('https://www.waqtixllp.com');
                  try {
                    await launchUrl(webUri, mode: LaunchMode.externalApplication);
                  } catch (_) {}
                },
              ),
              const SizedBox(height: 32),
              _buildContactItem(
                context,
                icon: Icons.policy_outlined,
                label: 'PRIVACY & POLICY',
                value: 'www.waqtixllp.com/privacy-and-policy',
                onTap: () async {
                  final Uri privacyUri = Uri.parse('https://www.waqtixllp.com/privacy-and-policy');
                  try {
                    await launchUrl(privacyUri, mode: LaunchMode.externalApplication);
                  } catch (_) {}
                },
              ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Column(
          children: [
            Icon(icon, size: 28, color: colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: AppColors.textSubLight,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                decoration: onTap != null ? TextDecoration.underline : null,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
