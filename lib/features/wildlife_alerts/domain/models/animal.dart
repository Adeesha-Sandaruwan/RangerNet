enum AnimalRiskProfile {
  high('High Risk / Critically Endangered', 3),
  medium('Medium Risk / Vulnerable', 2),
  low('Low Risk / Least Concern', 1);

  const AnimalRiskProfile(this.label, this.priorityWeight);
  final String label;
  final int priorityWeight;
}

class Animal {
  const Animal({
    required this.id,
    required this.name,
    required this.species,
    required this.collarId,
    required this.riskProfile,
    this.notes,
  });

  final String id;
  final String name;
  final String species;
  final String collarId;
  final AnimalRiskProfile riskProfile;
  final String? notes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'species': species,
    'collarId': collarId,
    'riskProfile': riskProfile.name,
    'notes': notes,
  };

  factory Animal.fromJson(Map<String, dynamic> json) => Animal(
    id: json['id'] as String,
    name: json['name'] as String,
    species: json['species'] as String,
    collarId: json['collarId'] as String,
    riskProfile: AnimalRiskProfile.values.byName(
      json['riskProfile'] as String? ?? 'medium',
    ),
    notes: json['notes'] as String?,
  );

  @override
  String toString() => 'Animal($name, $species, collar: $collarId)';
}
