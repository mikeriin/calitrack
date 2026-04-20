import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/workout_models.dart';
import '../services/database_service.dart';

class ExerciseLogItem {
  final String exerciseId;
  final int date;
  final String details;
  ExerciseLogItem({
    required this.exerciseId,
    required this.date,
    required this.details,
  });
}

class ExerciseChartData {
  final String exerciseName;
  final ExerciseType exerciseType;
  final Map<double, String> xLabels;
  final List<double> yValues;
  final List<double> yValuesMax;
  final List<ExerciseLogItem> logs;

  ExerciseChartData({
    required this.exerciseName,
    required this.exerciseType,
    required this.xLabels,
    required this.yValues,
    required this.yValuesMax,
    required this.logs,
  });
}

class TrackerProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();

  List<FullHistorySession> _fullHistory = [];
  Set<String> _workedOutDates = {};
  List<ExerciseChartData> _exerciseCharts = [];

  List<FullHistorySession> get fullHistory => _fullHistory;
  Set<String> get workedOutDates => _workedOutDates;
  List<ExerciseChartData> get exerciseCharts => _exerciseCharts;

  TrackerProvider() {
    loadHistory();
  }

  Future<void> loadHistory() async {
    _fullHistory = await _dbService.getAllFullHistory();
    _calculateWorkedOutDates();
    _calculateExerciseCharts();
    notifyListeners();
  }

  void _calculateWorkedOutDates() {
    final formatter = DateFormat('yyyy-MM-dd');
    _workedOutDates = _fullHistory
        .where((fh) => fh.session.isCompleted)
        .map(
          (fh) => formatter.format(
            DateTime.fromMillisecondsSinceEpoch(fh.session.date),
          ),
        )
        .toSet();
  }

  void _calculateExerciseCharts() {
    if (_fullHistory.isEmpty) {
      _exerciseCharts = [];
      return;
    }

    List<ExerciseChartData> newCharts = [];

    var allExercises = <Map<String, dynamic>>[];
    for (var fh in _fullHistory) {
      for (var ex in fh.exercises) {
        allExercises.add({'session': fh.session, 'exerciseWithSets': ex});
      }
    }

    var groupedByName = <String, List<Map<String, dynamic>>>{};
    for (var item in allExercises) {
      String name =
          (item['exerciseWithSets'] as HistoryExerciseWithSets).exercise.name;
      groupedByName.putIfAbsent(name, () => []).add(item);
    }

    final formatter = DateFormat('yyyy-MM-dd');

    groupedByName.forEach((name, exercisesList) {
      final firstEx =
          exercisesList.first['exerciseWithSets'] as HistoryExerciseWithSets;
      final type = firstEx.exercise.type;

      var dailyVolumes = <String, List<Map<String, dynamic>>>{};
      for (var item in exercisesList) {
        var session = item['session'] as HistorySession;
        String dateStr = formatter.format(
          DateTime.fromMillisecondsSinceEpoch(session.date),
        );
        dailyVolumes.putIfAbsent(dateStr, () => []).add(item);
      }

      var sortedKeys = dailyVolumes.keys.toList()..sort();

      Map<double, String> labelsMap = {};
      List<double> yValues = [];
      List<double> yValuesMax = [];

      for (int i = 0; i < sortedKeys.length; i++) {
        String dateStr = sortedKeys[i];
        var dailyExs = dailyVolumes[dateStr]!;

        String specificName =
            (dailyExs.first['exerciseWithSets'] as HistoryExerciseWithSets)
                .exercise
                .name;
        String shortDate = dateStr.substring(5).replaceAll('-', '/');
        labelsMap[i.toDouble()] = "$shortDate\n$specificName";

        double currentY = 0.0;
        for (var ex in dailyExs) {
          var sets = (ex['exerciseWithSets'] as HistoryExerciseWithSets).sets;
          for (var set in sets) {
            double weight = set.weightAdded > 0 ? set.weightAdded : 1.0;
            if (type == ExerciseType.cluster) {
              currentY += set.durationSeconds * weight;
            } else {
              currentY += set.repsCompleted * weight;
            }
          }
        }
        yValues.add(currentY);

        double currentMaxY = 0.0;
        if (type == ExerciseType.classic || type == ExerciseType.restPause) {
          for (var ex in dailyExs) {
            var sets = (ex['exerciseWithSets'] as HistoryExerciseWithSets).sets;
            if (sets.isNotEmpty) {
              int maxReps = sets
                  .map((s) => s.repsCompleted)
                  .reduce((a, b) => a > b ? a : b);
              double maxWeight = sets
                  .map((s) => s.weightAdded)
                  .reduce((a, b) => a > b ? a : b);
              double weightFactor = maxWeight > 0 ? maxWeight : 1.0;
              currentMaxY += (maxReps * sets.length * weightFactor);
            }
          }
        }
        yValuesMax.add(currentMaxY);
      }

      List<ExerciseLogItem> logsList = exercisesList.map((item) {
        var session = item['session'] as HistorySession;
        var exWithSets = item['exerciseWithSets'] as HistoryExerciseWithSets;

        int totalReps = exWithSets.sets.fold(
          0,
          (sum, set) => sum + set.repsCompleted,
        );
        int setsCount = exWithSets.sets.length;
        double maxWeight = exWithSets.sets.isEmpty
            ? 0.0
            : exWithSets.sets
                  .map((s) => s.weightAdded)
                  .reduce((a, b) => a > b ? a : b);
        String weightStr = maxWeight > 0 ? " @ ${maxWeight}kg" : "";

        String detailsStr =
            "$setsCount sets • $totalReps reps$weightStr"; // Simplifié, on pourra raffiner selon tes specs

        if (type == ExerciseType.cluster) {
          int duration = exWithSets.sets.fold(
            0,
            (sum, set) => sum + set.durationSeconds,
          );
          String timeStr =
              "${(duration ~/ 60).toString().padLeft(2, '0')}:${(duration % 60).toString().padLeft(2, '0')}";
          detailsStr = "$totalReps reps en $timeStr$weightStr";
        } else if (type == ExerciseType.isoMax ||
            type == ExerciseType.isoPositions) {
          detailsStr = "$setsCount sets • $totalReps total sec$weightStr";
        }

        return ExerciseLogItem(
          exerciseId: exWithSets.exercise.id,
          date: session.date,
          details: detailsStr,
        );
      }).toList();

      logsList.sort((a, b) => b.date.compareTo(a.date));

      newCharts.add(
        ExerciseChartData(
          exerciseName: name,
          exerciseType: type,
          xLabels: labelsMap,
          yValues: yValues,
          yValuesMax: yValuesMax,
          logs: logsList,
        ),
      );
    });

    _exerciseCharts = newCharts;
  }

  Future<void> deleteHistorySession(String sessionId) async {
    await _dbService.deleteHistorySession(sessionId);
    await loadHistory();
  }

  Future<void> clearAllHistory() async {
    await _dbService.clearAllHistory();
    await loadHistory();
  }

  Future<void> deleteHistoryExercise(String exerciseId) async {
    await _dbService.deleteHistoryExercise(exerciseId);
    await loadHistory();
  }
}
