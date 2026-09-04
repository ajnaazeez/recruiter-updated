import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../data/auth_repository.dart';
import '../models/recruiter_model.dart';
import '../../company/models/company_model.dart';
import '../utils/auth_exception_handler.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/services/local_notification_service.dart';
import '../../../core/services/notification_controller.dart';

final authControllerProvider = NotifierProvider<AuthController, bool>(
  AuthController.new,
);

// Stream provider to listen to auth state
final authStateChangeProvider = StreamProvider<User?>((ref) {
  final authController = ref.watch(authControllerProvider.notifier);
  return authController.authStateChanges;
});

final recruiterProfileProvider = FutureProvider.family<RecruiterModel?, String>(
  (ref, uid) {
    return ref.watch(authRepositoryProvider).getRecruiterProfile(uid);
  },
);

class AuthController extends Notifier<bool> {
  late final AuthRepository _authRepository;

  @override
  bool build() {
    _authRepository = ref.watch(authRepositoryProvider);
    return false; // Initial loading state
  }

  Stream<User?> get authStateChanges => _authRepository.authStateChanges;
  User? get currentUser => _authRepository.currentUser;

  Future<bool> doesProfileExist() async {
    final user = _authRepository.currentUser;
    if (user == null) return false;
    try {
      final profile = await _authRepository.getRecruiterProfile(user.uid);
      return profile != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> registerCompanyRecruiter(
    Map<String, dynamic> data,
    BuildContext context,
  ) async {
    state = true;
    try {
      String email;
      String phone;
      String uid;

      // Check current authenticated user
      final currentUser = _authRepository.currentUser;

      if (currentUser != null) {
        // User already exists (SignUp flow or Resume flow)
        uid = currentUser.uid;

        // Try to get email/phone from data, fallback to User, then Profile
        if (data['email'] != null) {
          email = data['email'] as String;
        } else {
          email = currentUser.email ?? '';
          if (email.isEmpty) {
            // Try fetching profile as last resort
            final profile = await _authRepository.getRecruiterProfile(uid);
            email = profile?.officialEmail ?? '';
          }
        }

        if (data['phone'] != null) {
          phone = data['phone'] as String;
        } else {
          phone = currentUser.phoneNumber ?? '';
        }
      } else {
        // New User (One-shot registration) - Requires Password
        email = data['email'] as String;
        phone = data['phone'] as String;
        final password = data['password'] as String;

        final credential = await _authRepository.signUpWithEmailAndPassword(
          email,
          password,
        );
        uid = credential.user!.uid;
      }

      // 2. Generate Company ID
      // We'll let firestore generate it or create a uuid.
      // Ideally separate ID, but for now let's random or Time based or from repository.
      // But we need it for RecruiterModel.
      // We can use a UUID generator, or just use Firestore doc().id logic if we had access.
      // For simplicity, we'll imply the Repository handles the ID generation if we pass null?
      // But our CompanyModel has String? id.
      // Let's generate one simple ID for now.
      final companyId = DateTime.now().millisecondsSinceEpoch.toString();

      // 3. Prepare Company Model
      // 3. Prepare Company Model
      final company = CompanyModel(
        id: companyId,
        profile: CompanyProfile(
          companyName: data['companyName'] ?? '',
          logoUrl: '',
          coverImageUrl: '',
          tagline: '',
          about: data['description'] ?? '',
          industry: data['industry'] ?? '',
          companyType: data['companyType'] ?? 'Private Limited',
          foundedYear: int.tryParse((data['foundedYear'] ?? '').toString()),
          companySize: data['companySize'] ?? '',
          website: '',
        ),
        contact: CompanyContact(
          email: data['email'] ?? email,
          phone: phone,
          addressLine: '',
          city: '',
          state: '',
          country: '',
          postalCode: '',
        ),
        business: CompanyBusiness(
          registrationNumber: '',
          gstOrTaxId: '',
          ownershipType: 'Private',
          operatingHours: 'Mon-Fri, 9AM-6PM',
          remoteFriendly: false,
          hiringRegions: [],
        ),
        verification: CompanyVerification(
          isVerified: false,
          verifiedBy: '',
          documents: [],
          status: 'pending',
        ),
        social: CompanySocial(),
        stats: CompanyStats(),
        settings: CompanySettings(),
        meta: CompanyMeta(
          createdBy: uid,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // 4. Prepare Recruiter Model
      final recruiter = RecruiterModel(
        uid: uid,
        companyId: companyId,
        fullName: data['fullName'] ?? '',
        designation: data['designation'] ?? '',
        officialEmail: email,
        phoneNumber: phone,
        emailVerified: false,
        phoneVerified: true, // We did mock verification
        createdAt: DateTime.now(),
      );

      // 5. Save to Firestore
      await _authRepository.createCompanyAndRecruiter(
        company: company,
        recruiter: recruiter,
      );

      // 6. Navigation
      if (context.mounted) {
        context.go('/dashboard');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AuthExceptionHandler.generateErrorMessage(e))),
        );
      }
    } finally {
      state = false;
    }
  }

  Future<User?> signUp(String email, String password, String fullName) async {
    state = true;
    try {
      User? user = _authRepository.currentUser;
      if (user != null) {
        // Link Email to existing Phone User
        final credential = EmailAuthProvider.credential(
          email: email,
          password: password,
        );
        await user.linkWithCredential(credential);
      } else {
        // Create new user (fallback if not logged in via phone)
        final credential = await _authRepository.signUpWithEmailAndPassword(
          email,
          password,
        );
        user = credential.user;
      }

      if (user != null) {
        print('DEBUG: User is not null, updating display name...');
        await user.updateDisplayName(fullName);

        // Send email verification
        print('DEBUG: Sending email verification...');
        try {
          await user.sendEmailVerification();
        } catch (e) {
          print('DEBUG: Failed to send verification email: $e');
        }

        return user;
      } else {
        print('DEBUG: User is NULL after sign up/link.');
        return null;
      }
    } catch (e) {
      // Re-throw to let the UI handle the specific error display using the handler if needed,
      // or we can handle it here.
      // But looking at SignUpScreen, it catches and shows snackbar.
      rethrow;
    } finally {
      state = false;
    }
  }

  Future<void> login(
    String email,
    String password,
    BuildContext context,
  ) async {
    state = true;
    try {
      await _authRepository.signInWithEmailAndPassword(email, password);

      // Save FCM Token
      final user = _authRepository.currentUser;
      if (user != null) {
        try {
          try {
            await FirebaseMessaging.instance.getAPNSToken();
          } catch (_) {}
          final token = await FirebaseMessaging.instance.getToken();
          if (token != null) {
            debugPrint("FCM Token: $token");
            await _authRepository.updateRecruiterProfile(
              user.uid,
              {'fcmToken': token},
            );
          }
        } catch (e) {
          debugPrint("Failed to save FCM Token: $e");
        }
      }
    } catch (e) {
      if (context.mounted) {
        final message = AuthExceptionHandler.generateErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        );
      }
    } finally {
      state = false;
    }
  }

  Future<void> forgotPassword(String email, BuildContext context) async {
    state = true;
    try {
      if (email.isEmpty) {
        throw FirebaseAuthException(
          code: 'invalid-email',
          message: 'Please enter your email address',
        );
      }
      await _authRepository.sendPasswordResetEmail(email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Password reset link sent to your email',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        final message = AuthExceptionHandler.generateErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        );
      }
    } finally {
      state = false;
    }
  }

  Future<void> sendEmailVerification(BuildContext context) async {
    state = true;
    try {
      await _authRepository.sendEmailVerification();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AuthExceptionHandler.generateErrorMessage(e))),
        );
      }
    } finally {
      state = false;
    }
  }

  Future<void> reloadUser() async {
    await _authRepository.currentUser?.reload();
  }

  Future<void> verifyPhoneNumber(
    String phoneNumber,
    BuildContext context, {
    required Function(String, int?) codeSent,
  }) async {
    state = true;
    await _authRepository.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-verification (rare for SMS usually)
        await _authRepository.currentUser?.updatePhoneNumber(credential);
        await updateProfilePhoneVerified(phoneNumber);
        state = false;
      },
      verificationFailed: (FirebaseAuthException e) {
        state = false;
        final message = AuthExceptionHandler.generateErrorMessage(e);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
      codeSent: (String verificationId, int? resendToken) {
        state = false;
        codeSent(verificationId, resendToken);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // Handle timeout
      },
    );
  }

  Future<void> signInWithPhone(
    String verificationId,
    String smsCode,
    BuildContext context,
  ) async {
    state = true;
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      await _authRepository.signInWithCredential(credential);
      // Ensure profile exists or handle new user if needed
      // Ideally check if profile exists, if not prompt registration details
    } catch (e) {
      if (context.mounted) {
        final message = AuthExceptionHandler.generateErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        );
      }
    } finally {
      state = false;
    }
  }

  Future<bool> verifyOTP(
    String verificationId,
    String smsCode,
    String phoneNumber,
    BuildContext context,
  ) async {
    state = true;
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final currentUser = _authRepository.currentUser;
      if (currentUser == null) {
        // Sign In Case
        await _authRepository.signInWithCredential(credential);
        // Check if profile exists, if not maybe set some flag?
        // For now, assuming standard flow
      } else {
        // Link / Update Case (Registration Flow)
        await currentUser.updatePhoneNumber(credential);
        await updateProfilePhoneVerified(phoneNumber);
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        final message = AuthExceptionHandler.generateErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        );
      }
      return false;
    } finally {
      state = false;
    }
  }

  Future<void> updateProfilePhoneVerified(String phoneNumber) async {
    final user = _authRepository.currentUser;
    if (user != null) {
      await _authRepository.updateRecruiterProfile(user.uid, {
        'phoneNumber': phoneNumber,
        'phoneVerified': true,
      });
    }
  }

  Future<void> createCompany(String companyName, BuildContext context) async {
    state = true;
    try {
      final user = _authRepository.currentUser;
      if (user == null) return;

      await _authRepository.updateRecruiterProfile(user.uid, {
        'companyCreated': true,
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      state = false;
    }
  }

  Future<void> logout() async {
    await _authRepository.signOut();
  }

  Future<RecruiterModel?> getRecruiterProfile(String uid) {
    return _authRepository.getRecruiterProfile(uid);
  }

  Future<void> deleteAccount(BuildContext context) async {
    if (state) return; // Prevent duplicate deletion requests
    final user = _authRepository.currentUser;
    if (user == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active user session found.')),
        );
      }
      return;
    }

    state = true;
    showAccountDeletionLoadingDialog(context);

    try {
      await _executeAccountDeletion(context, user);
    } catch (e) {
      if (context.mounted) {
        // Dismiss loading dialog if still visible
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}

        final errorMessage = AuthExceptionHandler.generateErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        );
      }
    } finally {
      state = false;
    }
  }

  Future<void> _executeAccountDeletion(BuildContext context, User user) async {
    try {
      await _authRepository.deleteAccountViaCloudFunction();
      await _finishSuccessfulDeletion(context, user);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login' ||
          e.code == 'user-token-expired' ||
          e.code == 'unauthenticated') {
        await _handleReauthenticationAndRetry(context, user);
      } else {
        rethrow;
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('requires-recent-login') ||
          msg.contains('unauthenticated') ||
          msg.contains('recent-login')) {
        await _handleReauthenticationAndRetry(context, user);
      } else {
        rethrow;
      }
    }
  }

  Future<void> _handleReauthenticationAndRetry(
    BuildContext context,
    User user,
  ) async {
    if (!context.mounted) return;

    // Pop the loading dialog first to allow user interaction
    try {
      Navigator.of(context, rootNavigator: true).pop();
    } catch (_) {}

    final email = user.email;
    final phoneNumber = user.phoneNumber;

    if (email != null && email.isNotEmpty) {
      final password = await showReauthenticatePasswordDialog(
        context,
        email: email,
      );
      if (password != null && password.isNotEmpty && context.mounted) {
        showAccountDeletionLoadingDialog(context);
        await _authRepository.reauthenticateWithEmailPassword(email, password);
        await _authRepository.deleteAccountViaCloudFunction();
        await _finishSuccessfulDeletion(context, user);
      }
    } else if (phoneNumber != null && phoneNumber.isNotEmpty) {
      String? verificationId;
      await _authRepository.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _authRepository.reauthenticateWithPhoneCredential(credential);
        },
        verificationFailed: (e) {
          throw e;
        },
        codeSent: (vId, token) {
          verificationId = vId;
        },
        codeAutoRetrievalTimeout: (vId) {
          verificationId = vId;
        },
      );

      if (context.mounted) {
        final otp = await showReauthenticatePhoneDialog(
          context,
          phoneNumber: phoneNumber,
        );
        if (otp != null &&
            otp.length == 6 &&
            verificationId != null &&
            context.mounted) {
          showAccountDeletionLoadingDialog(context);
          final cred = PhoneAuthProvider.credential(
            verificationId: verificationId!,
            smsCode: otp,
          );
          await _authRepository.reauthenticateWithPhoneCredential(cred);
          await _authRepository.deleteAccountViaCloudFunction();
          await _finishSuccessfulDeletion(context, user);
        }
      }
    } else {
      throw Exception(
        'Session expired. Please log in again to delete your account.',
      );
    }
  }

  Future<void> _finishSuccessfulDeletion(BuildContext context, User user) async {
    // 1. Cancel local notifications
    try {
      await LocalNotificationService.cancelAll();
    } catch (_) {}

    // 2. Clear user-specific shared preferences
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.remove('notifications_enabled');
    } catch (_) {}

    // 3. Invalidate profile provider
    ref.invalidate(recruiterProfileProvider(user.uid));

    // 4. Sign out locally
    await _authRepository.signOut();

    if (context.mounted) {
      try {
        Navigator.of(context, rootNavigator: true).pop();
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your account has been permanently deleted.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      );
    }
  }
}

