import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rangernet/features/patrols/domain/patrol_records.dart';
import 'package:rangernet/features/patrols/presentation/patrol_route_builder_page.dart';

void main() {
  testWidgets('requires start and destination before route generation', (
    tester,
  ) async {
    await _showRouteBuilder(tester);

    final generateButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Generate route coverage'),
    );

    expect(generateButton.onPressed, isNull);
    expect(find.text('Select start and destination'), findsOneWidget);
    await _removeRouteBuilder(tester);
  });

  testWidgets('removes optional stops and returns generated route coverage', (
    tester,
  ) async {
    PatrolRoutePlan? result;
    await _showRouteBuilder(
      tester,
      initialRoute: _route(),
      onRoute: (route) => result = route,
    );

    // Seeded routes exercise editing and generation without network tile dependence.
    expect(find.text('1 optional stop(s)'), findsOneWidget);
    final stopChip = tester.widget<InputChip>(find.byType(InputChip));
    stopChip.onDeleted!();
    await tester.pumpAndSettle();
    expect(find.text('0 optional stop(s)'), findsOneWidget);

    await tester.tap(find.text('Generate route coverage'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.stops, isEmpty);
    expect(result!.coverageSections, isNotEmpty);
    expect(result!.coverageSections.first.latitude, result!.start.latitude);
    expect(result!.coverageSections.last.latitude, result!.end.latitude);
    await _removeRouteBuilder(tester);
  });

  testWidgets('shows a validation error for identical start and destination', (
    tester,
  ) async {
    await _showRouteBuilder(tester, initialRoute: _route(duplicateEnd: true));

    await tester.tap(find.text('Generate route coverage'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Could not generate route coverage'),
      findsOneWidget,
    );
    expect(find.text('Build assigned patrol route'), findsOneWidget);
    await _removeRouteBuilder(tester);
  });
}

Future<void> _showRouteBuilder(
  WidgetTester tester, {
  PatrolRoutePlan? initialRoute,
  ValueChanged<PatrolRoutePlan>? onRoute,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final route = await Navigator.of(context).push<PatrolRoutePlan>(
                MaterialPageRoute(
                  builder: (_) =>
                      PatrolRouteBuilderPage(
                        initialRoute: initialRoute,
                        showTileLayer: false,
                      ),
                ),
              );
              if (route != null) onRoute?.call(route);
            },
            child: const Text('Open route builder'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open route builder'));
  await tester.pumpAndSettle();
}

Future<void> _removeRouteBuilder(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

PatrolRoutePlan _route({bool duplicateEnd = false}) {
  final start = PatrolCoverageCheckpoint(
    id: 'start',
    name: 'Start',
    latitude: 6.1,
    longitude: 81.2,
  );
  return PatrolRoutePlan(
    start: start,
    stops: duplicateEnd
        ? const []
        : [
            PatrolCoverageCheckpoint(
              id: 'stop',
              name: 'Stop 1',
              latitude: 6.15,
              longitude: 81.25,
            ),
          ],
    end: duplicateEnd
        ? PatrolCoverageCheckpoint(
            id: 'end',
            name: 'Destination',
            latitude: start.latitude,
            longitude: start.longitude,
          )
        : PatrolCoverageCheckpoint(
            id: 'end',
            name: 'Destination',
            latitude: 6.2,
            longitude: 81.3,
          ),
  );
}
