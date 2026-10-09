import 'package:flutter/material.dart';

import '../../domain/conservation_report_result.dart';

/// Scrollable data table showing the detail rows of a report.
class ReportDataTable extends StatelessWidget {
  const ReportDataTable({required this.result, super.key});

  final ConservationReportResult result;

  @override
  Widget build(BuildContext context) {
    if (result.tableColumns.isEmpty || result.tableRows.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.table_chart_outlined),
          title: Text('No detail data available'),
          subtitle: Text(
            'The report does not contain any tabular data for the current filters.',
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Detail (${result.tableRows.length} rows)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFE6F2E9),
                ),
                dataRowMinHeight: 36,
                dataRowMaxHeight: 48,
                columnSpacing: 20,
                horizontalMargin: 12,
                columns: result.tableColumns
                    .map(
                      (col) => DataColumn(
                        label: Text(
                          col,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                rows: result.tableRows.asMap().entries.map((entry) {
                  final row = entry.value;
                  return DataRow(
                    color: WidgetStateProperty.resolveWith<Color?>(
                      (states) =>
                          entry.key.isEven ? null : const Color(0xFFF5F8F3),
                    ),
                    cells: row
                        .map(
                          (cell) => DataCell(
                            Text(cell, style: const TextStyle(fontSize: 12)),
                          ),
                        )
                        .toList(),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
