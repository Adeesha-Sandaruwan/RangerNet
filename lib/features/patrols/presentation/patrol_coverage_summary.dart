import 'package:flutter/material.dart';

import '../domain/patrol_records.dart';

class PatrolCoverageSummary extends StatelessWidget {
  const PatrolCoverageSummary({required this.coverage, super.key});

  final PatrolCoverage coverage;

  @override
  Widget build(BuildContext context) {
    final percent = coverage.coveragePercent;
    final fraction = percent / 100;
    final color = percent >= 80
        ? const Color(0xFF17613F)
        : percent >= 50
        ? const Color(0xFFB7791F)
        : const Color(0xFFB54735);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  'Actual patrol coverage',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                '${percent.toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 10,
              color: color,
              backgroundColor: color.withValues(alpha: 0.16),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${coverage.coveredSections} of ${coverage.totalSections} '
            'assigned route sections covered',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 3),
          Text(
            'Estimated from reliable GPS and manual locations (100 m coverage radius).',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
