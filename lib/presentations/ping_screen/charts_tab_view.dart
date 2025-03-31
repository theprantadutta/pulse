import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../screens/ping_screen.dart';

class ChartsTabView extends StatelessWidget {
  final List<PingDataPoint> chartData;

  const ChartsTabView({super.key, required this.chartData});

  @override
  Widget build(BuildContext context) {
    return chartData.isEmpty
        ? const Center(child: Text('No data to display'))
        : Column(
          children: [
            const SizedBox(height: 16),
            const Text(
              'Response Time (ms)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SfCartesianChart(
                primaryXAxis: NumericAxis(
                  title: AxisTitle(text: 'Ping Sequence'),
                  majorGridLines: const MajorGridLines(width: 0),
                ),
                primaryYAxis: NumericAxis(
                  title: AxisTitle(text: 'Response Time (ms)'),
                ),
                tooltipBehavior: TooltipBehavior(enable: true),
                legend: Legend(
                  isVisible: true,
                  position: LegendPosition.bottom,
                ),
                series: <CartesianSeries>[
                  ColumnSeries<PingDataPoint, int>(
                    animationDuration: 1000,
                    name: 'Success',
                    dataSource:
                        chartData
                            .where((data) => data.success && !data.timedOut)
                            .toList(),
                    xValueMapper:
                        (PingDataPoint data, _) => chartData.indexOf(data),
                    yValueMapper: (PingDataPoint data, _) => data.responseTime,
                    color: Colors.green,
                    width: 0.8,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                  ColumnSeries<PingDataPoint, int>(
                    animationDuration: 1000,
                    name: 'Failed',
                    dataSource:
                        chartData
                            .where((data) => !data.success && !data.timedOut)
                            .toList(),
                    xValueMapper:
                        (PingDataPoint data, _) => chartData.indexOf(data),
                    yValueMapper:
                        (PingDataPoint data, _) =>
                            data.responseTime > 0 ? data.responseTime : 10,
                    color: Colors.red,
                    width: 0.8,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                  ColumnSeries<PingDataPoint, int>(
                    animationDuration: 1000,
                    name: 'Timeout',
                    dataSource:
                        chartData.where((data) => data.timedOut).toList(),
                    xValueMapper:
                        (PingDataPoint data, _) => chartData.indexOf(data),
                    yValueMapper:
                        (PingDataPoint data, _) =>
                            data.responseTime > 0 ? data.responseTime : 10,
                    color: Colors.orange,
                    width: 0.8,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
  }
}
