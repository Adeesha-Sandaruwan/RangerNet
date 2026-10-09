import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/conservation_report_result.dart';

/// Exports a [ConservationReportResult] to CSV or PDF formats.
///
/// Both methods are synchronous and return raw bytes that can be
/// saved to disk or downloaded from the browser.
class ConservationExportService {
  static final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  // ──────────────────────────── CSV ────────────────────────────

  /// Exports the report as a UTF-8 encoded CSV string (as bytes).
  List<int> exportCsv(ConservationReportResult result) {
    final rows = <List<String>>[];

    // Header metadata
    rows.add([result.displayTitle]);
    rows.add(['Generated', _dateFormat.format(result.generatedAt)]);
    rows.add(['Total incidents analysed', result.totalIncidents.toString()]);
    rows.add([]); // blank line

    // Summary metrics
    rows.add(['Summary']);
    for (final entry in result.summaryMetrics.entries) {
      rows.add([entry.key, entry.value]);
    }
    rows.add([]);

    // Detail table
    if (result.tableColumns.isNotEmpty) {
      rows.add(['Detail']);
      rows.add(result.tableColumns);
      rows.addAll(result.tableRows);
    }

    final csv = const ListToCsvConverter().convert(rows);
    return utf8.encode(csv);
  }

  // ──────────────────────────── PDF ────────────────────────────

  /// Exports the report as a PDF document (as bytes).
  Future<List<int>> exportPdf(ConservationReportResult result) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Title
          pw.Header(
            level: 0,
            child: pw.Text(
              result.displayTitle,
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated: ${_dateFormat.format(result.generatedAt)}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.Text(
            'Total incidents analysed: ${result.totalIncidents}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),

          // Summary metrics
          pw.Header(level: 1, text: 'Summary'),
          pw.TableHelper.fromTextArray(
            headerCount: 0,
            cellAlignment: pw.Alignment.centerLeft,
            data: result.summaryMetrics.entries
                .map((e) => [e.key, e.value])
                .toList(),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
          ),
          pw.SizedBox(height: 16),

          // Detail table
          if (result.tableColumns.isNotEmpty) ...[
            pw.Header(level: 1, text: 'Detail'),
            pw.TableHelper.fromTextArray(
              headers: result.tableColumns,
              data: result.tableRows,
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.green50,
              ),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3,
              ),
              cellAlignments: {
                for (var i = 0; i < result.tableColumns.length; i++)
                  i: i == 0
                      ? pw.Alignment.centerLeft
                      : pw.Alignment.centerRight,
              },
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }
}
