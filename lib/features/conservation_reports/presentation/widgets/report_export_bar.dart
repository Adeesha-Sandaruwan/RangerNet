import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../data/conservation_export_service.dart';
import '../../domain/conservation_report_result.dart';

/// Export buttons for CSV and PDF download.
class ReportExportBar extends StatefulWidget {
  const ReportExportBar({required this.result, super.key});

  final ConservationReportResult result;

  @override
  State<ReportExportBar> createState() => _ReportExportBarState();
}

class _ReportExportBarState extends State<ReportExportBar> {
  final _exportService = ConservationExportService();
  bool _exporting = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.download_outlined, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Export report',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _exporting ? null : _exportCsv,
                  icon: const Icon(Icons.table_chart_outlined, size: 18),
                  label: const Text('Download CSV'),
                ),
                FilledButton.icon(
                  onPressed: _exporting ? null : _exportPdf,
                  icon: _exporting
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('Download PDF'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _exportCsv() {
    try {
      final bytes = _exportService.exportCsv(widget.result);
      final fileName = _fileName('csv');
      Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: fileName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$fileName exported')),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'CSV export failed: $error');
    }
  }

  Future<void> _exportPdf() async {
    setState(() {
      _exporting = true;
      _error = null;
    });
    try {
      final bytes = await _exportService.exportPdf(widget.result);
      final fileName = _fileName('pdf');
      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: fileName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$fileName exported')),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'PDF export failed: $error');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _fileName(String extension) {
    final date = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final name = widget.result.reportType.name;
    return 'rangernet_${name}_$date.$extension';
  }
}
