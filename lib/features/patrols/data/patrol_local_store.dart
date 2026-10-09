import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/patrol.dart';
import 'patrol_codec.dart';

/// Persists each ranger patrol queue as versioned JSON in SharedPreferences. This is the offline-first local store; serialization is delegated to PatrolCodec.
class PatrolLocalStore {
  /// Creates the store; writeValue can replace the platform write for tests.
  PatrolLocalStore({this.writeValue});

  /// Optional injectable writer used to test persistence outcomes.
  final Future<bool> Function(String key, String value)? writeValue;

  /// Loads and decodes the local patrol queue belonging to rangerId.
  Future<List<Patrol>> loadForRanger(String rangerId) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_key(rangerId));
    if (encoded == null || encoded.isEmpty) return const [];
    final decoded = jsonDecode(encoded);
    if (decoded is! List) {
      throw const FormatException('Saved patrol data must be a list.');
    }
    return decoded
        .map(
          (item) => PatrolCodec.decode(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
  }

  /// Replaces a ranger queue after validating ownership and unique local IDs.
  Future<void> replaceForRanger(String rangerId, List<Patrol> patrols) async {
    if (patrols.any((patrol) => patrol.rangerId != rangerId)) {
      throw ArgumentError(
        'Cannot store another ranger\'s patrol in this queue.',
      );
    }
    final localIds = patrols.map((patrol) => patrol.localId).toSet();
    if (localIds.length != patrols.length) {
      throw ArgumentError('Patrol local IDs must be unique.');
    }
    final key = _key(rangerId);
    final encoded = jsonEncode(patrols.map(PatrolCodec.encode).toList());
    final writer = writeValue;
    final saved = writer == null
        ? await (await SharedPreferences.getInstance()).setString(key, encoded)
        : await writer(key, encoded);
    if (!saved) {
      throw StateError('Patrol data could not be saved on this device.');
    }
  }

  /// Builds a versioned key so a future storage schema can use a separate key.
  String _key(String rangerId) => 'patrol_records_v1_$rangerId';
}
