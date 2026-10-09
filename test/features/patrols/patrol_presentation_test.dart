import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rangernet/features/patrols/domain/patrol.dart';
import 'package:rangernet/features/patrols/domain/patrol_records.dart';
import 'package:rangernet/features/patrols/presentation/manual_waypoint_map_page.dart';
import 'package:rangernet/features/patrols/presentation/patrol_coverage_summary.dart';
import 'package:rangernet/features/patrols/presentation/patrol_route_map.dart';

void main() {
  testWidgets('coverage summary shows percentage and counts accessibly', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PatrolCoverageSummary(coverage: _coverage(1, 2))),
      ),
    );

    expect(find.text('Actual patrol coverage'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('1 of 2 assigned route sections covered'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('coverage summary handles zero assigned sections', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PatrolCoverageSummary(coverage: _coverage(0, 0))),
      ),
    );

    expect(find.text('0%'), findsOneWidget);
    expect(find.text('0 of 0 assigned route sections covered'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0,
    );
  });

  testWidgets('route map is omitted when the patrol has no mapped data', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PatrolRouteMap(patrol: _patrol())),
      ),
    );

    expect(find.byType(FlutterMap), findsNothing);
    expect(find.byType(SizedBox), findsWidgets);
  });

  testWidgets('a single recorded coordinate renders a finite map camera', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PatrolRouteMap(
            showTileLayer: false,
            patrol: _patrol(
              routePoints: [
                PatrolRoutePoint(
                  id: 'single-fix',
                  location: _location(6.1, 81.2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(TileLayer), findsNothing);
  });

  testWidgets(
    'route map marks assigned, recorded, manual, and live locations',
    (tester) async {
      final patrol = _patrol(
        plannedRoute: PatrolRoutePlan(
          start: _checkpoint('start', 'Start', 6.1, 81.2),
          stops: [_checkpoint('stop', 'Stop', 6.15, 81.25)],
          end: _checkpoint('end', 'End', 6.2, 81.3),
        ),
        routePoints: [
          PatrolRoutePoint(id: 'fix-1', location: _location(6.11, 81.21)),
          PatrolRoutePoint(id: 'fix-2', location: _location(6.12, 81.22)),
        ],
        manualWaypoints: [
          PatrolWaypoint(
            id: 'waypoint-1',
            description: 'Marked tree',
            location: _location(
              6.13,
              81.23,
              source: PatrolLocationSource.manual,
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PatrolRouteMap(
              showTileLayer: false,
              patrol: patrol,
              latestLocation: _location(6.14, 81.24),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(TileLayer), findsNothing);
      expect(find.text('S'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('E'), findsOneWidget);
      expect(find.byIcon(Icons.add_location_alt), findsOneWidget);
    },
  );

  testWidgets('manual map requires valid coordinates when no center exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ManualWaypointMapPage(patrol: _patrol())),
    );

    expect(
      find.textContaining('No patrol map center is configured.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField).at(0), '91');
    await tester.enterText(find.byType(TextField).at(1), '81.2');
    await tester.tap(find.text('Open map'));
    await tester.pumpAndSettle();

    expect(find.text('Enter valid map center coordinates.'), findsOneWidget);
    expect(
      find.textContaining('No patrol map center is configured.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).at(0), '6.1');
    await tester.enterText(find.byType(TextField).at(1), '181');
    await tester.tap(find.text('Open map'));
    await tester.pumpAndSettle();

    expect(find.text('Enter valid map center coordinates.'), findsOneWidget);
    expect(
      find.textContaining('No patrol map center is configured.'),
      findsOneWidget,
    );
  });

  testWidgets('manual map identifies a selected-location action and legend', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ManualWaypointMapPage(
          showTileLayer: false,
          patrol: _patrol(
            area: const PatrolArea(
              parkName: 'Park',
              zoneName: 'Zone',
              routeName: 'Route',
              centerLatitude: 6.1,
              centerLongitude: 81.2,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(TileLayer), findsNothing);
    expect(
      find.textContaining('Tap the map to mark the exact location.'),
      findsOneWidget,
    );
    expect(find.text('Assigned route'), findsOneWidget);
    expect(find.text('No location selected'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });
}

PatrolCoverage _coverage(int covered, int total) => PatrolCoverage(
  totalSections: total,
  coveredSections: covered,
  coveredSectionIds: List.generate(covered, (index) => 'covered-$index'),
  uncoveredSectionIds: List.generate(
    total - covered,
    (index) => 'uncovered-$index',
  ),
  calculatedAt: DateTime.utc(2026, 10, 9),
);

Patrol _patrol({
  PatrolArea area = const PatrolArea(
    parkName: 'Park',
    zoneName: 'Zone',
    routeName: 'Route',
  ),
  PatrolRoutePlan? plannedRoute,
  List<PatrolRoutePoint> routePoints = const [],
  List<PatrolWaypoint> manualWaypoints = const [],
}) => Patrol(
  patrolId: 'patrol-1',
  localId: 'local-1',
  rangerId: 'ranger-1',
  rangerName: 'Ranger',
  area: area,
  status: PatrolStatus.inProgress,
  startedAt: DateTime.utc(2026, 10, 9),
  startLocation: routePoints.isEmpty ? null : routePoints.first.location,
  routePoints: routePoints,
  manualWaypoints: manualWaypoints,
  plannedRoute: plannedRoute,
);

PatrolCoverageCheckpoint _checkpoint(
  String id,
  String name,
  double latitude,
  double longitude,
) => PatrolCoverageCheckpoint(
  id: id,
  name: name,
  latitude: latitude,
  longitude: longitude,
);

PatrolLocation _location(
  double latitude,
  double longitude, {
  PatrolLocationSource source = PatrolLocationSource.gps,
}) => PatrolLocation(
  latitude: latitude,
  longitude: longitude,
  recordedAt: DateTime.utc(2026, 10, 9),
  source: source,
  accuracyMeters: source == PatrolLocationSource.gps ? 5 : null,
);
