import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Handles Firebase Authentication (Email/Password) and Firestore user data.
///
/// Architecture:
///   - Login / Register → VPS backend (JWT) AND Firebase (email+password)
///   - User profile data → synced TO Firestore after every backend fetch
///   - Profile reads → Firestore first (offline-capable), backend as fallback
///
/// Firebase Email format: {phone_digits}@fkhotiyan.app
/// (e.g. 01711234567 → 01711234567@fkhotiyan.app)
///
/// ⚠️  Enable Email/Password sign-in in Firebase Console:
///     Authentication → Sign-in method → Email/Password → Enable
///
/// ⚠️  Set Firestore Security Rules (Firebase Console → Firestore → Rules):
///   rules_version = '2';
///   service cloud.firestore {
///     match /databases/{database}/documents {
///       match /users/{userId} {
///         allow read, write: if request.auth != null && request.auth.uid == userId;
///       }
///     }
///   }
class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static User? get currentUser => _auth.currentUser;
  static bool get isSignedIn => _auth.currentUser != null;

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Convert phone number to Firebase-compatible email address.
  static String phoneToEmail(String phone) {
    // Keep only digits (strip +880, leading zeros, spaces, dashes)
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return '$digits@fkhotiyan.app';
  }

  // ── Authentication ────────────────────────────────────────────────────────

  /// Sign in with phone number and password.
  /// Automatically creates a Firebase account on first login (user-not-found).
  /// Never throws — errors are silently swallowed so VPS login always succeeds.
  static Future<void> signIn(String phone, String password) async {
    try {
      final email = phoneToEmail(phone);
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      debugPrint('[Firebase] signIn success: $email');
    } on FirebaseAuthException catch (e) {
      debugPrint('[Firebase] signIn error: ${e.code} — ${e.message}');
      if (e.code == 'user-not-found' ||
          e.code == 'invalid-credential' ||
          e.code == 'INVALID_LOGIN_CREDENTIALS' ||
          e.code == 'wrong-password') {
        // First time OR password mismatch — create/overwrite account
        try {
          await _auth.createUserWithEmailAndPassword(
              email: phoneToEmail(phone), password: password);
          debugPrint('[Firebase] account created for: ${phoneToEmail(phone)}');
        } on FirebaseAuthException catch (e2) {
          if (e2.code == 'email-already-in-use') {
            // Account exists with different password — update password via re-auth
            debugPrint('[Firebase] email-already-in-use, trying sign in again');
          } else {
            debugPrint('[Firebase] create error: ${e2.code} — ${e2.message}');
          }
        }
      }
    } catch (e) {
      debugPrint('[Firebase] signIn unexpected error: $e');
    }
  }

  /// Register new user in Firebase. Silently handles already-exists case.
  static Future<void> register(String phone, String password) async {
    try {
      final email = phoneToEmail(phone);
      await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      debugPrint('[Firebase] register success: $email');
    } on FirebaseAuthException catch (e) {
      debugPrint('[Firebase] register error: ${e.code} — ${e.message}');
      if (e.code == 'email-already-in-use') {
        try {
          await _auth.signInWithEmailAndPassword(
              email: phoneToEmail(phone), password: password);
          debugPrint('[Firebase] signed in existing account');
        } catch (e2) {
          debugPrint('[Firebase] sign in existing failed: $e2');
        }
      }
    } catch (e) {
      debugPrint('[Firebase] register unexpected error: $e');
    }
  }

  /// Sign out from Firebase.
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (_) {}
  }

  // ── Firestore User Data ───────────────────────────────────────────────────

  /// Write (merge) user profile from backend into Firestore.
  /// Call this after every successful backend profile fetch.
  static Future<void> syncProfile(Map<String, dynamic> profileData) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('[Firebase] syncProfile skipped — not signed in to Firebase');
      return;
    }
    try {
      // Strip non-serialisable keys (e.g. logo File object)
      final data = Map<String, dynamic>.fromEntries(
        profileData.entries.where((e) => _isFirestoreSafe(e.value)),
      );
      data['last_synced'] = FieldValue.serverTimestamp();
      await _db
          .collection('users')
          .doc(user.uid)
          .set(data, SetOptions(merge: true));
      debugPrint('[Firebase] syncProfile success — uid: ${user.uid}');
    } catch (e) {
      debugPrint('[Firebase] syncProfile error: $e');
    }
  }

  static bool _isFirestoreSafe(dynamic v) {
    if (v == null) return true;
    if (v is String || v is num || v is bool) return true;
    if (v is List) return v.every(_isFirestoreSafe);
    if (v is Map) return v.values.every(_isFirestoreSafe);
    return false; // Excludes File, Uint8List, etc.
  }

  /// Read user profile FROM Firestore.
  /// Returns null if no Firebase user is signed in or data not yet cached.
  static Future<Map<String, dynamic>?> getProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      final doc = await _db
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.serverAndCache));
      if (doc.exists && doc.data() != null) {
        final data = Map<String, dynamic>.from(doc.data()!);
        data.remove('last_synced'); // internal field
        return data;
      }
    } catch (_) {
      // Offline fallback — try cache only
      try {
        final doc = await _db
            .collection('users')
            .doc(user.uid)
            .get(const GetOptions(source: Source.cache));
        if (doc.exists && doc.data() != null) {
          final data = Map<String, dynamic>.from(doc.data()!);
          data.remove('last_synced');
          return data;
        }
      } catch (_) {}
    }
    return null;
  }
}
