import 'package:flutter/material.dart';

import '../../../incidents/domain/incident_report.dart';
import '../../../incidents/domain/ranger_profile.dart';
import '../../domain/conservation_report_filter.dart';

/// Filter panel for UC04 conservation reports.
///
/// Provides controls for park, date range, incident type, severity,
/// and patrol team (ranger) filtering.
class ReportFilterPanel extends StatefulWidget {
  const ReportFilterPanel({
    required this.filter,
    required this.onFilterChanged,
    required this.parks,
    required this.rangers,
    super.key,
  });

  final ConservationReportFilter filter;
  final ValueChanged<ConservationReportFilter> onFilterChanged;
  final List<String> parks;
  final List<RangerProfile> rangers;

  @override
  State<ReportFilterPanel> createState() => _ReportFilterPanelState();
}

class _ReportFilterPanelState extends State<ReportFilterPanel> {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.filter_alt_outlined, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Report filters',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (!widget.filter.isEmpty)
                  TextButton.icon(
                    onPressed: () => widget.onFilterChanged(
                      const ConservationReportFilter(),
                    ),
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Clear all'),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Park filter
            DropdownButtonFormField<String?>(
              value: widget.filter.parkOrBlock,
              decoration: const InputDecoration(
                labelText: 'Park / Block',
                border: OutlineInputBorder(),
                filled: true,
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String?>(child: Text('All parks')),
                ...widget.parks.map(
                  (park) => DropdownMenuItem(value: park, child: Text(park)),
                ),
              ],
              onChanged: (value) => widget.onFilterChanged(
                widget.filter.copyWith(parkOrBlock: () => value),
              ),
            ),
            const SizedBox(height: 12),

            // Date range
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(isStart: true),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Start date',
                        border: OutlineInputBorder(),
                        filled: true,
                        isDense: true,
                        suffixIcon: Icon(Icons.calendar_today, size: 18),
                      ),
                      child: Text(
                        widget.filter.startDate != null
                            ? _formatDate(widget.filter.startDate!)
                            : 'Any',
                        style: TextStyle(
                          color: widget.filter.startDate != null
                              ? null
                              : Colors.black45,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(isStart: false),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'End date',
                        border: OutlineInputBorder(),
                        filled: true,
                        isDense: true,
                        suffixIcon: Icon(Icons.calendar_today, size: 18),
                      ),
                      child: Text(
                        widget.filter.endDate != null
                            ? _formatDate(widget.filter.endDate!)
                            : 'Any',
                        style: TextStyle(
                          color: widget.filter.endDate != null
                              ? null
                              : Colors.black45,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Incident type filter
            _MultiSelectChips<IncidentType>(
              label: 'Incident types',
              allValues: IncidentType.values,
              selectedValues: widget.filter.incidentTypes,
              labelFor: (type) => type.label,
              onChanged: (selected) => widget.onFilterChanged(
                widget.filter.copyWith(
                  incidentTypes: () => selected.isEmpty ? null : selected,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Severity filter
            _MultiSelectChips<IncidentSeverity>(
              label: 'Severity',
              allValues: IncidentSeverity.values,
              selectedValues: widget.filter.severities,
              labelFor: (severity) => severity.label,
              onChanged: (selected) => widget.onFilterChanged(
                widget.filter.copyWith(
                  severities: () => selected.isEmpty ? null : selected,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Patrol team (ranger) filter
            if (widget.rangers.isNotEmpty)
              DropdownButtonFormField<String?>(
                value: widget.filter.patrolTeamRangerIds?.isNotEmpty == true
                    ? widget.filter.patrolTeamRangerIds!.first
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Assigned ranger',
                  border: OutlineInputBorder(),
                  filled: true,
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<String?>(child: Text('All rangers')),
                  ...widget.rangers.map(
                    (ranger) => DropdownMenuItem(
                      value: ranger.uid,
                      child: Text(
                        ranger.displayName.isNotEmpty
                            ? ranger.displayName
                            : ranger.email,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) => widget.onFilterChanged(
                  widget.filter.copyWith(
                    patrolTeamRangerIds: () => value == null ? null : [value],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (widget.filter.startDate ?? now.subtract(const Duration(days: 30)))
          : (widget.filter.endDate ?? now),
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 1)),
    );
    if (picked == null) return;
    widget.onFilterChanged(
      isStart
          ? widget.filter.copyWith(startDate: () => picked)
          : widget.filter.copyWith(endDate: () => picked),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

/// Horizontally scrollable filter chips that allow multi-selection.
class _MultiSelectChips<T> extends StatelessWidget {
  const _MultiSelectChips({
    required this.label,
    required this.allValues,
    required this.selectedValues,
    required this.labelFor,
    required this.onChanged,
  });

  final String label;
  final List<T> allValues;
  final List<T>? selectedValues;
  final String Function(T) labelFor;
  final ValueChanged<List<T>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: allValues.map((value) {
            final isSelected = selectedValues?.contains(value) ?? false;
            return FilterChip(
              label: Text(labelFor(value)),
              selected: isSelected,
              onSelected: (selected) {
                final current = List<T>.from(selectedValues ?? []);
                if (selected) {
                  current.add(value);
                } else {
                  current.remove(value);
                }
                onChanged(current);
              },
              selectedColor: const Color(0xFFE6F2E9),
              checkmarkColor: const Color(0xFF17613F),
              labelStyle: TextStyle(
                fontSize: 12,
                color: isSelected ? const Color(0xFF17613F) : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
