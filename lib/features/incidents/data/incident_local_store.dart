import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/incident_report.dart';

/// Small offline outbox for the student MVP. Evidence is resized before it is
/// queued, and the UI surfaces storage errors instead of claiming a save.
class IncidentLocalStore {
  static const _maxQueuedReports = 8;

  Future<List<IncidentReport>> loadQueue(String rangerId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey(rangerId));
    if (raw == null || raw.isEmpty) return const [];

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map(
          (item) =>
              IncidentReport.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
  }

  Future<void> enqueue(IncidentReport report) async {
    final reports = (await loadQueue(report.rangerId)).toList();
    final existingIndex = reports.indexWhere((item) => item.id == report.id);
    if (existingIndex >= 0) {
      reports[existingIndex] = report;
    } else {
      if (reports.length >= _maxQueuedReports) {
        throw StateError(
          'The offline incident queue is full. Sync existing reports first.',
        );
      }
      reports.add(report);
    }

    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      _queueKey(report.rangerId),
      jsonEncode(reports.map((item) => item.toJson()).toList()),
    );
    if (!saved)
      throw StateError('The incident could not be saved on this device.');
  }

  Future<void> replace(IncidentReport report) => enqueue(report);

  Future<void> remove(String rangerId, String incidentId) async {
    final reports = (await loadQueue(
      rangerId,
    )).where((item) => item.id != incidentId).toList(growable: false);
    final prefs = await SharedPreferences.getInstance();
    if (reports.isEmpty) {
      await prefs.remove(_queueKey(rangerId));
    } else {
      await prefs.setString(
        _queueKey(rangerId),
        jsonEncode(reports.map((item) => item.toJson()).toList()),
      );
    }
  }

  String _queueKey(String rangerId) => 'incident_queue_$rangerId';
}
