import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../domain/patrol_records.dart';

class PatrolCoverageSectionMapPage extends StatefulWidget {
  const PatrolCoverageSectionMapPage({
    this.initialCenter,
    this.initialSections = const [],
    super.key,
  });

  final LatLng? initialCenter;
  final List<PatrolCoverageCheckpoint> initialSections;

  @override
  State<PatrolCoverageSectionMapPage> createState() =>
      _PatrolCoverageSectionMapPageState();
}

class _PatrolCoverageSectionMapPageState
    extends State<PatrolCoverageSectionMapPage> {
  static const _uuid = Uuid();

  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  late final List<PatrolCoverageCheckpoint> _sections = [
    ...widget.initialSections,
  ];
  late int _nextSectionNumber = _sections.length + 1;
  LatLng? _center;
  bool _tilesUnavailable = false;

  @override
  void initState() {
    super.initState();
    _center = widget.initialCenter;
  }

  @override
  void dispose() {
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = _center;
    return Scaffold(
      appBar: AppBar(title: const Text('Define patrol coverage sections')),
      body: center == null ? _buildChooseCenter() : _buildMap(center),
    );
  }

  Widget _buildChooseCenter() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: ListView(
        padding: const EdgeInsets.all(20),
        shrinkWrap: true,
        children: [
          const Icon(Icons.map_outlined, size: 46),
          const SizedBox(height: 12),
          const Text(
            'Enter an approximate center coordinate for the assigned zone. '
            'Then tap the map to mark each required coverage section.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _latitude,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: const InputDecoration(
              labelText: 'Map center latitude',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _longitude,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: const InputDecoration(
              labelText: 'Map center longitude',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _openMapAtEnteredCenter,
            child: const Text('Open map'),
          ),
        ],
      ),
    ),
  );

  Widget _buildMap(LatLng center) => Column(
    children: [
      if (_tilesUnavailable)
        const MaterialBanner(
          content: Text(
            'Map tiles are unavailable. Coordinates can still be marked at '
            'the selected map positions.',
          ),
          leading: Icon(Icons.map_outlined),
          actions: [SizedBox.shrink()],
        ),
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text(
          'Tap once for each required patrol section. A section is counted '
          'as covered when a recorded GPS point or manual waypoint is within '
          '100 m.',
        ),
      ),
      Expanded(
        child: FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: 15,
            onTap: (_, point) => _addSection(point),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'lk.rangernet.rangernet',
              errorTileCallback: (_, _, _) {
                if (_tilesUnavailable || !mounted) return;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _tilesUnavailable = true);
                });
              },
            ),
            MarkerLayer(
              markers: _sections.indexed
                  .map(
                    (entry) => Marker(
                      point: LatLng(
                        entry.$2.latitude,
                        entry.$2.longitude,
                      ),
                      child: Tooltip(
                        message: entry.$2.name,
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: const Color(0xFF17613F),
                          child: Text(
                            '${entry.$1 + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
      ),
      if (_sections.isNotEmpty)
        SizedBox(
          height: 54,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: _sections
                .map(
                  (section) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InputChip(
                      label: Text(section.name),
                      onDeleted: () => setState(
                        () => _sections.removeWhere(
                          (item) => item.id == section.id,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _sections.isEmpty
                      ? 'No coverage sections marked'
                      : '${_sections.length} coverage section(s) marked',
                ),
              ),
              FilledButton(
                onPressed: _sections.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(
                        List<PatrolCoverageCheckpoint>.unmodifiable(_sections),
                      ),
                child: const Text('Use sections'),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  void _openMapAtEnteredCenter() {
    final latitude = double.tryParse(_latitude.text.trim());
    final longitude = double.tryParse(_longitude.text.trim());
    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid map center coordinates.')),
      );
      return;
    }
    setState(() => _center = LatLng(latitude, longitude));
  }

  void _addSection(LatLng point) {
    setState(() {
      _sections.add(
        PatrolCoverageCheckpoint(
          id: _uuid.v4(),
          name: 'Section $_nextSectionNumber',
          latitude: point.latitude,
          longitude: point.longitude,
        ),
      );
      _nextSectionNumber++;
    });
  }
}
