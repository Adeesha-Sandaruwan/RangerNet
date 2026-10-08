import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/patrol.dart';
import 'patrol_codec.dart';

class PatrolLocalStore {
  PatrolLocalStore({this.writeValue});

  final Future<bool> Function(String key, String value)? writeValue;

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

  String _key(String rangerId) => 'patrol_records_v1_$rangerId';
}
