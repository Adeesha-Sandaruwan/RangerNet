enum RangerRole { ranger, manager }

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
