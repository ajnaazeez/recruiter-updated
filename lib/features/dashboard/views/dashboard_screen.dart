import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:recruiter_talentbay/features/auth/controllers/auth_controller.dart';
import 'package:recruiter_talentbay/features/dashboard/views/home_tab_view.dart';
import 'package:recruiter_talentbay/features/jobs/views/jobs_tab_view.dart';

import 'package:recruiter_talentbay/features/chat/views/chat_list_screen.dart';
import 'package:recruiter_talentbay/features/settings/views/settings_screen.dart';
import 'package:recruiter_talentbay/features/settings/views/about_screen.dart';
import 'package:recruiter_talentbay/features/settings/views/support_screen.dart';
import 'package:recruiter_talentbay/features/jobs/views/closed_jobs_screen.dart';
import 'package:recruiter_talentbay/core/widgets/app_dialogs.dart';
import '../../../theme/app_colors.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentIndex = 0;
  bool _hasShownTrialOffer = false;

  final List<Widget> _tabs = [
    const HomeTabView(),
    const JobsTabView(),
    const ChatListScreen(),
    const SettingsScreen(),
  ];

  final List<String> _titles = ['HOME', 'JOBS', 'CHAT', 'SETTINGS'];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider.notifier).currentUser;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS || Platform.isIOS;

    ref.listen(
      recruiterProfileProvider(user?.uid ?? ''),
      (previous, next) {
        if (!_hasShownTrialOffer && next.hasValue && next.value != null) {
          final profile = next.value!;
          if (!isIOS && profile.subscriptionPlanId == null) {
            _hasShownTrialOffer = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _showTrialOfferBottomSheet(context);
              }
            });
          } else {
            _hasShownTrialOffer = true;
          }
        }
      },
    );

    final recruiterAsync = ref.watch(recruiterProfileProvider(user?.uid ?? ''));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_currentIndex],
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        backgroundColor: theme.colorScheme.background,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      drawer: Drawer(
        backgroundColor: theme.colorScheme.background,
        child: Column(
          children: [
            // Custom Minimalist Header
            recruiterAsync.when(
              data: (recruiter) {
                if (recruiter == null) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: Text('Guest')),
                  );
                }
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.background,
                    border: Border(
                      bottom: BorderSide(color: theme.dividerColor),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.surface,
                          border: Border.all(color: theme.dividerColor),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Center(
                          child: Text(
                            recruiter.fullName.isNotEmpty
                                ? recruiter.fullName[0].toUpperCase()
                                : 'R',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        recruiter.fullName.toUpperCase(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        recruiter.officialEmail,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        recruiter.designation,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const SizedBox(
                height: 200,
                child: Center(child: Text('Error loading profile')),
              ),
            ),

            // Drawer Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.person_outline,
                    title: 'PROFILE',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/profile');
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.business_outlined,
                    title: 'COMPANY DETAILS',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/company-details');
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.archive_outlined,
                    title: 'CLOSED POSITIONS',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ClosedJobsScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  _buildDrawerItem(
                    context,
                    icon: Icons.support_agent_outlined,
                    title: 'SUPPORT',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SupportScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.info_outline,
                    title: 'ABOUT',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AboutScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Bottom Actions
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.logout,
                    title: 'LOGOUT',
                    color: AppColors.error,
                    onTap: () async {
                      Navigator.pop(context);
                      final shouldLogout = await showLogoutDialog(context);
                      if (shouldLogout) {
                        ref.read(authControllerProvider.notifier).logout();
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: theme.dividerColor, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: theme.colorScheme.onSurfaceVariant,
          selectedLabelStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          showUnselectedLabels: true,
          showSelectedLabels: true,
          items: const [
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.grid_view, size: 22),
              ),
              label: 'HOME',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.cases_outlined, size: 22),
              ),
              label: 'JOBS',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.chat_bubble_outline, size: 22),
              ),
              label: 'CHAT',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.settings_outlined, size: 22),
              ),
              label: 'SETTINGS',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.onSurface;

    return ListTile(
      leading: Icon(icon, color: effectiveColor, size: 22),
      title: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: effectiveColor,
          letterSpacing: 0.5,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      minLeadingWidth: 24,
    );
  }

  void _showTrialOfferBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Draggable handle
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 32),
              
              Icon(Icons.stars_rounded, size: 80, color: colorScheme.primary),
              const SizedBox(height: 24),
              
              Text(
                'EXCLUSIVE OFFER',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              Text(
                '60 Days Premium',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(text: 'Unlock all premium features worth '),
                    TextSpan(
                      text: '₹2,998',
                      style: TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                      ),
                    ),
                    const TextSpan(text: ' for just '),
                    TextSpan(
                      text: '₹1 ',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    const TextSpan(text: 'today!'),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    elevation: 0,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context); // close bottom sheet
                    context.push('/subscription');
                  },
                  child: const Text(
                    'CLAIM ₹1 OFFER',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                ),
                child: const Text(
                  'Maybe Later',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        );
      },
    );
  }
}
