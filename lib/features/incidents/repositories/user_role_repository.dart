// Loads account roles from Firestore and creates new ranger profiles.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/ranger_profile.dart';

/// Loads a trusted role profile. New accounts are always created as rangers;
/// manager roles must be provisioned by a project administrator.
/// Keeps user role data access out of the role-routing screen.
class UserRoleRepository {
  UserRoleRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // Load the saved profile, or create a safe default ranger profile.
  Future<RangerProfile> loadOrCreateRangerProfile(User user) async {
    final reference = _firestore.collection('users').doc(user.uid);
    final existing = await reference.get();
    if (existing.exists) {
      final profile = RangerProfile.fromMap(user.uid, existing.data()!);
      if (!profile.active) {
        throw StateError(
          'This RangerNet account is inactive. Contact a manager.',
        );
      }
      return profile;
    }

    final name = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : (user.email?.split('@').first ?? 'Ranger');
    await reference.set({
      'uid': user.uid,
      'email': user.email ?? '',
      'displayName': name,
      'role': RangerRole.ranger.name,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return RangerProfile(
      uid: user.uid,
      email: user.email ?? '',
      displayName: name,
      role: RangerRole.ranger,
      active: true,
    );
  }
}
