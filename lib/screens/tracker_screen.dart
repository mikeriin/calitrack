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
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 32,
          ).copyWith(bottom: 120),
          physics: const BouncingScrollPhysics(),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "TRACKER",
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                IconButton(
                  onPressed: () => provider.clearAllHistory(),
                  icon: Icon(
                    Icons.delete_sweep_rounded,
                    color: colorScheme.error,
                    size: 28,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.error.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // HEATMAP
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: isLight
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
                border: isLight
                    ? null
                    : Border.all(color: colorScheme.surfaceContainerHighest),
              ),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "ACTIVITY (30 DAYS)",
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _ConsistencyHeatmap(
                    workedOutDates: workedOutDates,
                    fullHistory: fullHistory,
                  ),
                ],
              ),
            ),

            if (exerciseCharts.isNotEmpty) ...[
              const SizedBox(height: 48),
              Text(
                "EXERCISES LOGS",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 24),
              ...exerciseCharts.map((chartData) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: _ExerciseExpandableCard(
                    chartData: chartData,
                    provider: provider,
                  ),
                );
              }),
            ],

            if (fullHistory.isNotEmpty) ...[
              const SizedBox(height: 48),
              Text(
                "SESSIONS HISTORY",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 24),
              ...fullHistory.map((fullSession) {
                final sessionTitle = fullSession.session.title;
                final date = DateFormat("dd MMM yyyy - HH:mm").format(
                  DateTime.fromMillisecondsSinceEpoch(fullSession.session.date),
                );

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: isLight
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                    border: isLight
                        ? null
                        : Border.all(
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
                                  ?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              date.toUpperCase(),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
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
                          size: 24,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.error.withValues(
                            alpha: 0.1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
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
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: hasTrained
                  ? null
                  : Border.all(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                    ),
            ),
            alignment: Alignment.center,
            child: hasTrained
                ? Text(
                    displayFormatter.format(date),
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
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
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: colorScheme.surfaceContainerHighest),
          ),
          title: Text(
            formattedDate,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w900,
            ),
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
                final durationStr = session.formattedDuration;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (entry.key > 0)
                      Divider(
                        color: colorScheme.surfaceContainerHighest,
                        thickness: 1,
                        height: 32,
                      ),
                    Text(
                      "${session.title.toUpperCase()} - $timeFormatted ($durationStr)",
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
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
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Text(
                            "• ${exercise.name.toUpperCase()} ($setsCount sets, $totalReps reps$weightStr)",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                  ],
                );
              }).toList(),
            ),
          ),
          actionsPadding: const EdgeInsets.all(24),
          actions: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "CLOSE",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
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
    final isLight = Theme.of(context).brightness == Brightness.light;
    final chartData = widget.chartData;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isLight
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
        border: Border.all(
          color: _expanded
              ? colorScheme.primary
              : (isLight
                    ? Colors.transparent
                    : colorScheme.surfaceContainerHighest),
          width: _expanded ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      chartData.exerciseName.toUpperCase(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: !_expanded
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (chartData.yValues.isNotEmpty)
                          Container(
                            height: 220,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: _buildChart(context),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Text(
                              "No data.",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        const SizedBox(height: 24),
                        ...chartData.logs.map(
                          (log) => _buildLogItem(context, log),
                        ),
                        const SizedBox(height: 16),
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
              reservedSize: 36,
              interval: interval,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: mainSpots,
            isCurved: true,
            color: colorScheme.primary,
            barWidth: 4,
            isStrokeCapRound: true,
            belowBarData: BarAreaData(
              show: true,
              color: colorScheme.primary.withValues(alpha: 0.1),
            ),
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                    radius: 5,
                    color: colorScheme.primary,
                    strokeWidth: 2,
                    strokeColor: colorScheme.surface,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                date.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                log.details,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              color: colorScheme.error,
              size: 24,
            ),
            onPressed: () =>
                widget.provider.deleteHistoryExercise(log.exerciseId),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.error.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
