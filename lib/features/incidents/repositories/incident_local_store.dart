// Saves drafts and reports on the phone until they can be sent to Firebase.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/incident_report.dart';

/// Small offline outbox for the student MVP. Evidence is resized before it is
/// queued, and the UI surfaces storage errors instead of claiming a save.
/// Stores the offline queue and unfinished form draft in phone preferences.
class IncidentLocalStore {
  static const _maxQueuedReports = 8;

  // Read this ranger's saved reports from the offline queue.
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

  // Add a report, or replace its existing queue copy after a failed sync.
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
    if (!saved) {
      throw StateError('The incident could not be saved on this device.');
    }
  }

  // Return the unfinished form, or null if there is no saved draft.
  Future<Map<String, dynamic>?> loadDraft(String rangerId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey(rangerId));
    if (raw == null || raw.isEmpty) return null;
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  // Save the current form so it can be restored if the screen closes.
  Future<void> saveDraft(String rangerId, Map<String, Object?> draft) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(_draftKey(rangerId), jsonEncode(draft));
    if (!saved) {
      throw StateError('The incident draft could not be saved on this device.');
    }
  }

  // Remove the unfinished form after it becomes a submitted report.
  Future<void> clearDraft(String rangerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey(rangerId));
  }

  // Use the same safe save logic when updating a queued report's status.
  Future<void> replace(IncidentReport report) => enqueue(report);

  // Remove a report only after its upload succeeds.
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
  String _draftKey(String rangerId) => 'incident_draft_$rangerId';
}
