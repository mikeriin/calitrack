import 'dart:convert';
import 'package:uuid/uuid.dart';

const uuid = Uuid();

// ==========================================
// ENUMS
// ==========================================

enum ExerciseType {
  classic("CLASSIC (Sets/Reps)"),
  pyramid("PYRAMID (Up/Down/Up&Down)"),
  amrap("AMRAP (Time Limit)"),
  emom("EMOM (Intervals)"),
  multiEmom("MULTI-EMOM (Circuit)"),
  restPause("REST-PAUSE (Max Reps)"),
  cluster("CLUSTER (For Time)"),
  circuit("CIRCUIT (Multi-exercise)"),
  isoMax("ISOMETRIC (Max Hold)"),
  isoPositions("ISOMETRIC (Multi-Hold)"),
  restBlock("REST BLOCK (Custom Timer)");

  final String label;
  const ExerciseType(this.label);
}

enum PyramidType {
  up("Up"),
  down("Down"),
  upAndDown("Up & Down");

  final String label;
  const PyramidType(this.label);
}

enum Day {
  monday("Monday"),
  tuesday("Tuesday"),
  wednesday("Wednesday"),
  thursday("Thursday"),
  friday("Friday"),
  saturday("Saturday"),
  sunday("Sunday");

  final String dayOut;
  const Day(this.dayOut);
}

// ==========================================
// PROGRESSION CONDITIONS (Progression Science)
// ==========================================

enum ProgressionType {
  linearWeight("Linear Weight (+Kg)"),
  doubleProgression("Double Progression (Reps then Weight)"),
  volume("Volume Increment (+Sets)");

  final String label;
  const ProgressionType(this.label);
}

class ProgressionCondition {
  final String id;
  final String name;
  final ProgressionType type;
  final int targetSets;
  final int targetReps;
  final double weightIncrement;

  ProgressionCondition({
    String? id,
    required this.name,
    required this.type,
    required this.targetSets,
    required this.targetReps,
    required this.weightIncrement,
  }) : id = id ?? uuid.v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'targetSets': targetSets,
      'targetReps': targetReps,
      'weightIncrement': weightIncrement,
    };
  }

  factory ProgressionCondition.fromMap(Map<String, dynamic> map) {
    return ProgressionCondition(
      id: map['id'],
      name: map['name'],
      type: ProgressionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ProgressionType.linearWeight,
      ),
      targetSets: map['targetSets'] ?? 0,
      targetReps: map['targetReps'] ?? 0,
      weightIncrement: map['weightIncrement']?.toDouble() ?? 0.0,
    );
  }
}

// ==========================================
// BASE DATA CLASSES
// ==========================================

class SubExercise {
  final String name;
  final int reps;
  final double weight;

  SubExercise({required this.name, required this.reps, this.weight = 0.0});

  Map<String, dynamic> toMap() {
    return {'name': name, 'reps': reps, 'weight': weight};
  }

  factory SubExercise.fromMap(Map<String, dynamic> map) {
    return SubExercise(
      name: map['name'],
      reps: map['reps'],
      weight: map['weight']?.toDouble() ?? 0.0,
    );
  }
}

// ==========================================
// EXERCISE POLYMORPHISM (SEALED CLASS)
// ==========================================

sealed class Exercise {
  String get id;
  String get name;
  ProgressionCondition? get condition;

  Map<String, dynamic> toMap();

  Exercise copyWithCondition(ProgressionCondition? newCondition);

  factory Exercise.fromMap(Map<String, dynamic> map) {
    final type = map['type'] as String?;
    if (type == null) throw Exception("'type' missing from the JSON");

    ProgressionCondition? parsedCondition;
    if (map['condition'] != null) {
      final conditionMap = map['condition'] is String
          ? jsonDecode(map['condition'])
          : map['condition'];
      parsedCondition = ProgressionCondition.fromMap(conditionMap);
    }

    switch (type) {
      case 'Classic':
        return Classic(
          id: map['id'],
          name: map['name'],
          sets: map['sets'],
          reps: map['reps'],
          weight: map['weight']?.toDouble() ?? 0.0,
          rest: map['rest'] ?? 0,
          condition: parsedCondition,
        );
      case 'Amrap':
        return Amrap(
          id: map['id'],
          name: map['name'],
          timeCapMinutes: map['timeCapMinutes'],
          movements:
              (map['movements'] as List?)
                  ?.map((e) => SubExercise.fromMap(e))
                  .toList() ??
              [],
          condition: parsedCondition,
        );
      case 'Emom':
        return Emom(
          id: map['id'],
          name: map['name'],
          everyXSeconds: map['everyXSeconds'],
          totalRounds: map['totalRounds'],
          movements:
              (map['movements'] as List?)
                  ?.map((e) => SubExercise.fromMap(e))
                  .toList() ??
              [],
          condition: parsedCondition,
        );
      case 'RestPause':
        return RestPause(
          id: map['id'],
          name: map['name'],
          microSets: map['microSets'],
          restSeconds: map['restSeconds'],
          condition: parsedCondition,
        );
      case 'Cluster':
        return Cluster(
          id: map['id'],
          name: map['name'],
          targetReps: map['targetReps'],
          incrementFactor: map['incrementFactor'] ?? 1,
          condition: parsedCondition,
        );
      case 'Circuit':
        return Circuit(
          id: map['id'],
          name: map['name'],
          sets: map['sets'],
          restSeconds: map['restSeconds'],
          movements:
              (map['movements'] as List?)
                  ?.map((e) => SubExercise.fromMap(e))
                  .toList() ??
              [],
          condition: parsedCondition,
        );
      case 'IsoMax':
        return IsoMax(
          id: map['id'],
          name: map['name'],
          sets: map['sets'],
          weight: map['weight']?.toDouble() ?? 0.0,
          restSeconds: map['restSeconds'],
          condition: parsedCondition,
        );
      case 'IsoPositions':
        return IsoPositions(
          id: map['id'],
          name: map['name'],
          sets: map['sets'],
          restSeconds: map['restSeconds'],
          movements:
              (map['movements'] as List?)
                  ?.map((e) => SubExercise.fromMap(e))
                  .toList() ??
              [],
          condition: parsedCondition,
        );
      case 'RestBlock':
        return RestBlock(
          id: map['id'],
          name: map['name'] ?? "Rest",
          restSeconds: map['restSeconds'],
          condition: parsedCondition,
        );
      case 'Pyramid':
        return Pyramid(
          id: map['id'],
          name: map['name'],
          minReps: map['minReps'],
          maxReps: map['maxReps'],
          increment: map['increment'],
          weight: map['weight']?.toDouble() ?? 0.0,
          restSeconds: map['restSeconds'],
          pyramidType: PyramidType.values.firstWhere(
            (e) => e.name == map['pyramidType'],
            orElse: () => PyramidType.upAndDown,
          ),
          condition: parsedCondition,
        );
      case 'MultiEmom':
        return MultiEmom(
          id: map['id'],
          name: map['name'],
          everyXSeconds: map['everyXSeconds'] ?? 60,
          totalRounds: map['totalRounds'] ?? 1,
          minutes:
              (map['minutes'] as List?)
                  ?.map((e) => EmomMinuteGroup.fromMap(e))
                  .toList() ??
              [],
          condition: parsedCondition,
        );
      default:
        throw Exception("Unknown type: $type");
    }
  }
}

class Classic implements Exercise {
  @override
  final String id;
  @override
  final String name;
  @override
  final ProgressionCondition? condition;
  final int sets;
  final int reps;
  final double weight;
  final int rest;

  Classic({
    String? id,
    required this.name,
    required this.sets,
    required this.reps,
    this.weight = 0.0,
    this.rest = 0,
    this.condition,
  }) : id = id ?? uuid.v4();

  @override
  Classic copyWithCondition(ProgressionCondition? newCondition) {
    return Classic(
      id: id,
      name: name,
      sets: sets,
      reps: reps,
      weight: weight,
      rest: rest,
      condition: newCondition,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    'type': 'Classic',
    'id': id,
    'name': name,
    'sets': sets,
    'reps': reps,
    'weight': weight,
    'rest': rest,
    'condition': condition?.toMap(),
  };
}

class Amrap implements Exercise {
  @override
  final String id;
  @override
  final String name;
  @override
  final ProgressionCondition? condition;
  final int timeCapMinutes;
  final List<SubExercise> movements;

  Amrap({
    String? id,
    required this.name,
    required this.timeCapMinutes,
    this.movements = const [],
    this.condition,
  }) : id = id ?? uuid.v4();

  @override
  Amrap copyWithCondition(ProgressionCondition? newCondition) {
    return Amrap(
      id: id,
      name: name,
      timeCapMinutes: timeCapMinutes,
      movements: movements,
      condition: newCondition,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    'type': 'Amrap',
    'id': id,
    'name': name,
    'timeCapMinutes': timeCapMinutes,
    'movements': movements.map((e) => e.toMap()).toList(),
    'condition': condition?.toMap(),
  };
}

class Emom implements Exercise {
  @override
  final String id;
  @override
  final String name;
  @override
  final ProgressionCondition? condition;
  final int everyXSeconds;
  final int totalRounds;
  final List<SubExercise> movements;

  Emom({
    String? id,
    required this.name,
    required this.everyXSeconds,
    required this.totalRounds,
    this.movements = const [],
    this.condition,
  }) : id = id ?? uuid.v4();

  @override
  Emom copyWithCondition(ProgressionCondition? newCondition) {
    return Emom(
      id: id,
      name: name,
      everyXSeconds: everyXSeconds,
      totalRounds: totalRounds,
      movements: movements,
      condition: newCondition,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    'type': 'Emom',
    'id': id,
    'name': name,
    'everyXSeconds': everyXSeconds,
    'totalRounds': totalRounds,
    'movements': movements.map((e) => e.toMap()).toList(),
    'condition': condition?.toMap(),
  };
}

class EmomMinuteGroup {
  final int minuteIndex;
  final List<SubExercise> movements;

  EmomMinuteGroup({required this.minuteIndex, required this.movements});

  Map<String, dynamic> toMap() => {
    'minuteIndex': minuteIndex,
    'movements': movements.map((e) => e.toMap()).toList(),
  };

  factory EmomMinuteGroup.fromMap(Map<String, dynamic> map) {
    return EmomMinuteGroup(
      minuteIndex: map['minuteIndex'],
      movements: (map['movements'] as List)
          .map((e) => SubExercise.fromMap(e))
          .toList(),
    );
  }
}

class RestPause implements Exercise {
  @override
  final String id;
  @override
  final String name;
  @override
  final ProgressionCondition? condition;
  final int microSets;
  final int restSeconds;

  RestPause({
    String? id,
    required this.name,
    required this.microSets,
    required this.restSeconds,
    this.condition,
  }) : id = id ?? uuid.v4();

  @override
  RestPause copyWithCondition(ProgressionCondition? newCondition) {
    return RestPause(
      id: id,
      name: name,
      microSets: microSets,
      restSeconds: restSeconds,
      condition: newCondition,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    'type': 'RestPause',
    'id': id,
    'name': name,
    'microSets': microSets,
    'restSeconds': restSeconds,
    'condition': condition?.toMap(),
  };
}

class Cluster implements Exercise {
  @override
  final String id;
  @override
  final String name;
  @override
  final ProgressionCondition? condition;
  final int targetReps;
  final int incrementFactor;

  Cluster({
    String? id,
    required this.name,
    required this.targetReps,
    this.incrementFactor = 1,
    this.condition,
  }) : id = id ?? uuid.v4();

  @override
  Cluster copyWithCondition(ProgressionCondition? newCondition) {
    return Cluster(
      id: id,
      name: name,
      targetReps: targetReps,
      incrementFactor: incrementFactor,
      condition: newCondition,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    'type': 'Cluster',
    'id': id,
    'name': name,
    'targetReps': targetReps,
    'incrementFactor': incrementFactor,
    'condition': condition?.toMap(),
  };
}

class Circuit implements Exercise {
  @override
  final String id;
  @override
  final String name;
  @override
  final ProgressionCondition? condition;
  final int sets;
  final int restSeconds;
  final List<SubExercise> movements;

  Circuit({
    String? id,
    required this.name,
    required this.sets,
    required this.restSeconds,
    this.movements = const [],
    this.condition,
  }) : id = id ?? uuid.v4();

  @override
  Circuit copyWithCondition(ProgressionCondition? newCondition) {
    return Circuit(
      id: id,
      name: name,
      sets: sets,
      restSeconds: restSeconds,
      movements: movements,
      condition: newCondition,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    'type': 'Circuit',
    'id': id,
    'name': name,
    'sets': sets,
    'restSeconds': restSeconds,
    'movements': movements.map((e) => e.toMap()).toList(),
    'condition': condition?.toMap(),
  };
}

class IsoMax implements Exercise {
  @override
  final String id;
  @override
  final String name;
  @override
  final ProgressionCondition? condition;
  final int sets;
  final double weight;
  final int restSeconds;

  IsoMax({
    String? id,
    required this.name,
    required this.sets,
    this.weight = 0.0,
    required this.restSeconds,
    this.condition,
  }) : id = id ?? uuid.v4();

  @override
  IsoMax copyWithCondition(ProgressionCondition? newCondition) {
    return IsoMax(
      id: id,
      name: name,
      sets: sets,
      weight: weight,
      restSeconds: restSeconds,
      condition: newCondition,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    'type': 'IsoMax',
    'id': id,
    'name': name,
    'sets': sets,
    'weight': weight,
    'restSeconds': restSeconds,
    'condition': condition?.toMap(),
  };
}

class IsoPositions implements Exercise {
  @override
  final String id;
  @override
  final String name;
  @override
  final ProgressionCondition? condition;
  final int sets;
  final int restSeconds;
  final List<SubExercise> movements;

  IsoPositions({
    String? id,
    required this.name,
    required this.sets,
    required this.restSeconds,
    this.movements = const [],
    this.condition,
  }) : id = id ?? uuid.v4();

  @override
  IsoPositions copyWithCondition(ProgressionCondition? newCondition) {
    return IsoPositions(
      id: id,
      name: name,
      sets: sets,
      restSeconds: restSeconds,
      movements: movements,
      condition: newCondition,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    'type': 'IsoPositions',
    'id': id,
    'name': name,
    'sets': sets,
    'restSeconds': restSeconds,
    'movements': movements.map((e) => e.toMap()).toList(),
    'condition': condition?.toMap(),
  };
}

class RestBlock implements Exercise {
  @override
  final String id;
  @override
  final String name;
  @override
  final ProgressionCondition? condition;
  final int restSeconds;

  RestBlock({
    String? id,
    this.name = "Rest",
    required this.restSeconds,
    this.condition,
  }) : id = id ?? uuid.v4();

  @override
  RestBlock copyWithCondition(ProgressionCondition? newCondition) {
    return RestBlock(
      id: id,
      name: name,
      restSeconds: restSeconds,
      condition: newCondition,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    'type': 'RestBlock',
    'id': id,
    'name': name,
    'restSeconds': restSeconds,
    'condition': condition?.toMap(),
  };
}

// ==========================================
// SESSION MODELS
// ==========================================

class Session {
  final String id;
  final String title;
  final Day day;
  final List<Exercise> exercises;

  Session({
    String? id,
    required this.title,
    required this.day,
    this.exercises = const [],
  }) : id = id ?? uuid.v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'day': day.name,
      'exercises': jsonEncode(exercises.map((e) => e.toMap()).toList()),
    };
  }

  factory Session.fromMap(Map<String, dynamic> map) {
    var exercisesList = <Exercise>[];
    if (map['exercises'] != null) {
      final decoded = jsonDecode(map['exercises']) as List;
      exercisesList = decoded
          .map((e) => Exercise.fromMap(e as Map<String, dynamic>))
          .toList();
    }

    return Session(
      id: map['id'],
      title: map['title'],
      day: Day.values.firstWhere(
        (d) => d.name == map['day'],
        orElse: () => Day.sunday,
      ),
      exercises: exercisesList,
    );
  }
}

// ==========================================
// HISTORY MODELS (SQLite)
// ==========================================

class HistorySession {
  final String id;
  final String originalSessionId;
  final String title;
  final int date;
  final int durationMillis;
  final bool isCompleted;

  HistorySession({
    String? id,
    required this.originalSessionId,
    required this.title,
    required this.date,
    required this.durationMillis,
    required this.isCompleted,
  }) : id = id ?? uuid.v4();

  String get formattedDuration {
    final int seconds = durationMillis ~/ 1000;
    final int h = seconds ~/ 3600;
    final int m = (seconds % 3600) ~/ 60;
    final int s = seconds % 60;
    if (h > 0) {
      return "${h}h ${m.toString().padLeft(2, '0')}m";
    } else {
      return "${m}m ${s.toString().padLeft(2, '0')}s";
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'originalSessionId': originalSessionId,
      'title': title,
      'date': date,
      'durationMillis': durationMillis,
      'isCompleted': isCompleted ? 1 : 0,
    };
  }

  factory HistorySession.fromMap(Map<String, dynamic> map) {
    return HistorySession(
      id: map['id'],
      originalSessionId: map['originalSessionId'],
      title: map['title'],
      date: map['date'],
      durationMillis: map['durationMillis'],
      isCompleted: map['isCompleted'] == 1,
    );
  }
}

class HistoryExercise {
  final String id;
  final String historySessionId;
  final String name;
  final ExerciseType type;

  HistoryExercise({
    String? id,
    required this.historySessionId,
    required this.name,
    required this.type,
  }) : id = id ?? uuid.v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'historySessionId': historySessionId,
      'name': name,
      'type': type.name,
    };
  }

  factory HistoryExercise.fromMap(Map<String, dynamic> map) {
    return HistoryExercise(
      id: map['id'],
      historySessionId: map['historySessionId'],
      name: map['name'],
      type: ExerciseType.values.firstWhere((e) => e.name == map['type']),
    );
  }
}

class HistorySet {
  final String id;
  final String historyExerciseId;
  final int setIndex;
  final int repsCompleted;
  final double weightAdded;
  final int restTimeTakenSeconds;
  final int durationSeconds;

  HistorySet({
    String? id,
    required this.historyExerciseId,
    required this.setIndex,
    required this.repsCompleted,
    required this.weightAdded,
    required this.restTimeTakenSeconds,
    required this.durationSeconds,
  }) : id = id ?? uuid.v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'historyExerciseId': historyExerciseId,
      'setIndex': setIndex,
      'repsCompleted': repsCompleted,
      'weightAdded': weightAdded,
      'restTimeTakenSeconds': restTimeTakenSeconds,
      'durationSeconds': durationSeconds,
    };
  }

  factory HistorySet.fromMap(Map<String, dynamic> map) {
    return HistorySet(
      id: map['id'],
      historyExerciseId: map['historyExerciseId'],
      setIndex: map['setIndex'],
      repsCompleted: map['repsCompleted'],
      weightAdded: map['weightAdded']?.toDouble() ?? 0.0,
      restTimeTakenSeconds: map['restTimeTakenSeconds'],
      durationSeconds: map['durationSeconds'],
    );
  }
}

// ==========================================
// ASSETS & PROGRESSION MODELS
// ==========================================

class AssetExercise {
  final String id;
  final String name;
  final ExerciseType type;
  final String imageUrl;
  final ProgressionCondition? condition;

  AssetExercise({
    String? id,
    required this.name,
    required this.type,
    this.imageUrl = "",
    this.condition,
  }) : id = id ?? uuid.v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'imageUrl': imageUrl,
      'condition': condition != null ? jsonEncode(condition!.toMap()) : null,
    };
  }

  factory AssetExercise.fromMap(Map<String, dynamic> map) {
    ProgressionCondition? parsedCondition;
    if (map['condition'] != null) {
      parsedCondition = ProgressionCondition.fromMap(
        jsonDecode(map['condition']),
      );
    }
    return AssetExercise(
      id: map['id'],
      name: map['name'],
      type: ExerciseType.values.firstWhere((e) => e.name == map['type']),
      imageUrl: map['imageUrl'] ?? "",
      condition: parsedCondition,
    );
  }
}

// ==========================================
// PROGRAM MODELS
// ==========================================

class ProgramWeek {
  final String id;
  String name;
  List<Session> sessions;

  ProgramWeek({String? id, required this.name, this.sessions = const []})
    : id = id ?? uuid.v4();

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'sessions': jsonEncode(sessions.map((e) => e.toMap()).toList()),
  };

  factory ProgramWeek.fromMap(Map<String, dynamic> map) {
    return ProgramWeek(
      id: map['id'],
      name: map['name'],
      sessions: map['sessions'] != null
          ? (jsonDecode(map['sessions']) as List)
                .map((e) => Session.fromMap(e))
                .toList()
          : [],
    );
  }
}

class Program {
  final String id;
  String name;
  bool isActive;
  List<ProgramWeek> weeks;
  List<String> completedSessionIds;

  Program({
    String? id,
    required this.name,
    this.isActive = false,
    this.weeks = const [],
    this.completedSessionIds = const [],
  }) : id = id ?? uuid.v4();

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'isActive': isActive ? 1 : 0,
    'weeks': jsonEncode(weeks.map((e) => e.toMap()).toList()),
    'completedSessionIds': jsonEncode(completedSessionIds),
  };

  factory Program.fromMap(Map<String, dynamic> map) {
    return Program(
      id: map['id'],
      name: map['name'],
      isActive: map['isActive'] == 1,
      weeks: map['weeks'] != null
          ? (jsonDecode(map['weeks']) as List)
                .map((e) => ProgramWeek.fromMap(e))
                .toList()
          : [],
      completedSessionIds: map['completedSessionIds'] != null
          ? List<String>.from(jsonDecode(map['completedSessionIds']))
          : [],
    );
  }
}

class Pyramid implements Exercise {
  @override
  final String id;
  @override
  final String name;
  @override
  final ProgressionCondition? condition;

  final int minReps;
  final int maxReps;
  final int increment;
  final double weight;
  final int restSeconds;
  final PyramidType pyramidType;

  Pyramid({
    String? id,
    required this.name,
    required this.minReps,
    required this.maxReps,
    required this.increment,
    this.weight = 0.0,
    required this.restSeconds,
    this.pyramidType = PyramidType.upAndDown,
    this.condition,
  }) : id = id ?? uuid.v4();

  @override
  Pyramid copyWithCondition(ProgressionCondition? newCondition) {
    return Pyramid(
      id: id,
      name: name,
      minReps: minReps,
      maxReps: maxReps,
      increment: increment,
      weight: weight,
      restSeconds: restSeconds,
      pyramidType: pyramidType,
      condition: newCondition,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    'type': 'Pyramid',
    'id': id,
    'name': name,
    'minReps': minReps,
    'maxReps': maxReps,
    'increment': increment,
    'weight': weight,
    'restSeconds': restSeconds,
    'pyramidType': pyramidType.name,
    'condition': condition?.toMap(),
  };
}

class MultiEmom implements Exercise {
  @override
  final String id;
  @override
  final String name;
  @override
  final ProgressionCondition? condition;
  final int everyXSeconds;
  final int totalRounds;
  final List<EmomMinuteGroup> minutes;

  MultiEmom({
    String? id,
    required this.name,
    required this.everyXSeconds,
    required this.totalRounds,
    this.minutes = const [],
    this.condition,
  }) : id = id ?? uuid.v4();

  @override
  MultiEmom copyWithCondition(ProgressionCondition? newCondition) {
    return MultiEmom(
      id: id,
      name: name,
      everyXSeconds: everyXSeconds,
      totalRounds: totalRounds,
      minutes: minutes,
      condition: newCondition,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    'type': 'MultiEmom',
    'id': id,
    'name': name,
    'everyXSeconds': everyXSeconds,
    'totalRounds': totalRounds,
    'minutes': minutes.map((e) => e.toMap()).toList(),
    'condition': condition?.toMap(),
  };
}
