import 'package:flutter_test/flutter_test.dart';
import 'package:rangernet/features/conservation_reports/data/conservation_export_service.dart';
import 'package:rangernet/features/conservation_reports/domain/conservation_report_result.dart';
import 'package:rangernet/features/conservation_reports/domain/conservation_report_type.dart';

void main() {
  late ConservationExportService service;

  setUp(() {
    service = ConservationExportService();
  });

  group('CSV export', () {
    test('produces non-empty bytes for a valid result', () {
      final result = _sampleResult();
      final bytes = service.exportCsv(result);
      expect(bytes, isNotEmpty);
      final content = String.fromCharCodes(bytes);
      expect(content, contains('Poaching Hotspot Report'));
      expect(content, contains('Total incidents'));
    });

    test('includes table headers and rows', () {
      final result = _sampleResult();
      final bytes = service.exportCsv(result);
      final content = String.fromCharCodes(bytes);
      expect(content, contains('Area'));
      expect(content, contains('Yala North'));
    });

    test('produces valid CSV for empty result', () {
      final result = _emptyResult();
      final bytes = service.exportCsv(result);
      expect(bytes, isNotEmpty);
      final content = String.fromCharCodes(bytes);
      expect(content, contains('0'));
    });
  });

  group('PDF export', () {
    test('produces non-empty bytes for a valid result', () async {
      final result = _sampleResult();
      final bytes = await service.exportPdf(result);
      expect(bytes, isNotEmpty);
      // PDF files start with %PDF
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });

    test('produces valid PDF for empty result', () async {
      final result = _emptyResult();
      final bytes = await service.exportPdf(result);
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });
  });
}

ConservationReportResult _sampleResult() => ConservationReportResult(
      reportType: ConservationReportType.poachingHotspot,
      generatedAt: DateTime(2026, 6, 15, 10, 30),
      totalIncidents: 5,
      summaryMetrics: const {
        'Total incidents': '5',
        'Top hotspot': 'Yala North',
        'Active threats': '2',
      },
      chartSeries: const {
        'By area': [
          ChartDataPoint('Yala North', 3),
          ChartDataPoint('Wilpattu', 2),
        ],
      },
      tableColumns: const ['Area', 'Total', 'Critical'],
      tableRows: const [
        ['Yala North', '3', '1'],
        ['Wilpattu', '2', '0'],
      ],
    );

ConservationReportResult _emptyResult() => ConservationReportResult(
      reportType: ConservationReportType.poachingHotspot,
      generatedAt: DateTime(2026, 6, 15),
      totalIncidents: 0,
      summaryMetrics: const {'Total incidents': '0'},
      chartSeries: const {},
      tableColumns: const ['Area', 'Total'],
      tableRows: const [],
    );
