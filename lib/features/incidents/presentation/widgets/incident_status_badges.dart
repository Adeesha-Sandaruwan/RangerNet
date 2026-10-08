import 'package:flutter/material.dart';

import '../../domain/incident_report.dart';

/// Small, high-contrast labels that make severity and workflow state scannable.
class IncidentStatusBadges extends StatelessWidget {
  const IncidentStatusBadges({
    required this.severity,
    required this.status,
    super.key,
  });

  final IncidentSeverity severity;
  final IncidentWorkflowStatus status;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 4,
    children: [
      _Badge(
        label: severity.label,
        icon: Icons.priority_high_rounded,
        color: switch (severity) {
          IncidentSeverity.low => const Color(0xFF247A4A),
          IncidentSeverity.medium => const Color(0xFF9A6700),
          IncidentSeverity.high => const Color(0xFFC65A12),
          IncidentSeverity.critical => const Color(0xFFB42318),
        },
      ),
      _Badge(
        label: status.label,
        icon: _statusIcon(status),
        color: _statusColor(status),
      ),
    ],
  );

  static Color _statusColor(IncidentWorkflowStatus status) => switch (status) {
    IncidentWorkflowStatus.reported => const Color(0xFF1769AA),
    IncidentWorkflowStatus.underReview => const Color(0xFF6254A5),
    IncidentWorkflowStatus.assigned => const Color(0xFF087E8B),
    IncidentWorkflowStatus.responseInProgress => const Color(0xFF6842A6),
    IncidentWorkflowStatus.resolved => const Color(0xFF247A4A),
    IncidentWorkflowStatus.followUpRequired => const Color(0xFFC65A12),
    IncidentWorkflowStatus.monitoring => const Color(0xFF1769AA),
    IncidentWorkflowStatus.closed => const Color(0xFF52616B),
    IncidentWorkflowStatus.duplicate => const Color(0xFF68737D),
    IncidentWorkflowStatus.rejected => const Color(0xFFB42318),
  };

  static IconData _statusIcon(IncidentWorkflowStatus status) =>
      switch (status) {
        IncidentWorkflowStatus.reported => Icons.fiber_new_rounded,
        IncidentWorkflowStatus.underReview => Icons.rate_review_outlined,
        IncidentWorkflowStatus.assigned => Icons.assignment_ind_rounded,
        IncidentWorkflowStatus.responseInProgress =>
          Icons.directions_run_rounded,
        IncidentWorkflowStatus.resolved => Icons.task_alt_rounded,
        IncidentWorkflowStatus.followUpRequired => Icons.event_repeat_rounded,
        IncidentWorkflowStatus.monitoring => Icons.visibility_outlined,
        IncidentWorkflowStatus.closed => Icons.lock_outline_rounded,
        IncidentWorkflowStatus.duplicate => Icons.content_copy_rounded,
        IncidentWorkflowStatus.rejected => Icons.block_rounded,
      };
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.icon, required this.color});

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
