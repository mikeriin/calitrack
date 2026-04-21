// lib/viewmodels/session_provider.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/workout_models.dart';
import '../services/database_service.dart';
import '../services/progress_repository.dart';

class SessionProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final ProgressRepository _progressRepo;
  late StreamSubscription _progressSub;

  List<Session> _allSessions = [];
  Session? _sessionOfTheDay;
  SessionProgress _progress = SessionProgress();
  bool _isSessionOfTheDayCompleted = false;

  List<Session> get allSessions => _allSessions;
  Session? get sessionOfTheDay => _sessionOfTheDay;
  SessionProgress get progress => _progress;
  bool get isSessionOfTheDayCompleted => _isSessionOfTheDayCompleted;
  bool get keepAwake => _progressRepo.keepAwake;

  SessionProvider(this._progressRepo) {
    _loadSessions();
    _progressSub = _progressRepo.progressFlow.listen((newProgress) {
      _progress = newProgress;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _progressSub.cancel();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    _allSessions = await _dbService.getAllSessions();
    _calculateSessionOfTheDay();
    await _checkIfSessionCompletedToday();
    notifyListeners();
  }

  void _calculateSessionOfTheDay() {
    final now = DateTime.now();
    final currentDay = Day.values[now.weekday - 1];
    try {
      _sessionOfTheDay = _allSessions.firstWhere((s) => s.day == currentDay);
    } catch (e) {
      _sessionOfTheDay = null;
    }
  }

  Future<void> _checkIfSessionCompletedToday() async {
    if (_sessionOfTheDay == null) {
      _isSessionOfTheDayCompleted = false;
      return;
    }
    try {
      final histories = await _dbService.getAllHistorySessions();
      final now = DateTime.now();
      final startOfDay = DateTime(
        now.year,
        now.month,
        now.day,
      ).millisecondsSinceEpoch;
      final endOfDay = DateTime(
        now.year,
        now.month,
        now.day,
        23,
        59,
        59,
      ).millisecondsSinceEpoch;

      _isSessionOfTheDayCompleted = histories.any(
        (h) =>
            h.originalSessionId == _sessionOfTheDay!.id &&
            h.isCompleted &&
            h.date >= startOfDay &&
            h.date <= endOfDay,
      );
    } catch (e) {
      _isSessionOfTheDayCompleted = false;
    }
  }

  void startSession(String sessionId) {
    if (_progressRepo.keepAwake) {
      WakelockPlus.enable(); // Enable if wakelock_plus package is installed
      debugPrint("Wakelock enabled for the session.");
    }

    if (_progressRepo.isGarminLinked) {
      debugPrint(
        "Garmin Connection: Starting temporary recording of watch data...",
      );
    }

    final newProgress = _progress.copyWith(
      startTime: DateTime.now().millisecondsSinceEpoch,
      sessionId: sessionId,
    );
    _progressRepo.saveProgress(newProgress);
  }

  void updateProgress(SessionProgress newProgress) {
    var progressToSave = newProgress;
    if (newProgress.isFinished && !_progress.isFinished) {
      progressToSave = newProgress.copyWith(
        endTime: DateTime.now().millisecondsSinceEpoch,
      );
    }
    _progressRepo.saveProgress(progressToSave);
  }

  void resetSession() {
    if (_progressRepo.keepAwake) {
      WakelockPlus.disable(); // Disable wakelock
      debugPrint("Wakelock disabled.");
    }
    _progressRepo.clearProgress();
  }

  Future<void> addSession(Session newSession) async {
    await _dbService.insertSession(newSession);
    await _loadSessions();
  }

  Future<void> updateSession(Session updatedSession) async {
    await _dbService.insertSession(updatedSession);
    await _loadSessions();
  }

  Future<void> deleteSession(String sessionId) async {
    await _dbService.deleteSession(sessionId);
    await _loadSessions();
  }

  // Helper pour déduire le type d'exercice
  ExerciseType _getTypeFromExercise(Exercise ex) {
    if (ex is Classic) return ExerciseType.classic;
    if (ex is Amrap) return ExerciseType.amrap;
    if (ex is Emom) return ExerciseType.emom;
    if (ex is RestPause) return ExerciseType.restPause;
    if (ex is Cluster) return ExerciseType.cluster;
    if (ex is Circuit) return ExerciseType.circuit;
    if (ex is IsoMax) return ExerciseType.isoMax;
    if (ex is IsoPositions) return ExerciseType.isoPositions;
    return ExerciseType.restBlock;
  }

  Future<void> importSessionFromJson(String jsonString) async {
    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      map['id'] = const Uuid().v4();
      if (map['exercises'] != null) {
        final exList = jsonDecode(map['exercises']) as List;
        for (var ex in exList) {
          if (ex is Map<String, dynamic>) ex['id'] = const Uuid().v4();
        }
        map['exercises'] = jsonEncode(exList);
      }

      final newSession = Session.fromMap(map);

      // --- IMPORT AUTOMATIQUE DES ASSETS INCONNUS ---
      final existingAssets = await _dbService.getAllAssets();
      final existingConditions = await _dbService.getAllConditions();

      for (final ex in newSession.exercises) {
        // 1. Importer la condition si elle n'existe pas
        if (ex.condition != null) {
          final cond = ex.condition!;
          bool condExists = existingConditions.any(
            (c) =>
                c.name.toLowerCase() == cond.name.toLowerCase() &&
                c.type == cond.type,
          );

          if (!condExists) {
            await _dbService.insertCondition(cond);
            existingConditions.add(
              cond,
            ); // Met à jour la liste locale pour cette boucle
          }
        }

        // 2. Importer l'exercice comme Asset s'il n'existe pas
        final exType = _getTypeFromExercise(ex);
        if (exType != ExerciseType.restBlock) {
          bool assetExists = existingAssets.any(
            (a) =>
                a.name.toLowerCase() == ex.name.toLowerCase() &&
                a.type == exType,
          );

          if (!assetExists) {
            final newAsset = AssetExercise(
              name: ex.name,
              type: exType,
              condition: ex.condition,
            );
            await _dbService.insertAsset(newAsset);
            existingAssets.add(
              newAsset,
            ); // Met à jour la liste locale pour cette boucle
          }
        }
      }
      // ------------------------------------------------

      await addSession(newSession);
    } catch (e) {
      debugPrint("Error importing session: $e");
      rethrow;
    }
  }

  Future<void> addExercise(String sessionId, Exercise newExercise) async {
    final sessionIndex = _allSessions.indexWhere((s) => s.id == sessionId);
    if (sessionIndex != -1) {
      final session = _allSessions[sessionIndex];
      final updatedExercises = List<Exercise>.from(session.exercises)
        ..add(newExercise);
      await updateSession(
        Session(
          id: session.id,
          title: session.title,
          day: session.day,
          exercises: updatedExercises,
        ),
      );
    }
  }

  Future<void> deleteExercise(String sessionId, String exerciseId) async {
    final sessionIndex = _allSessions.indexWhere((s) => s.id == sessionId);
    if (sessionIndex != -1) {
      final session = _allSessions[sessionIndex];
      final updatedExercises = session.exercises
          .where((e) => e.id != exerciseId)
          .toList();
      await updateSession(
        Session(
          id: session.id,
          title: session.title,
          day: session.day,
          exercises: updatedExercises,
        ),
      );
    }
  }

  Future<void> updateExercise(
    String sessionId,
    Exercise updatedExercise,
  ) async {
    final sessionIndex = _allSessions.indexWhere((s) => s.id == sessionId);
    if (sessionIndex != -1) {
      final session = _allSessions[sessionIndex];
      final updatedExercises = session.exercises
          .map((e) => e.id == updatedExercise.id ? updatedExercise : e)
          .toList();
      await updateSession(
        Session(
          id: session.id,
          title: session.title,
          day: session.day,
          exercises: updatedExercises,
        ),
      );
    }
  }

  Future<void> updateExercisesOrder(
    String sessionId,
    List<Exercise> newOrder,
  ) async {
    final sessionIndex = _allSessions.indexWhere((s) => s.id == sessionId);
    if (sessionIndex != -1) {
      final session = _allSessions[sessionIndex];
      await updateSession(
        Session(
          id: session.id,
          title: session.title,
          day: session.day,
          exercises: newOrder,
        ),
      );
    }
  }

  Future<void> cleanSession(String sessionId) async {
    final sessionIndex = _allSessions.indexWhere((s) => s.id == sessionId);
    if (sessionIndex == -1) return;

    final session = _allSessions[sessionIndex];
    List<Exercise> rawExercises = List.from(session.exercises);
    List<Exercise> cleaned = [];

    for (int i = 0; i < rawExercises.length; i++) {
      final currentEx = rawExercises[i];
      if (currentEx is RestBlock) {
        if (cleaned.isNotEmpty && cleaned.last is RestBlock) {
          final previousRest = cleaned.removeLast() as RestBlock;
          cleaned.add(
            RestBlock(
              id: previousRest.id,
              restSeconds: previousRest.restSeconds + currentEx.restSeconds,
            ),
          );
        } else {
          cleaned.add(currentEx);
        }
      } else {
        cleaned.add(currentEx);
      }
    }
    while (cleaned.isNotEmpty && cleaned.last is RestBlock) {
      cleaned.removeLast();
    }

    await updateSession(
      Session(
        id: session.id,
        title: session.title,
        day: session.day,
        exercises: cleaned,
      ),
    );
  }

  Future<void> applyConditionToSession(
    String sessionId,
    ProgressionCondition condition,
  ) async {
    final sessionIndex = _allSessions.indexWhere((s) => s.id == sessionId);
    if (sessionIndex != -1) {
      final session = _allSessions[sessionIndex];
      final updatedExercises = session.exercises
          .map((e) => e.copyWithCondition(condition))
          .toList();
      await updateSession(
        Session(
          id: session.id,
          title: session.title,
          day: session.day,
          exercises: updatedExercises,
        ),
      );
    }
  }

  Future<void> saveCompletedWorkout(
    Session session,
    int durationMillis,
    List<WorkoutLogEntry> logs,
  ) async {
    // FIX: Empêcher le double enregistrement si la méthode est appelée plusieurs fois
    if (_progress.isSaved) {
      debugPrint("Workout already saved. Skipping double log insertion.");
      return;
    }

    // Marquer immédiatement comme sauvegardé en mémoire locale pour bloquer les appels concurrents
    _progress = _progress.copyWith(isSaved: true);

    final historySessionId = const Uuid().v4();
    List<String> finalStats = List.from(_progress.stats);

    // Garmin Processing
    if (_progressRepo.isGarminLinked) {
      debugPrint(
        "Garmin: Creating summary, adding to stats, and freeing local memory.",
      );
      // Simulating extracted stats
      // finalStats.add("GARMIN: 420 Kcal, Avg HR: 135 bpm");
      // Simulated release of local recording variables
    }

    if (_progressRepo.keepAwake) {
      WakelockPlus.disable();
      debugPrint("Wakelock disabled.");
    }

    final historySession = HistorySession(
      id: historySessionId,
      originalSessionId: session.id,
      title: session.title,
      date: DateTime.now().millisecondsSinceEpoch,
      durationMillis: durationMillis,
      isCompleted: true,
    );
    await _dbService.insertHistorySession(historySession);

    List<HistoryExercise> exercisesToSave = [];
    List<HistorySet> setsToSave = [];

    final groupedLogs = <String, List<WorkoutLogEntry>>{};
    for (var log in logs) {
      groupedLogs.putIfAbsent(log.exerciseName, () => []).add(log);
    }

    for (var entry in groupedLogs.entries) {
      final exName = entry.key;
      final exLogs = entry.value;
      final historyExId = const Uuid().v4();
      final exerciseType = exLogs.first.exerciseType;

      exercisesToSave.add(
        HistoryExercise(
          id: historyExId,
          historySessionId: historySessionId,
          name: exName,
          type: exerciseType,
        ),
      );

      for (var log in exLogs) {
        setsToSave.add(
          HistorySet(
            historyExerciseId: historyExId,
            setIndex: log.setIndex,
            repsCompleted: log.repsCompleted,
            weightAdded: log.weightAdded,
            restTimeTakenSeconds: log.restTimeSeconds,
            durationSeconds: log.durationSeconds,
          ),
        );
      }
    }

    await _dbService.insertHistoryExercises(exercisesToSave);
    await _dbService.insertHistorySets(setsToSave);

    _isSessionOfTheDayCompleted = true;
    updateProgress(_progress.copyWith(isSaved: true, stats: finalStats));
  }
}
