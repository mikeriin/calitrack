import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/workout_models.dart';

// ==========================================
// CLASSES DE REGROUPEMENT (Relations)
// ==========================================

class HistoryExerciseWithSets {
  final HistoryExercise exercise;
  final List<HistorySet> sets;

  HistoryExerciseWithSets({required this.exercise, required this.sets});
}

class FullHistorySession {
  final HistorySession session;
  final List<HistoryExerciseWithSets> exercises;

  FullHistorySession({required this.session, required this.exercises});
}

// ==========================================
// SERVICE DE BASE DE DONNEES (Singleton)
// ==========================================

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'calitrack_database.db');

    return await openDatabase(
      path,
      version: 3, // Montée de version suite à l'ajout de targetSets
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await db.execute('DROP TABLE IF EXISTS progression_conditions');
          await db.execute('DROP TABLE IF EXISTS conditions');

          await db.execute('''
              CREATE TABLE progression_conditions (
                id TEXT PRIMARY KEY,
                name TEXT,
                type TEXT,
                targetSets INTEGER,
                targetReps INTEGER,
                weightIncrement REAL
              )
            ''');
          await db.execute('''
              CREATE TABLE conditions (
                id TEXT PRIMARY KEY,
                name TEXT,
                type TEXT,
                targetSets INTEGER,
                targetReps INTEGER,
                weightIncrement REAL
              )
            ''');
        }
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sessions (
            id TEXT PRIMARY KEY,
            title TEXT,
            day TEXT,
            exercices TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE history_sessions (
            id TEXT PRIMARY KEY,
            originalSessionId TEXT,
            title TEXT,
            date INTEGER,
            durationMillis INTEGER,
            isCompleted INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE history_exercises (
            id TEXT PRIMARY KEY,
            historySessionId TEXT,
            name TEXT,
            type TEXT,
            FOREIGN KEY (historySessionId) REFERENCES history_sessions (id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE history_sets (
            id TEXT PRIMARY KEY,
            historyExerciseId TEXT,
            setIndex INTEGER,
            repsCompleted INTEGER,
            weightAdded REAL,
            restTimeTakenSeconds INTEGER,
            durationSeconds INTEGER,
            FOREIGN KEY (historyExerciseId) REFERENCES history_exercises (id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE assets_exercises (
            id TEXT PRIMARY KEY,
            name TEXT,
            type TEXT,
            imageUrl TEXT,
            condition TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE progression_conditions (
            id TEXT PRIMARY KEY,
            name TEXT,
            type TEXT,
            targetSets INTEGER,
            targetReps INTEGER,
            weightIncrement REAL
          )
        ''');

        await db.execute('''
          CREATE TABLE conditions (
            id TEXT PRIMARY KEY,
            name TEXT,
            type TEXT,
            targetSets INTEGER,
            targetReps INTEGER,
            weightIncrement REAL
          )
        ''');
      },
    );
  }

  // ==========================================
  // DAO : SESSIONS (Programmes en cours)
  // ==========================================

  Future<void> insertSession(Session session) async {
    final db = await database;
    await db.insert(
      'sessions',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Session>> getAllSessions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('sessions');
    return maps.map((map) => Session.fromMap(map)).toList();
  }

  Future<void> deleteSession(String sessionId) async {
    final db = await database;
    await db.delete('sessions', where: 'id = ?', whereArgs: [sessionId]);
  }

  // ==========================================
  // DAO : HISTORIQUE (Tracker)
  // ==========================================

  Future<void> insertHistorySession(HistorySession session) async {
    final db = await database;
    await db.insert(
      'history_sessions',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<HistorySession>> getAllHistorySessions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('history_sessions');
    return maps.map((map) => HistorySession.fromMap(map)).toList();
  }

  Future<void> insertHistoryExercises(List<HistoryExercise> exercises) async {
    final db = await database;
    Batch batch = db.batch();
    for (var exercise in exercises) {
      batch.insert(
        'history_exercises',
        exercise.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> insertHistorySets(List<HistorySet> sets) async {
    final db = await database;
    Batch batch = db.batch();
    for (var set in sets) {
      batch.insert(
        'history_sets',
        set.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<FullHistorySession>> getAllFullHistory() async {
    final db = await database;

    final List<Map<String, dynamic>> sessionMaps = await db.query(
      'history_sessions',
      orderBy: 'date DESC',
    );
    final sessions = sessionMaps
        .map((map) => HistorySession.fromMap(map))
        .toList();

    List<FullHistorySession> fullHistory = [];

    // 2. Pour chaque session, récupérer ses exercices et ses séries
    for (var session in sessions) {
      final List<Map<String, dynamic>> exerciseMaps = await db.query(
        'history_exercises',
        where: 'historySessionId = ?',
        whereArgs: [session.id],
      );
      final exercises = exerciseMaps
          .map((map) => HistoryExercise.fromMap(map))
          .toList();

      List<HistoryExerciseWithSets> exercisesWithSets = [];

      for (var exercise in exercises) {
        final List<Map<String, dynamic>> setMaps = await db.query(
          'history_sets',
          where: 'historyExerciseId = ?',
          whereArgs: [exercise.id],
        );
        final sets = setMaps.map((map) => HistorySet.fromMap(map)).toList();

        exercisesWithSets.add(
          HistoryExerciseWithSets(exercise: exercise, sets: sets),
        );
      }

      fullHistory.add(
        FullHistorySession(session: session, exercises: exercisesWithSets),
      );
    }

    return fullHistory;
  }

  Future<void> deleteHistorySession(String sessionId) async {
    final db = await database;
    await db.delete(
      'history_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> clearAllHistory() async {
    final db = await database;
    await db.delete('history_sessions');
  }

  Future<void> deleteHistoryExercise(String exerciseId) async {
    final db = await database;
    await db.delete(
      'history_exercises',
      where: 'id = ?',
      whereArgs: [exerciseId],
    );
  }

  // ==========================================
  // DAO : ASSETS
  // ==========================================

  Future<void> insertAsset(AssetExercise asset) async {
    final db = await database;
    await db.insert(
      'assets_exercises',
      asset.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AssetExercise>> getAllAssets() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('assets_exercises');
    return maps.map((map) => AssetExercise.fromMap(map)).toList();
  }

  Future<void> deleteAsset(String id) async {
    final db = await database;
    await db.delete('assets_exercises', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================
  // DAO : CONDITIONS (Progression)
  // ==========================================

  Future<void> insertCondition(ProgressionCondition condition) async {
    final db = await database;
    await db.insert(
      'progression_conditions',
      condition.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ProgressionCondition>> getAllConditions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'progression_conditions',
    );
    return maps.map((map) => ProgressionCondition.fromMap(map)).toList();
  }

  Future<void> deleteCondition(String id) async {
    final db = await database;
    await db.delete('progression_conditions', where: 'id = ?', whereArgs: [id]);
  }
}
