import 'package:flutter_test/flutter_test.dart';
import 'package:rangernet/features/patrols/domain/patrol_records.dart';

void main() {
  group('PatrolLocation validation', () {
    test('rejects non-finite coordinates and invalid GPS accuracy', () {
      final recordedAt = DateTime.utc(2026, 10, 9);

      expect(
        () => PatrolLocation(
          latitude: double.nan,
          longitude: 81,
          recordedAt: recordedAt,
          source: PatrolLocationSource.gps,
        ),
        throwsArgumentError,
      );
      expect(
        () => PatrolLocation(
          latitude: 6,
          longitude: double.infinity,
          recordedAt: recordedAt,
          source: PatrolLocationSource.gps,
        ),
        throwsArgumentError,
      );
      expect(
        () => PatrolLocation(
          latitude: 6,
          longitude: 81,
          recordedAt: recordedAt,
          source: PatrolLocationSource.gps,
          accuracyMeters: -1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('PatrolRoutePlan validation', () {
    test('rejects duplicate route and coverage section identifiers', () {
      final start = _checkpoint('same', 'Start');
      final end = _checkpoint('same', 'End');

      expect(
        () => PatrolRoutePlan(start: start, end: end),
        throwsArgumentError,
      );
      expect(
        () => PatrolRoutePlan(
          start: _checkpoint('start', 'Start'),
          end: _checkpoint('end', 'End'),
          coverageSections: [
            _checkpoint('section', 'North'),
            _checkpoint('section', 'South'),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects plans exceeding the supported coverage section limit', () {
      final sections = List.generate(
        2001,
        (index) => _checkpoint('section-$index', 'Section $index'),
      );

      expect(
        () => PatrolRoutePlan(
          start: _checkpoint('start', 'Start'),
          end: _checkpoint('end', 'End'),
          coverageSections: sections,
        ),
        throwsArgumentError,
      );
    });
  });

  group('PatrolCoverage validation', () {
    test(
      'rejects duplicate uncovered and inconsistent covered identifiers',
      () {
        final at = DateTime.utc(2026, 10, 9);

        expect(
          () => PatrolCoverage(
            totalSections: 2,
            coveredSections: 0,
            uncoveredSectionIds: const ['section-1', 'section-1'],
            calculatedAt: at,
          ),
          throwsArgumentError,
        );
        expect(
          () => PatrolCoverage(
            totalSections: 2,
            coveredSections: 1,
            coveredSectionIds: const ['section-1', 'section-2'],
            uncoveredSectionIds: const ['section-3'],
            calculatedAt: at,
          ),
          throwsArgumentError,
        );
      },
    );
  });
}

PatrolCoverageCheckpoint _checkpoint(String id, String name) =>
    PatrolCoverageCheckpoint(
      id: id,
      name: name,
      latitude: 6.1,
      longitude: 81.2,
    );
