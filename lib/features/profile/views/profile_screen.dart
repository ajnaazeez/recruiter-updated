import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recruiter_talentbay/features/auth/controllers/auth_controller.dart';
import 'package:recruiter_talentbay/features/auth/data/auth_repository.dart';
import 'package:recruiter_talentbay/features/company/models/company_model.dart';
import 'package:recruiter_talentbay/features/auth/models/recruiter_model.dart';
import 'package:go_router/go_router.dart';

import 'package:csc_picker_plus/csc_picker_plus.dart';
import '../../../../core/utils/country_codes.dart';
import 'package:recruiter_talentbay/theme/app_colors.dart';
import 'package:recruiter_talentbay/core/widgets/app_dialogs.dart';

final companyProfileProvider = FutureProvider.family<CompanyModel?, String>((
  ref,
  companyId,
) {
  return ref.watch(authRepositoryProvider).getCompany(companyId);
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for Company
  late TextEditingController _nameController;
  late TextEditingController _industryController;
  late TextEditingController _sizeController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _websiteController;

  // Controllers for Recruiter
  late TextEditingController _recruiterNameController;
  late TextEditingController _recruiterDesignationController;
  late TextEditingController _recruiterEmailController;
  late TextEditingController _recruiterPhoneController;

  bool _isEditing = false;
  String? _companyId;
  String? _recruiterId;
  String? _originalPhone;

  // Country Codes
  String _recruiterCountryCode = '+91';
  String _companyCountryCode = '+91';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _industryController = TextEditingController();
    _sizeController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _websiteController = TextEditingController();

    _recruiterNameController = TextEditingController();
    _recruiterDesignationController = TextEditingController();
    _recruiterEmailController = TextEditingController();
    _recruiterPhoneController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _industryController.dispose();
    _sizeController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();

    _recruiterNameController.dispose();
    _recruiterDesignationController.dispose();
    _recruiterEmailController.dispose();
    _recruiterPhoneController.dispose();
    super.dispose();
  }

  void _splitPhoneNumber(String fullPhone, Function(String, String) onSplit) {
    if (fullPhone.isEmpty) {
      onSplit('+91', '');
      return;
    }

    // Sort country codes by length (descending) to match longest prefix first
    final sortedCodes = CountryCodes.countryCodeMap.values.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final code in sortedCodes) {
      if (fullPhone.startsWith(code)) {
        onSplit(code, fullPhone.substring(code.length));
        return;
      }
    }

    // Fallback if no code matches (assume default or custom)
    // Here we'll just assume +91 if it starts with +, otherwise keep as is
    if (fullPhone.startsWith('+')) {
      // Try to guess 2 or 3 digits
      // But safe fallback is just treat everything as number if we can't match
      onSplit('+91', fullPhone);
    } else {
      onSplit('+91', fullPhone);
    }
  }

  void _initializeControllers(CompanyModel company, RecruiterModel recruiter) {
    if (!_isEditing) {
      if (_companyId != company.id || _recruiterId != recruiter.uid) {
        _companyId = company.id;
        _recruiterId = recruiter.uid;

        // Company
        _nameController.text = company.profile.companyName;
        _industryController.text = company.profile.industry;
        _sizeController.text = company.profile.companySize;
        _emailController.text = company.contact.email;
        _splitPhoneNumber(company.contact.phone, (code, number) {
          _companyCountryCode = code;
          _phoneController.text = number;
        });
        _websiteController.text = company.profile.website;

        // Recruiter
        _recruiterNameController.text = recruiter.fullName;
        _recruiterDesignationController.text = recruiter.designation;
        _recruiterEmailController.text = recruiter.officialEmail;
        _splitPhoneNumber(recruiter.phoneNumber, (code, number) {
          _recruiterCountryCode = code;
          _recruiterPhoneController.text = number;
        });
        _originalPhone = recruiter.phoneNumber;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider.notifier).currentUser;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('User not logged in')));
    }

    final recruiterAsync = ref.watch(recruiterProfileProvider(user.uid));

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: Text(
          'MY PROFILE',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: colorScheme.background,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit_outlined),
            color: colorScheme.onSurface,
            onPressed: () {
              if (_isEditing) {
                _saveProfile();
              } else {
                setState(() => _isEditing = true);
              }
            },
          ),
        ],
      ),
      body: recruiterAsync.when(
        data: (recruiter) {
          if (recruiter == null) {
            return const Center(child: Text('Recruiter profile not found'));
          }

          final companyAsync = ref.watch(
            companyProfileProvider(recruiter.companyId),
          );

          return companyAsync.when(
            data: (company) {
              if (company == null) {
                return const Center(child: Text('Company profile not found'));
              }
              _initializeControllers(company, recruiter);

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Column(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              border: Border.all(color: AppColors.borderLight),
                              borderRadius: BorderRadius.zero, // Sharp corners
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Center(
                              child: Text(
                                company.profile.companyName.isNotEmpty
                                    ? company.profile.companyName[0]
                                          .toUpperCase()
                                    : 'C',
                                style: theme.textTheme.displayMedium,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            company.profile.companyName.toUpperCase(),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "${recruiter.fullName} • ${recruiter.designation}",
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSubLight,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (recruiter.isSubscribed) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'PRO',
                                    style: TextStyle(
                                      color: colorScheme.onPrimary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),
                      const Divider(),
                      const SizedBox(height: 24),

                      // --- Recruiter Info ---
                      _buildSectionTitle(context, 'RECRUITER INFORMATION'),
                      const SizedBox(height: 16),
                      _buildTextField(
                        context,
                        controller: _recruiterNameController,
                        label: 'Full Name',
                        icon: Icons.person_outline,
                        enabled: _isEditing,
                      ),
                      _buildTextField(
                        context,
                        controller: _recruiterDesignationController,
                        label: 'Designation',
                        icon: Icons.work_outline,
                        enabled: _isEditing,
                      ),
                      _buildTextField(
                        context,
                        controller: _recruiterEmailController,
                        label: 'Email',
                        icon: Icons.email_outlined,
                        enabled: false,
                      ),
                      _buildPhoneField(
                        context,
                        controller: _recruiterPhoneController,
                        label: 'Phone',
                        countryCode: _recruiterCountryCode,
                        onCountryChanged: (code) {
                          setState(() => _recruiterCountryCode = code);
                        },
                        enabled: _isEditing,
                      ),

                      const SizedBox(height: 32),

                      // --- Company Info ---
                      _buildSectionTitle(context, 'COMPANY INFORMATION'),
                      const SizedBox(height: 16),
                      _buildTextField(
                        context,
                        controller: _nameController,
                        label: 'Company Name',
                        icon: Icons.business_outlined,
                        enabled: _isEditing,
                      ),
                      _buildTextField(
                        context,
                        controller: _industryController,
                        label: 'Industry',
                        icon: Icons.category_outlined,
                        enabled: _isEditing,
                      ),
                      _buildTextField(
                        context,
                        controller: _sizeController,
                        label: 'Company Size',
                        icon: Icons.groups_outlined,
                        enabled: _isEditing,
                      ),
                      _buildTextField(
                        context,
                        controller: _emailController,
                        label: 'Official Email',
                        icon: Icons.email_outlined,
                        enabled: _isEditing,
                      ),
                      _buildPhoneField(
                        context,
                        controller: _phoneController,
                        label: 'Official Phone',
                        countryCode: _companyCountryCode,
                        onCountryChanged: (code) {
                          setState(() => _companyCountryCode = code);
                        },
                        enabled: _isEditing,
                      ),
                      _buildTextField(
                        context,
                        controller: _websiteController,
                        label: 'Website',
                        icon: Icons.language_outlined,
                        enabled: _isEditing,
                      ),

                      const SizedBox(height: 40),

                      // Danger Zone
                      const Divider(),
                      const SizedBox(height: 24),
                      _buildSectionTitle(
                        context,
                        'DANGER ZONE',
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Once you delete your account, there is no going back. Please be certain.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSubLight,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final confirm =
                              await showDeleteAccountConfirmationDialog(context);

                          if (confirm == true && context.mounted) {
                            ref
                                .read(authControllerProvider.notifier)
                                .deleteAccount(context);
                          }
                        },
                        icon: const Icon(
                          Icons.delete_forever_outlined,
                          size: 20,
                        ),
                        label: const Text('DELETE ACCOUNT'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error loading company: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error loading recruiter: $e')),
      ),
    );
  }

  Widget _buildSectionTitle(
    BuildContext context,
    String title, {
    Color? color,
  }) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: 1.0,
        color: color,
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool enabled,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: theme.textTheme.bodySmall,
          floatingLabelStyle: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          prefixIcon: Icon(icon, size: 20, color: AppColors.textSubLight),
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: AppColors.borderLight),
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: AppColors.borderLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(
              color: theme.colorScheme.primary,
              width: 1.5,
            ),
          ),
          disabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: AppColors.borderLight, width: 0.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildPhoneField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required String countryCode,
    required Function(String) onCountryChanged,
    required bool enabled,
  }) {
    final theme = Theme.of(context);

    // Attempt to map countryCode to CscCountry enum for initial value
    CscCountry defaultParam = CscCountry.India;
    final countryName = CountryCodes.getCountryFromDialCode(countryCode);

    if (countryName != null) {
      // Create a map or iterate values to find match
      // This is a bit expensive but done only on build properties, assuming not too frequent
      // Or we can just try to match name.
      try {
        defaultParam = CscCountry.values.firstWhere(
          (e) =>
              e.toString().split('.').last.replaceAll('_', ' ') == countryName,
          orElse: () => CscCountry.India,
        );
      } catch (e) {
        // Fallback
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty) ...[
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textSubLight,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(
                color: enabled
                    ? AppColors.borderLight
                    : AppColors.borderLight.withOpacity(0.5),
              ),
              borderRadius: BorderRadius.zero,
            ),
            child: Row(
              children: [
                if (enabled)
                  SizedBox(
                    width: 110,
                    child: CSCPickerPlus(
                      onCountryChanged: (value) {
                        final code =
                            CountryCodes.countryCodeMap[value] ?? '+91';
                        onCountryChanged(code);
                      },
                      onStateChanged: (value) {},
                      onCityChanged: (value) {},
                      flagState: CountryFlag.SHOW_IN_DROP_DOWN_ONLY,
                      dropdownDecoration: const BoxDecoration(
                        color: Colors.transparent,
                      ),
                      disabledDropdownDecoration: const BoxDecoration(
                        color: Colors.transparent,
                      ),
                      selectedItemStyle: theme.textTheme.bodyMedium!.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      dropdownHeadingStyle: theme.textTheme.titleSmall!
                          .copyWith(fontWeight: FontWeight.bold),
                      dropdownItemStyle: theme.textTheme.bodyMedium!,
                      searchBarRadius: 0,
                      defaultCountry: defaultParam,
                      showStates: false,
                      showCities: false,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    child: Text(
                      countryCode, // Show just the code if disabled
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSubLight,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                const SizedBox(width: 8),
                Container(width: 1, height: 24, color: AppColors.borderLight),
                const SizedBox(width: 12),

                Expanded(
                  child: TextFormField(
                    controller: controller,
                    enabled: enabled,
                    keyboardType: TextInputType.phone,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      // We don't need prefixText here if we have the picker or text showing it
                      // But for editing, the picker is separate.
                      // For disabled state, we showed code in Text widget above.
                      // Let's keep it consistent.
                      hintText: '9876543210',
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSubLight.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      // 1. Check for Phone Change (Recruiter)
      final newPhoneNumber = _recruiterPhoneController.text.trim();
      final fullNewPhone = '$_recruiterCountryCode$newPhoneNumber';

      print('DEBUG: Original Phone: $_originalPhone');
      print('DEBUG: New Phone: $fullNewPhone');

      final phoneChanged = fullNewPhone != _originalPhone;
      print('DEBUG: Phone Changed: $phoneChanged');

      // 2. Prepare Updates
      final recruiterUpdates = {
        'fullName': _recruiterNameController.text.trim(),
        'designation': _recruiterDesignationController.text.trim(),
        // Don't update phone here if changed, wait for verification
      };
      if (!phoneChanged) {
        // If not changed, ensure we send the full phone just in case, or don't send if not needed.
        // But if we split it, we should reconstruct it if the API expects full phone.
        // If the user didn't change anything, the parts should combine to original.
        recruiterUpdates['phoneNumber'] = fullNewPhone;
      }

      final companyUpdates = {
        'profile.companyName': _nameController.text.trim(),
        'profile.industry': _industryController.text.trim(),
        'profile.companySize': _sizeController.text.trim(),
        'contact.email': _emailController.text.trim(),
        'contact.phone':
            '$_companyCountryCode${_phoneController.text.trim()}', // Combine for company
        'profile.website': _websiteController.text.trim(),
      };

      // 3. Perform Updates
      if (_recruiterId != null) {
        await ref
            .read(authRepositoryProvider)
            .updateRecruiterProfile(_recruiterId!, recruiterUpdates);
      }
      if (_companyId != null) {
        await ref
            .read(authRepositoryProvider)
            .updateCompany(_companyId!, companyUpdates);
      }

      // 4. Handle Phone Change Flow
      if (phoneChanged) {
        if (mounted) {
          setState(() => _isEditing = false);
          // Pass the full new phone number for verification
          context.push('/update-phone-verification', extra: fullNewPhone);
        }
      } else {
        if (mounted) {
          setState(() => _isEditing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
          // Refresh data
          ref.invalidate(recruiterProfileProvider);
          if (_companyId != null) {
            ref.invalidate(companyProfileProvider(_companyId!));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
      }
    }
  }
}
