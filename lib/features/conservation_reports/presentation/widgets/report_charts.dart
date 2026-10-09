import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/conservation_report_result.dart';

/// Renders bar charts for each chart series in a [ConservationReportResult].
class ReportCharts extends StatelessWidget {
  const ReportCharts({required this.result, super.key});

  final ConservationReportResult result;

  static const _barColors = [
    Color(0xFF17613F),
    Color(0xFF247A4A),
    Color(0xFF3BA164),
    Color(0xFF6FBF8A),
    Color(0xFF9CD4AB),
    Color(0xFFC2E6CB),
    Color(0xFF087E8B),
    Color(0xFF1769AA),
    Color(0xFF6254A5),
    Color(0xFFC65A12),
  ];

  @override
  Widget build(BuildContext context) {
    if (result.chartSeries.isEmpty) return const SizedBox.shrink();

    return Column(
      children: result.chartSeries.entries.map((entry) {
        final series = entry.value;
        if (series.isEmpty) return const SizedBox.shrink();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(entry.key, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                SizedBox(
                  height: 220,
                  child: series.length <= 6
                      ? _buildPieChart(series)
                      : _buildBarChart(series),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBarChart(List<ChartDataPoint> series) {
    final maxValue = series.fold<double>(
      0,
      (max, p) => p.value > max ? p.value : max,
    );

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${series[groupIndex].label}\n${rod.toY.toInt()}',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= series.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    series[index].label.length > 8
                        ? '${series[index].label.substring(0, 8)}…'
                        : series[index].label,
                    style: const TextStyle(fontSize: 9),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxValue > 0 ? (maxValue / 4).ceilToDouble() : 1,
        ),
        borderData: FlBorderData(show: false),
        barGroups: series.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.value,
                width: 18,
                color: _barColors[entry.key % _barColors.length],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPieChart(List<ChartDataPoint> series) {
    final total = series.fold<double>(0, (sum, p) => sum + p.value);
    if (total == 0) return const Center(child: Text('No data'));

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 30,
              sections: series.asMap().entries.map((entry) {
                final percentage = (entry.value.value / total) * 100;
                return PieChartSectionData(
                  value: entry.value.value,
                  title: '${percentage.toStringAsFixed(0)}%',
                  titleStyle: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  color: _barColors[entry.key % _barColors.length],
                  radius: 60,
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: series.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _barColors[entry.key % _barColors.length],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${entry.value.label} (${entry.value.value.toInt()})',
                        style: const TextStyle(fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
