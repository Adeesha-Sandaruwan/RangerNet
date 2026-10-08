import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rangernet/features/incidents/data/incident_local_store.dart';
import 'package:rangernet/features/incidents/domain/incident_report.dart';

void main() {
  late IncidentLocalStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = IncidentLocalStore();
  });

  group('offline incident queue', () {
    test('starts empty when no reports were saved', () async {
      expect(await store.loadQueue('ranger-uid'), isEmpty);
    });

    test('saves and loads a report with its photo data', () async {
      await store.enqueue(_report('INC-1', title: 'Original report'));

      final loaded = await store.loadQueue('ranger-uid');

      expect(loaded, hasLength(1));
      expect(loaded.single.title, 'Original report');
      expect(loaded.single.evidence.single.base64Data, 'cGhvdG8=');
      expect(loaded.single.status, IncidentStatus.pendingSync);
    });

    test(
      'saving the same report again updates it instead of duplicating it',
      () async {
        await store.enqueue(_report('INC-1', title: 'First version'));
        await store.enqueue(_report('INC-1', title: 'Updated version'));

        final loaded = await store.loadQueue('ranger-uid');

        expect(loaded, hasLength(1));
        expect(loaded.single.title, 'Updated version');
      },
    );

    test(
      'rejects the ninth different pending report and preserves the first eight',
      () async {
        for (var index = 1; index <= 8; index++) {
          await store.enqueue(_report('INC-$index'));
        }

        await expectLater(store.enqueue(_report('INC-9')), throwsStateError);
        expect(await store.loadQueue('ranger-uid'), hasLength(8));
      },
    );

    test('removes one report and deletes the empty queue', () async {
      await store.enqueue(_report('INC-1'));
      await store.enqueue(_report('INC-2'));
      await store.remove('ranger-uid', 'INC-1');
      expect((await store.loadQueue('ranger-uid')).single.id, 'INC-2');

      await store.remove('ranger-uid', 'INC-2');
      expect(await store.loadQueue('ranger-uid'), isEmpty);
    });

    test(
      'removing a report that is not queued leaves the queue unchanged',
      () async {
        await store.enqueue(_report('INC-1'));
        await store.remove('ranger-uid', 'missing');
        expect((await store.loadQueue('ranger-uid')).single.id, 'INC-1');
      },
    );

    test('reports malformed saved queue data as an error', () async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('incident_queue_ranger-uid', '{not json');

      await expectLater(store.loadQueue('ranger-uid'), throwsFormatException);
    });
  });

  group('incident draft', () {
    test('loads null when there is no saved draft', () async {
      expect(await store.loadDraft('ranger-uid'), isNull);
    });

    test('saves, reloads, and clears a draft', () async {
      const draft = <String, Object?>{
        'title': 'Snare near trail',
        'description': 'Fresh tracks nearby',
        'step': 2,
      };
      await store.saveDraft('ranger-uid', draft);

      expect(await store.loadDraft('ranger-uid'), draft);
      await store.clearDraft('ranger-uid');
      expect(await store.loadDraft('ranger-uid'), isNull);
    });
  });
}

IncidentReport _report(String id, {String title = 'Wildlife incident'}) =>
    IncidentReport(
      id: id,
      rangerId: 'ranger-uid',
      rangerEmail: 'ranger@example.com',
      type: IncidentType.illegalSnare,
      title: title,
      description: 'Found during patrol.',
      severity: IncidentSeverity.medium,
      activeThreat: false,
      latitude: 6.1,
      longitude: 81.2,
      locationAccuracyMeters: 7,
      parkOrBlock: 'North block',
      createdAt: DateTime.utc(2026),
      status: IncidentStatus.pendingSync,
      evidence: const [
        IncidentEvidence(
          id: 'photo-1',
          fileName: 'evidence.jpg',
          base64Data: 'cGhvdG8=',
          contentType: 'image/jpeg',
        ),
      ],
    );
