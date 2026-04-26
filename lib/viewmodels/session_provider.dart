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
  List<Program> _allPrograms = [];
  Session? _sessionOfTheDay;
  SessionProgress _progress = SessionProgress();
  bool _isSessionOfTheDayCompleted = false;

  List<Session> get allSessions => _allSessions;
  List<Program> get allPrograms => _allPrograms;
  Session? get sessionOfTheDay => _sessionOfTheDay;
  SessionProgress get progress => _progress;
  bool get isSessionOfTheDayCompleted => _isSessionOfTheDayCompleted;
  bool get keepAwake => _progressRepo.keepAwake;

  SessionProvider(this._progressRepo) {
    _progress = _progressRepo
        .currentProgress; // Synchronous initialization prevents reset bug on restart
    _loadData();
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

  Future<void> _loadData() async {
    _allSessions = await _dbService.getAllSessions();
    _allPrograms = await _dbService.getAllPrograms();
    await _calculateSessionOfTheDay();
    await _checkIfSessionCompletedToday();
    notifyListeners();
  }

  Session? getSessionById(String id) {
    try {
      return _allSessions.firstWhere((s) => s.id == id);
    } catch (_) {}

    for (var p in _allPrograms) {
      for (var w in p.weeks) {
        try {
          return w.sessions.firstWhere((s) => s.id == id);
        } catch (_) {}
      }
    }
    return null;
  }

  Future<void> _calculateSessionOfTheDay() async {
    _sessionOfTheDay = null;
    final now = DateTime.now();
    final currentDay = Day.values[now.weekday - 1];

    Program? activeProgram;
    try {
      activeProgram = _allPrograms.firstWhere((p) => p.isActive);
    } catch (_) {
      activeProgram = null;
    }

    if (activeProgram != null) {
      for (var week in activeProgram.weeks) {
        bool weekHasUncompleted = false;
        Session? candidateForToday;

        for (var session in week.sessions) {
          if (!activeProgram.completedSessionIds.contains(session.id)) {
            weekHasUncompleted = true;
            if (session.day == currentDay) {
              candidateForToday = session;
            }
          }
        }

        if (weekHasUncompleted) {
          if (candidateForToday != null) {
            _sessionOfTheDay = candidateForToday;
          }
          break;
        }
      }
    } else {
      try {
        _sessionOfTheDay = _allSessions.firstWhere((s) => s.day == currentDay);
      } catch (e) {
        _sessionOfTheDay = null;
      }
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
    if (_progressRepo.keepAwake) WakelockPlus.enable();
    final newProgress = _progress.copyWith(
      startTime: DateTime.now().millisecondsSinceEpoch,
      sessionId: sessionId,
    );
    _progressRepo.saveProgress(newProgress);

    final forcedSession = getSessionById(sessionId);
    if (forcedSession != null) {
      _sessionOfTheDay = forcedSession;
    }
    notifyListeners();
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
    if (_progressRepo.keepAwake) WakelockPlus.disable();
    _progressRepo.clearProgress();
    _calculateSessionOfTheDay();
    notifyListeners();
  }

  // ==========================================
  // PROGRAM OPERATIONS
  // ==========================================

  Future<void> addProgram(Program newProgram) async {
    await _dbService.insertProgram(newProgram);
    await _loadData();
  }

  Future<void> updateProgram(Program updatedProgram) async {
    await _dbService.insertProgram(updatedProgram);
    await _loadData();
  }

  Future<void> deleteProgram(String programId) async {
    await _dbService.deleteProgram(programId);
    await _loadData();
  }

  Future<void> toggleProgramActive(String programId, bool isActive) async {
    if (isActive) {
      for (var p in _allPrograms) {
        if (p.id != programId && p.isActive) {
          p.isActive = false;
          await _dbService.insertProgram(p);
        }
      }
    }
    final progIndex = _allPrograms.indexWhere((p) => p.id == programId);
    if (progIndex != -1) {
      _allPrograms[progIndex].isActive = isActive;
      await _dbService.insertProgram(_allPrograms[progIndex]);
    }
    await _loadData();
  }

  // ==========================================
  // SESSION & EXERCISE OPERATIONS
  // ==========================================

  Future<void> addSession(Session newSession) async {
    await _dbService.insertSession(newSession);
    await _loadData();
  }

  Future<void> updateSession(Session updatedSession) async {
    int sIdx = _allSessions.indexWhere((s) => s.id == updatedSession.id);
    if (sIdx != -1) {
      await _dbService.insertSession(updatedSession);
      await _loadData();
      return;
    }

    for (var p in _allPrograms) {
      for (var w in p.weeks) {
        int wSidx = w.sessions.indexWhere((s) => s.id == updatedSession.id);
        if (wSidx != -1) {
          w.sessions[wSidx] = updatedSession;
          await updateProgram(p);
          return;
        }
      }
    }
  }

  Future<void> deleteSession(String sessionId) async {
    int sIdx = _allSessions.indexWhere((s) => s.id == sessionId);
    if (sIdx != -1) {
      await _dbService.deleteSession(sessionId);
    } else {
      for (var p in _allPrograms) {
        for (var w in p.weeks) {
          if (w.sessions.any((s) => s.id == sessionId)) {
            w.sessions.removeWhere((s) => s.id == sessionId);
            await updateProgram(p);
            return;
          }
        }
      }
    }
    await _loadData();
  }

  Future<void> addExercise(String sessionId, Exercise newExercise) async {
    final session = getSessionById(sessionId);
    if (session != null) {
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
    final session = getSessionById(sessionId);
    if (session != null) {
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
    final session = getSessionById(sessionId);
    if (session != null) {
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
    final session = getSessionById(sessionId);
    if (session != null) {
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
    final session = getSessionById(sessionId);
    if (session == null) return;

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

  // ==========================================
  // IMPORTS (SESSION & PROGRAMME)
  // ==========================================

  Future<void> _extractAssetsFromExercises(List<Exercise> exercises) async {
    final existingAssets = await _dbService.getAllAssets();
    final existingConditions = await _dbService.getAllConditions();

    for (final ex in exercises) {
      if (ex.condition != null) {
        final cond = ex.condition!;
        bool condExists = existingConditions.any(
          (c) =>
              c.name.trim().toLowerCase() == cond.name.trim().toLowerCase() &&
              c.type == cond.type,
        );

        if (!condExists) {
          await _dbService.insertCondition(cond);
          existingConditions.add(cond);
        }
      }

      final exType = _getTypeFromExercise(ex);
      if (exType != ExerciseType.restBlock) {
        bool assetExists = existingAssets.any(
          (a) =>
              a.name.trim().toLowerCase() == ex.name.trim().toLowerCase() &&
              a.type == exType,
        );

        if (!assetExists) {
          final newAsset = AssetExercise(
            name: ex.name.trim(),
            type: exType,
            condition: ex.condition,
          );
          await _dbService.insertAsset(newAsset);
          existingAssets.add(newAsset);
        }
      }
    }
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
      await _extractAssetsFromExercises(newSession.exercises);
      await addSession(newSession);
    } catch (e) {
      debugPrint("Error importing session: $e");
      rethrow;
    }
  }

  Future<void> importProgramFromJson(String jsonString) async {
    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      map['id'] = const Uuid().v4();
      map['isActive'] = 0;
      map['completedSessionIds'] = jsonEncode([]);

      if (map['weeks'] != null) {
        final weeksList = jsonDecode(map['weeks']) as List;
        for (var w in weeksList) {
          if (w is Map<String, dynamic>) {
            w['id'] = const Uuid().v4();
            if (w['sessions'] != null) {
              final sessList = jsonDecode(w['sessions']) as List;
              for (var s in sessList) {
                if (s is Map<String, dynamic>) {
                  s['id'] = const Uuid().v4();
                  if (s['exercises'] != null) {
                    final exList = jsonDecode(s['exercises']) as List;
                    for (var ex in exList) {
                      if (ex is Map<String, dynamic>) {
                        ex['id'] = const Uuid().v4();
                      }
                    }
                    s['exercises'] = jsonEncode(exList);
                  }
                }
              }
              w['sessions'] = jsonEncode(sessList);
            }
          }
        }
        map['weeks'] = jsonEncode(weeksList);
      }

      final newProgram = Program.fromMap(map);

      for (final week in newProgram.weeks) {
        for (final session in week.sessions) {
          await _extractAssetsFromExercises(session.exercises);
        }
      }

      await addProgram(newProgram);
    } catch (e) {
      debugPrint("Error importing program: $e");
      rethrow;
    }
  }

  Future<void> saveCompletedWorkout(
    Session session,
    int durationMillis,
    List<WorkoutLogEntry> logs,
  ) async {
    if (_progress.isSaved) return;

    _progress = _progress.copyWith(isSaved: true);
    final historySessionId = const Uuid().v4();
    List<String> finalStats = List.from(_progress.stats);

    if (_progressRepo.keepAwake) WakelockPlus.disable();

    final historySession = HistorySession(
      id: historySessionId,
      originalSessionId: session.id,
      title: session.title,
      date: DateTime.now().millisecondsSinceEpoch,
      durationMillis: durationMillis,
      isCompleted: true,
    );
    await _dbService.insertHistorySession(historySession);

    try {
      final activeProg = _allPrograms.firstWhere((p) => p.isActive);
      bool isPartOfProgram = false;
      for (var w in activeProg.weeks) {
        if (w.sessions.any((s) => s.id == session.id)) {
          isPartOfProgram = true;
          break;
        }
      }
      if (isPartOfProgram &&
          !activeProg.completedSessionIds.contains(session.id)) {
        activeProg.completedSessionIds.add(session.id);
        await _dbService.insertProgram(activeProg);
      }
    } catch (_) {}

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

    await _loadData();
    updateProgress(_progress.copyWith(isSaved: true, stats: finalStats));
  }

  ExerciseType _getTypeFromExercise(Exercise ex) {
    if (ex is Classic) return ExerciseType.classic;
    if (ex is Pyramid) return ExerciseType.pyramid;
    if (ex is Amrap) return ExerciseType.amrap;
    if (ex is Emom) return ExerciseType.emom;
    if (ex is MultiEmom) return ExerciseType.multiEmom;
    if (ex is RestPause) return ExerciseType.restPause;
    if (ex is Cluster) return ExerciseType.cluster;
    if (ex is Circuit) return ExerciseType.circuit;
    if (ex is IsoMax) return ExerciseType.isoMax;
    if (ex is IsoPositions) return ExerciseType.isoPositions;
    if (ex is FreeTime) return ExerciseType.freeTime;
    return ExerciseType.restBlock;
  }
}
