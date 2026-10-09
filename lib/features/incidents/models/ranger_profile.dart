// The two account roles used to choose the app's screens.
enum RangerRole { ranger, manager }

/// Holds the account details needed by manager and ranger screens.
class RangerProfile {
  const RangerProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.active,
  });

  final String uid;
  final String email;
  final String displayName;
  final RangerRole role;
  final bool active;

  // Convert a Firestore user document into a simple app model.
  factory RangerProfile.fromMap(String uid, Map<String, dynamic> data) {
    final roleName = data['role']?.toString();
    final role = RangerRole.values.firstWhere(
      (value) => value.name == roleName,
      orElse: () => RangerRole.ranger,
    );
    return RangerProfile(
      uid: uid,
      email: data['email']?.toString() ?? '',
      displayName: data['displayName']?.toString() ?? '',
      role: role,
      active: data['active'] != false,
    );
  }
}
