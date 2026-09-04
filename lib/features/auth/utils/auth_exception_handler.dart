import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AuthExceptionHandler {
  static String generateErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'The email address is not valid. Please check and try again.';
        case 'user-disabled':
          return 'This user has been disabled. Please contact support.';
        case 'user-not-found':
          return 'No user found with this email. Please sign up first.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'email-already-in-use':
          return 'This email is already registered. Please log in instead.';
        case 'operation-not-allowed':
          return 'This sign-in method is not enabled. Please contact support.';
        case 'weak-password':
          return 'The password is too weak. Please use a stronger password.';
        case 'invalid-verification-code':
          return 'The verification code is invalid. Please check and try again.';
        case 'invalid-verification-id':
          return 'The verification session has expired. Please request a new code.';
        case 'credential-already-in-use':
          return 'This account is already linked to another user.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection.';
        case 'invalid-credential':
          return 'Invalid credentials. Please check your details and try again.';
        case 'wrong-role':
          return 'User is invalid in this application.';
        case 'requires-recent-login':
          return 'For security, please confirm your credentials before completing this action.';
        case 'user-token-expired':
          return 'Your session has expired. Please log in again.';
        // App Check / Security errors
        case 'invalid-app-credential':
        case 'permission-denied':
        case '403':
          return 'Security check failed. Please ensure you are using the latest app version.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        default:
          return error.message ?? 'An authentication error occurred.';
      }
    } else if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'unauthenticated':
          return 'Please sign in again to complete this action.';
        case 'permission-denied':
          return 'You do not have permission to perform this action.';
        case 'unavailable':
          return 'The service is temporarily unavailable. Please try again.';
        default:
          return error.message ?? 'A server error occurred. Please try again.';
      }
    } else if (error is FirebaseException) {
      if (error.code == 'permission-denied' ||
          error.code == '403' ||
          (error.message?.contains('App attestation failed') ?? false)) {
        return 'Security verification failed. Please try again later.';
      }
      return error.message ?? 'A Firebase service error occurred.';
    } else if (error is Exception) {
      final msg = error.toString().replaceFirst('Exception: ', '');
      return msg;
    } else {
      return error?.toString() ?? 'An unexpected error occurred.';
    }
  }
}

