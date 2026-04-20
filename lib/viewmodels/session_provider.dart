import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/workout_models.dart';
import '../services/database_service.dart';
import '../services/progress_repository.dart';

class SessionProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final ProgressRepository _progressRepo;
  late StreamSubscription _progressSub;

  // --- ETATS ---
  List<Session> _allSessions = [];
  Session? _sessionOfTheDay;
  SessionProgress _progress = SessionProgress();
  bool _isSessionOfTheDayCompleted = false;

  List<Session> get allSessions => _allSessions;
  Session? get sessionOfTheDay => _sessionOfTheDay;
  SessionProgress get progress => _progress;
  bool get isSessionOfTheDayCompleted => _isSessionOfTheDayCompleted;

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

  // --- LECTURE ---
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

  // --- GESTION DU CHRONO ET PROGRESSION ---
  void startSession(String sessionId) {
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
    _progressRepo.clearProgress();
  }

  // --- CRUD SESSIONS & EXERCICES ---
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

  Future<void> addExercice(String sessionId, Exercice newExercise) async {
    final sessionIndex = _allSessions.indexWhere((s) => s.id == sessionId);
    if (sessionIndex != -1) {
      final session = _allSessions[sessionIndex];
      final updatedExercices = List<Exercice>.from(session.exercices)
        ..add(newExercise);
      final updatedSession = Session(
        id: session.id,
        title: session.title,
        day: session.day,
        exercices: updatedExercices,
      );
      await updateSession(updatedSession);
    }
  }

  Future<void> deleteExercice(String sessionId, String exerciceId) async {
    final sessionIndex = _allSessions.indexWhere((s) => s.id == sessionId);
    if (sessionIndex != -1) {
      final session = _allSessions[sessionIndex];
      final updatedExercices = session.exercices
          .where((e) => e.id != exerciceId)
          .toList();
      final updatedSession = Session(
        id: session.id,
        title: session.title,
        day: session.day,
        exercices: updatedExercices,
      );
      await updateSession(updatedSession);
    }
  }

  Future<void> updateExercice(
    String sessionId,
    Exercice updatedExercise,
  ) async {
    final sessionIndex = _allSessions.indexWhere((s) => s.id == sessionId);
    if (sessionIndex != -1) {
      final session = _allSessions[sessionIndex];
      final updatedExercices = session.exercices.map((e) {
        return e.id == updatedExercise.id ? updatedExercise : e;
      }).toList();
      final updatedSession = Session(
        id: session.id,
        title: session.title,
        day: session.day,
        exercices: updatedExercices,
      );
      await updateSession(updatedSession);
    }
  }

  Future<void> updateExercicesOrder(
    String sessionId,
    List<Exercice> newOrder,
  ) async {
    final sessionIndex = _allSessions.indexWhere((s) => s.id == sessionId);
    if (sessionIndex != -1) {
      final session = _allSessions[sessionIndex];
      final updatedSession = Session(
        id: session.id,
        title: session.title,
        day: session.day,
        exercices: newOrder,
      );
      await updateSession(updatedSession);
    }
  }

  // --- NETTOYAGE INTELLIGENT ---
  Future<void> cleanSession(String sessionId) async {
    final sessionIndex = _allSessions.indexWhere((s) => s.id == sessionId);
    if (sessionIndex == -1) return;

    final session = _allSessions[sessionIndex];
    List<Exercice> rawExercices = List.from(session.exercices);
    List<Exercice> cleaned = [];

    for (int i = 0; i < rawExercices.length; i++) {
      final currentEx = rawExercices[i];

      // Règle 1 : Fusionner les chronos RestBlock consécutifs
      if (currentEx is RestBlock) {
        if (cleaned.isNotEmpty && cleaned.last is RestBlock) {
          final previousRest = cleaned.removeLast() as RestBlock;
          final mergedRest = RestBlock(
            id: previousRest.id, // On garde le premier ID
            restSeconds: previousRest.restSeconds + currentEx.restSeconds,
          );
          cleaned.add(mergedRest);
        } else {
          cleaned.add(currentEx);
        }
      } else {
        cleaned.add(currentEx);
      }
    }

    // Règle 2 : Supprimer le(s) RestBlock à la toute fin de la séance
    while (cleaned.isNotEmpty && cleaned.last is RestBlock) {
      cleaned.removeLast();
    }

    final updatedSession = Session(
      id: session.id,
      title: session.title,
      day: session.day,
      exercices: cleaned,
    );

    await updateSession(updatedSession);
  }

  // --- LOGIQUE CONDITIONS ---
  Future<void> applyConditionToSession(
    String sessionId,
    ProgressionCondition condition,
  ) async {
    final sessionIndex = _allSessions.indexWhere((s) => s.id == sessionId);
    if (sessionIndex != -1) {
      final session = _allSessions[sessionIndex];
      // On applique la condition à tous les exercices de la session actuelle
      final updatedExercices = session.exercices
          .map((e) => e.copyWithCondition(condition))
          .toList();

      final updatedSession = Session(
        id: session.id,
        title: session.title,
        day: session.day,
        exercices: updatedExercices,
      );
      await updateSession(updatedSession);
    }
  }

  // --- SAUVEGARDE FINALE DE L'HISTORIQUE ---
  Future<void> saveCompletedWorkout(
    Session session,
    int durationMillis,
    List<WorkoutLogEntry> logs,
  ) async {
    final historySessionId = const Uuid().v4();

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
    updateProgress(_progress.copyWith(isSaved: true));
  }
}
