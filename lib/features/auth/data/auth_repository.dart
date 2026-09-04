import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recruiter_model.dart';
import '../../company/models/company_model.dart';

final authRepositoryProvider = Provider(
  (ref) => AuthRepository(
    FirebaseAuth.instance,
    FirebaseFirestore.instance,
    FirebaseFunctions.instanceFor(region: 'us-central1'),
  ),
);

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  AuthRepository(
    this._auth,
    this._firestore, [
    FirebaseFunctions? functions,
  ]) : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  Stream<User?> get authStateChanges => _auth.userChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signUpWithEmailAndPassword(
    String email,
    String password,
  ) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    await _checkUserRole(userCredential.user!);
    return userCredential;
  }

  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    final userCredential = await _auth.signInWithCredential(credential);
    await _checkUserRole(userCredential.user!);
    return userCredential;
  }

  Future<void> _checkUserRole(User user) async {
    // Check user role
    final userDoc = await _firestore.collection('users').doc(user.uid).get();

    if (userDoc.exists) {
      final role = userDoc.data()?['role'];
      if (role != 'recruiter') {
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'wrong-role',
          message: 'User is invalid in this application',
        );
      }
    } else {
      // Fallback: Check if it's a legacy candidate
      final candidateDoc = await _firestore
          .collection('candidates')
          .doc(user.uid)
          .get();
      if (candidateDoc.exists) {
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'wrong-role',
          message: 'User is invalid in this application',
        );
      }
    }
  }

  Future<void> sendEmailVerification() async {
    if (_auth.currentUser != null) {
      await _auth.currentUser!.sendEmailVerification();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required PhoneVerificationCompleted verificationCompleted,
    required PhoneVerificationFailed verificationFailed,
    required PhoneCodeSent codeSent,
    required PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  Future<void> reauthenticateWithEmailPassword(
    String email,
    String password,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No user is currently signed in.',
      );
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  Future<void> reauthenticateWithPhoneCredential(
    PhoneAuthCredential credential,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No user is currently signed in.',
      );
    }
    await user.reauthenticateWithCredential(credential);
  }

  Future<void> deleteAccountViaCloudFunction() async {
    final callable = _functions.httpsCallable('deleteUserAccount');
    final result = await callable.call();
    final data = result.data;
    if (data is Map && data['success'] == false) {
      throw Exception(data['message'] ?? 'Failed to delete account.');
    }
  }

  Future<void> createRecruiterProfile(RecruiterModel recruiter) async {
    await _firestore
        .collection('recruiters')
        .doc(recruiter.uid)
        .set(recruiter.toMap());
  }

  Future<void> createCompanyAndRecruiter({
    required CompanyModel company,
    required RecruiterModel recruiter,
  }) async {
    final batch = _firestore.batch();

    // Create Company Doc
    final companyRef = _firestore.collection('companies').doc(company.id);
    batch.set(companyRef, company.toMap());

    // Create User Role Doc
    final userRef = _firestore.collection('users').doc(recruiter.uid);
    batch.set(userRef, {'role': 'recruiter', 'email': recruiter.officialEmail});

    // Create Recruiter Doc
    final recruiterRef = _firestore.collection('recruiters').doc(recruiter.uid);
    batch.set(recruiterRef, recruiter.toMap());

    await batch.commit();
  }

  Future<RecruiterModel?> getRecruiterProfile(String uid) async {
    final doc = await _firestore.collection('recruiters').doc(uid).get();
    if (doc.exists) {
      return RecruiterModel.fromMap(doc.data()!);
    }
    return null;
  }

  Future<CompanyModel?> getCompany(String companyId) async {
    final doc = await _firestore.collection('companies').doc(companyId).get();
    if (doc.exists) {
      return CompanyModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  Future<void> updateRecruiterProfile(
    String uid,
    Map<String, dynamic> data,
  ) async {
    await _firestore.collection('recruiters').doc(uid).update(data);
  }

  Future<void> updateCompany(
    String companyId,
    Map<String, dynamic> data,
  ) async {
    await _firestore.collection('companies').doc(companyId).update(data);
  }

  Future<void> deleteUserData(String uid, String? companyId) async {
    final batch = _firestore.batch();

    // Delete User Role Doc
    final userRef = _firestore.collection('users').doc(uid);
    batch.delete(userRef);

    // Delete Recruiter Doc
    final recruiterRef = _firestore.collection('recruiters').doc(uid);
    batch.delete(recruiterRef);

    // Delete Company Doc
    if (companyId != null) {
      final companyRef = _firestore.collection('companies').doc(companyId);
      batch.delete(companyRef);
    }

    await batch.commit();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}

