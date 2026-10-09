import 'package:flutter/material.dart';
import '../../domain/models/geo_location.dart';

class LocationHistoryTimeline extends StatelessWidget {
  const LocationHistoryTimeline({
    required this.locations,
    super.key,
  });

  final List<GeoLocation> locations;

  @override
  Widget build(BuildContext context) {
    if (locations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No location telemetry recorded.',
          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
        ),
      );
    }

    final reversedList = locations.reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Telemetry Breadcrumbs (${locations.length} pings)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF17613F),
                  ),
            ),
            if (locations.length > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Throttled stream active',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: reversedList.length,
          separatorBuilder: (context, index) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final loc = reversedList[index];
            final isLatest = index == 0;

            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isLatest
                    ? const Color(0xFFF1F8F5)
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isLatest
                      ? const Color(0xFF17613F).withValues(alpha: 0.4)
                      : Colors.grey.shade300,
                  width: isLatest ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: isLatest
                        ? const Color(0xFF17613F)
                        : Colors.grey.shade400,
                    child: Text(
                      '${locations.length - index}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Lat: ${loc.latitude.toStringAsFixed(5)}, Lon: ${loc.longitude.toStringAsFixed(5)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isLatest
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            if (isLatest) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF17613F),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'LATEST',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (loc.altitude != null)
                          Text(
                            'Altitude: ${loc.altitude!.toStringAsFixed(1)}m',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    _formatTime(loc.timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }
}
