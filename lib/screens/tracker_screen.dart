// lib/screens/tracker_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../viewmodels/tracker_provider.dart';

class TrackerScreen extends StatelessWidget {
  const TrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TrackerProvider>().loadHistory();
    });

    final provider = context.watch<TrackerProvider>();
    final exerciseCharts = provider.exerciseCharts;
    final Set<String> workedOutDates = provider.workedOutDates;
    final List<dynamic> fullHistory = provider.fullHistory;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ).copyWith(bottom: 100),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "TRACKER",
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                IconButton(
                  onPressed: () => provider.clearAllHistory(),
                  icon: Icon(
                    Icons.delete_sweep_rounded,
                    color: colorScheme.error,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.error.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // HEATMAP
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.surfaceContainerHighest),
              ),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "ACTIVITY (30 DAYS)",
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ConsistencyHeatmap(
                    workedOutDates: workedOutDates,
                    fullHistory: fullHistory,
                  ),
                ],
              ),
            ),

            if (exerciseCharts.isNotEmpty) ...[
              const SizedBox(height: 40),
              Text(
                "EXERCISES LOGS",
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
              ),
              const SizedBox(height: 16),
              ...exerciseCharts.map((chartData) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: _ExerciseExpandableCard(
                    chartData: chartData,
                    provider: provider,
                  ),
                );
              }),
            ],

            if (fullHistory.isNotEmpty) ...[
              const SizedBox(height: 40),
              Text(
                "SESSIONS HISTORY",
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
              ),
              const SizedBox(height: 16),
              ...fullHistory.map((fullSession) {
                final sessionTitle = fullSession.session.title;
                final date = DateFormat("dd MMM yyyy - HH:mm").format(
                  DateTime.fromMillisecondsSinceEpoch(fullSession.session.date),
                );

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sessionTitle.toUpperCase(),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: colorScheme.primary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              date.toUpperCase(),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => provider.deleteHistorySession(
                          fullSession.session.id,
                        ),
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: colorScheme.error,
                          size: 20,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.error.withValues(
                            alpha: 0.1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConsistencyHeatmap extends StatelessWidget {
  final Set<String> workedOutDates;
  final List<dynamic> fullHistory;

  const _ConsistencyHeatmap({
    required this.workedOutDates,
    required this.fullHistory,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final formatter = DateFormat('yyyy-MM-dd');
    final displayFormatter = DateFormat('MM/dd');
    final today = DateTime.now();
    final last30Days = List.generate(
      30,
      (i) => today.subtract(Duration(days: 29 - i)),
    );

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: 30,
      itemBuilder: (context, index) {
        final date = last30Days[index];
        final dateStr = formatter.format(date);
        final hasTrained = workedOutDates.contains(dateStr);

        return GestureDetector(
          onTap: hasTrained
              ? () {
                  final sessionsForDay = fullHistory
                      .where(
                        (s) =>
                            formatter.format(
                              DateTime.fromMillisecondsSinceEpoch(
                                s.session.date,
                              ),
                            ) ==
                            dateStr,
                      )
                      .toList();
                  if (sessionsForDay.isNotEmpty) {
                    _showSessionDetailsDialog(context, sessionsForDay, date);
                  }
                }
              : null,
          child: Container(
            decoration: BoxDecoration(
              color: hasTrained
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: hasTrained
                ? Text(
                    displayFormatter.format(date),
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }

  void _showSessionDetailsDialog(
    BuildContext context,
    List<dynamic> sessionsForDay,
    DateTime date,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final formattedDate = DateFormat(
      "EEEE dd MMMM yyyy",
    ).format(date).toUpperCase();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: colorScheme.surfaceContainerHighest,
            ), // CORRECTION DU BORDER
          ),
          title: Text(
            formattedDate,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: colorScheme.primary),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: sessionsForDay.asMap().entries.map((entry) {
                final sessionData = entry.value;
                final session = sessionData.session;
                final timeFormatted = DateFormat(
                  "HH:mm",
                ).format(DateTime.fromMillisecondsSinceEpoch(session.date));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (entry.key > 0)
                      Divider(
                        color: colorScheme.surfaceContainerHighest,
                        thickness: 1,
                        height: 24,
                      ),
                    Text(
                      "${session.title.toUpperCase()} - $timeFormatted",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    if (sessionData.exercises != null)
                      ...sessionData.exercises.map<Widget>((exWithSets) {
                        final exercise = exWithSets.exercise;
                        final setsCount = exWithSets.sets.length;

                        int totalReps = 0;
                        double maxWeight = 0;

                        for (var s in exWithSets.sets) {
                          totalReps += (s.repsCompleted as num).toInt();
                          if (s.weightAdded != null &&
                              s.weightAdded > maxWeight) {
                            maxWeight = (s.weightAdded as num).toDouble();
                          }
                        }

                        final weightStr = maxWeight > 0
                            ? " @ ${maxWeight}kg"
                            : "";
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            "• ${exercise.name.toUpperCase()} ($setsCount sets, $totalReps reps$weightStr)",
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      }).toList(),
                  ],
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CLOSE"),
            ),
          ],
        );
      },
    );
  }
}

class _ExerciseExpandableCard extends StatefulWidget {
  final ExerciseChartData chartData;
  final TrackerProvider provider;
  const _ExerciseExpandableCard({
    required this.chartData,
    required this.provider,
  });
  @override
  State<_ExerciseExpandableCard> createState() =>
      _ExerciseExpandableCardState();
}

class _ExerciseExpandableCardState extends State<_ExerciseExpandableCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final chartData = widget.chartData;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.surfaceContainerHighest),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      chartData.exerciseName.toUpperCase(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: !_expanded
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (chartData.yValues.isNotEmpty)
                          SizedBox(height: 200, child: _buildChart(context))
                        else
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              "No data.",
                              textAlign: TextAlign.center,
                            ),
                          ),
                        const SizedBox(height: 16),
                        Divider(color: colorScheme.surfaceContainerHighest),
                        ...chartData.logs.map(
                          (log) => _buildLogItem(context, log),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final chartData = widget.chartData;
    List<FlSpot> mainSpots = [];
    double maxY = 0;
    for (int i = 0; i < chartData.yValues.length; i++) {
      double y = chartData.yValues[i].toDouble();
      mainSpots.add(FlSpot(i.toDouble(), y));
      if (y > maxY) maxY = y;
    }
    maxY = maxY + (maxY * 0.2);
    if (maxY < 10) maxY = 10;
    double interval = maxY / 4;
    if (interval < 1) interval = 1;
    double minX = 0, maxX = (chartData.yValues.length - 1).toDouble();
    if (chartData.yValues.length == 1) {
      minX = -0.5;
      maxX = 0.5;
    }

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: colorScheme.surfaceContainerHighest,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: interval,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: mainSpots,
            isCurved: true,
            color: colorScheme.secondary,
            barWidth: 2,
            // CORRECTION DES UNDERSCORES : Utilisation de noms explicites au lieu de _, __, ___, ____
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                    radius: 3,
                    color: colorScheme.secondary,
                    strokeWidth: 0,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(BuildContext context, dynamic log) {
    final colorScheme = Theme.of(context).colorScheme;
    final date = DateFormat(
      'dd MMM yyyy',
    ).format(DateTime.fromMillisecondsSinceEpoch(log.date));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                date.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                log.details,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(
              Icons.delete,
              color: colorScheme.surfaceContainerHighest,
              size: 20,
            ),
            onPressed: () =>
                widget.provider.deleteHistoryExercise(log.exerciseId),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
