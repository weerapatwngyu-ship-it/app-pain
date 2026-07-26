import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../domain/entities/symptom_log.dart';

/// Pain-score-over-time line chart, matching the "กราฟแนวโน้มอาการเทียบกับ
/// การกินยา" requirement from the architecture doc's dashboard module.
class SymptomTrendChart extends StatelessWidget {
  const SymptomTrendChart({super.key, required this.logs});

  final List<SymptomLog> logs;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text('ยังไม่มีข้อมูลอาการในช่วงนี้')),
      );
    }

    final spots = <FlSpot>[
      for (var i = 0; i < logs.length; i++) FlSpot(i.toDouble(), logs[i].painScore.toDouble()),
    ];

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 10,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: 2,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.border,
              strokeWidth: 1,
            ),
          ),
          titlesData: const FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: 2),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.primary,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primarySoft.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
