import 'package:flutter/material.dart';

import '../../domain/conservation_report_type.dart';

/// Grid of cards allowing the manager to select a conservation report type.
class ReportTypeSelector extends StatelessWidget {
  const ReportTypeSelector({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final ConservationReportType? selected;
  final ValueChanged<ConservationReportType> onSelected;

  static const _icons = <ConservationReportType, IconData>{
    ConservationReportType.poachingHotspot: Icons.location_on,
    ConservationReportType.patrolCoverage: Icons.shield_outlined,
    ConservationReportType.humanWildlifeConflict: Icons.warning_amber_rounded,
    ConservationReportType.incidentTrend: Icons.trending_up,
    ConservationReportType.wildlifeMonitoring: Icons.pets,
    ConservationReportType.conservationOutcome: Icons.task_alt,
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 700 ? 3 : 2;
        return GridView.count(
          crossAxisCount: crossCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.55,
          children: ConservationReportType.values.map((type) {
            final isSelected = type == selected;
            return Card(
              elevation: isSelected ? 4 : 1,
              color: isSelected
                  ? const Color(0xFFE6F2E9)
                  : Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: isSelected
                    ? const BorderSide(color: Color(0xFF17613F), width: 2)
                    : BorderSide.none,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onSelected(type),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _icons[type] ?? Icons.assessment,
                        color: isSelected
                            ? const Color(0xFF17613F)
                            : const Color(0xFF536459),
                        size: 28,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        type.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w600,
                          fontSize: 13,
                          color: isSelected ? const Color(0xFF17613F) : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Expanded(
                        child: Text(
                          type.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
