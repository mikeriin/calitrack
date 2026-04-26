// lib/services/progress_repository.dart

import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workout_models.dart';

class WorkoutLogEntry {
  final String exerciseName;
  final ExerciseType exerciseType;
  final int setIndex;
  final int repsCompleted;
  final double weightAdded;
  final int restTimeSeconds;
  final int durationSeconds;

  WorkoutLogEntry({
    required this.exerciseName,
    required this.exerciseType,
    required this.setIndex,
    required this.repsCompleted,
    this.weightAdded = 0.0,
    this.restTimeSeconds = 0,
    this.durationSeconds = 0,
  });

  Map<String, dynamic> toMap() => {
    'exerciseName': exerciseName,
    'exerciseType': exerciseType.name,
    'setIndex': setIndex,
    'repsCompleted': repsCompleted,
    'weightAdded': weightAdded,
    'restTimeSeconds': restTimeSeconds,
    'durationSeconds': durationSeconds,
  };

  factory WorkoutLogEntry.fromMap(Map<String, dynamic> map) {
    return WorkoutLogEntry(
      exerciseName: map['exerciseName'],
      exerciseType: ExerciseType.values.firstWhere(
        (e) => e.name == map['exerciseType'],
      ),
      setIndex: map['setIndex'],
      repsCompleted: map['repsCompleted'],
      weightAdded: map['weightAdded']?.toDouble() ?? 0.0,
      restTimeSeconds: map['restTimeSeconds'] ?? 0,
      durationSeconds: map['durationSeconds'] ?? 0,
    );
  }
}

class SessionProgress {
  final String sessionId;
  final int currentExIdx;
  final int currentSetIdx;
  final bool isResting;
  final int restEndTime;
  final int startTime;
  final int endTime;
  final bool isFinished;
  final bool isSaved;
  final List<String> stats;
  final List<WorkoutLogEntry> logs;
  final Map<String, dynamic>
  activeExState; // <-- NOUVEAU: Sauvegarde l'état local de l'exo en cours

  SessionProgress({
    this.sessionId = "",
    this.currentExIdx = 0,
    this.currentSetIdx = 1,
    this.isResting = false,
    this.restEndTime = 0,
    this.startTime = 0,
    this.endTime = 0,
    this.isFinished = false,
    this.isSaved = false,
    this.stats = const [],
    this.logs = const [],
    this.activeExState = const {}, // Initialisation par défaut
  });

  SessionProgress copyWith({
    String? sessionId,
    int? currentExIdx,
    int? currentSetIdx,
    bool? isResting,
    int? restEndTime,
    int? startTime,
    int? endTime,
    bool? isFinished,
    bool? isSaved,
    List<String>? stats,
    List<WorkoutLogEntry>? logs,
    Map<String, dynamic>? activeExState,
  }) {
    return SessionProgress(
      sessionId: sessionId ?? this.sessionId,
      currentExIdx: currentExIdx ?? this.currentExIdx,
      currentSetIdx: currentSetIdx ?? this.currentSetIdx,
      isResting: isResting ?? this.isResting,
      restEndTime: restEndTime ?? this.restEndTime,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isFinished: isFinished ?? this.isFinished,
      isSaved: isSaved ?? this.isSaved,
      stats: stats ?? this.stats,
      logs: logs ?? this.logs,
      activeExState: activeExState ?? this.activeExState,
    );
  }
}

class ProgressRepository {
  static const _sessionIdKey = 'session_id';
  static const _exIdxKey = 'current_ex_idx';
  static const _setIdxKey = 'current_set_idx';
  static const _isRestingKey = 'is_resting';
  static const _restEndTimeKey = 'rest_end_time';
  static const _startTimeKey = 'session_start_time';
  static const _endTimeKey = 'session_end_time';
  static const _isFinishedKey = 'is_finished';
  static const _isSavedKey = 'is_saved';
  static const _statsKey = 'stats_json';
  static const _logsKey = 'logs_json';
  static const _activeExStateKey = 'active_ex_state'; // <-- NOUVELLE CLÉ

  static const _isDarkModeKey = 'is_dark_mode';
  static const _dataFolderKey = 'data_folder_path';
  static const _garminLinkedKey = 'garmin_linked';
  static const _notificationsKey = 'daily_notifications';
  static const _keepAwakeKey = 'keep_awake_active';

  final _progressController = StreamController<SessionProgress>.broadcast();
  final _darkModeController = StreamController<bool>.broadcast();
  final _settingsController = StreamController<void>.broadcast();

  Stream<SessionProgress> get progressFlow => _progressController.stream;
  Stream<bool> get isDarkModeFlow => _darkModeController.stream;
  Stream<void> get settingsFlow => _settingsController.stream;

  SessionProgress _currentProgress = SessionProgress();
  SessionProgress get currentProgress => _currentProgress;

  bool _isDarkMode = true;
  bool get isDarkMode => _isDarkMode;

  String? dataFolder;
  bool isGarminLinked = false;
  bool dailyNotifications = false;
  bool keepAwake = false;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    _isDarkMode = prefs.getBool(_isDarkModeKey) ?? true;
    dataFolder = prefs.getString(_dataFolderKey);
    isGarminLinked = prefs.getBool(_garminLinkedKey) ?? false;
    dailyNotifications = prefs.getBool(_notificationsKey) ?? false;
    keepAwake = prefs.getBool(_keepAwakeKey) ?? false;

    _darkModeController.add(_isDarkMode);
    _currentProgress = await _readProgressFromPrefs();
    _progressController.add(_currentProgress);
  }

  Future<SessionProgress> _readProgressFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    List<String> statsList = [];
    final statsJson = prefs.getString(_statsKey);
    if (statsJson != null) {
      statsList = List<String>.from(jsonDecode(statsJson));
    }

    List<WorkoutLogEntry> logsList = [];
    final logsJson = prefs.getString(_logsKey);
    if (logsJson != null) {
      final decoded = jsonDecode(logsJson) as List;
      logsList = decoded.map((e) => WorkoutLogEntry.fromMap(e)).toList();
    }

    Map<String, dynamic> activeState = {};
    final activeStateJson = prefs.getString(_activeExStateKey);
    if (activeStateJson != null) {
      activeState = Map<String, dynamic>.from(jsonDecode(activeStateJson));
    }

    return SessionProgress(
      sessionId: prefs.getString(_sessionIdKey) ?? "",
      currentExIdx: prefs.getInt(_exIdxKey) ?? 0,
      currentSetIdx: prefs.getInt(_setIdxKey) ?? 1,
      isResting: prefs.getBool(_isRestingKey) ?? false,
      restEndTime: prefs.getInt(_restEndTimeKey) ?? 0,
      startTime: prefs.getInt(_startTimeKey) ?? 0,
      endTime: prefs.getInt(_endTimeKey) ?? 0,
      isFinished: prefs.getBool(_isFinishedKey) ?? false,
      isSaved: prefs.getBool(_isSavedKey) ?? false,
      stats: statsList,
      logs: logsList,
      activeExState: activeState,
    );
  }

  Future<void> saveProgress(SessionProgress progress) async {
    _currentProgress = progress;
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_sessionIdKey, progress.sessionId);
    await prefs.setInt(_exIdxKey, progress.currentExIdx);
    await prefs.setInt(_setIdxKey, progress.currentSetIdx);
    await prefs.setBool(_isRestingKey, progress.isResting);
    await prefs.setInt(_restEndTimeKey, progress.restEndTime);
    await prefs.setInt(_startTimeKey, progress.startTime);
    await prefs.setInt(_endTimeKey, progress.endTime);
    await prefs.setBool(_isFinishedKey, progress.isFinished);
    await prefs.setBool(_isSavedKey, progress.isSaved);
    await prefs.setString(_statsKey, jsonEncode(progress.stats));
    await prefs.setString(
      _activeExStateKey,
      jsonEncode(progress.activeExState),
    ); // <-- SAUVEGARDE DE L'ÉTAT LOCAL
    await prefs.setString(
      _logsKey,
      jsonEncode(progress.logs.map((e) => e.toMap()).toList()),
    );

    _progressController.add(progress);
  }

  Future<void> clearProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final keysToRemove = [
      _sessionIdKey,
      _exIdxKey,
      _setIdxKey,
      _isRestingKey,
      _restEndTimeKey,
      _startTimeKey,
      _endTimeKey,
      _isFinishedKey,
      _isSavedKey,
      _statsKey,
      _logsKey,
      _activeExStateKey, // <-- PURGE DE L'ÉTAT LOCAL
    ];
    for (String key in keysToRemove) {
      await prefs.remove(key);
    }
    _currentProgress = SessionProgress();
    _progressController.add(_currentProgress);
  }

  Future<void> setDarkMode(bool isDark) async {
    _isDarkMode = isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isDarkModeKey, isDark);
    _darkModeController.add(isDark);
  }

  Future<void> setDataFolder(String? path) async {
    dataFolder = path;
    final prefs = await SharedPreferences.getInstance();
    if (path != null) {
      await prefs.setString(_dataFolderKey, path);
    } else {
      await prefs.remove(_dataFolderKey);
    }
    _settingsController.add(null);
  }

  Future<void> setGarminLinked(bool linked) async {
    isGarminLinked = linked;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_garminLinkedKey, linked);
    _settingsController.add(null);
  }

  Future<void> setDailyNotifications(bool enabled) async {
    dailyNotifications = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, enabled);
    _settingsController.add(null);
  }

  Future<void> setKeepAwake(bool keep) async {
    keepAwake = keep;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keepAwakeKey, keep);
    _settingsController.add(null);
  }
}
