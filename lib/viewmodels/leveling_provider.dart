// lib/viewmodels/leveling_provider.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workout_models.dart';
import '../services/progress_repository.dart';
import 'session_provider.dart';

class MilestoneReward {
  final int level;
  final int coins;
  final String sessionName;
  final Day day;

  MilestoneReward({
    required this.level,
    required this.coins,
    required this.sessionName,
    required this.day,
  });
}

class LevelingProvider extends ChangeNotifier {
  int _level = 1;
  double _currentXp = 0;
  int _coins = 0;
  Set<int> _claimedMilestones = {};

  int get level => _level;
  double get currentXp => _currentXp;
  int get coins => _coins;
  Set<int> get claimedMilestones => _claimedMilestones;

  double get xpForNextLevel => 250.0 * pow(_level, 1.5);
  double get progressRatio => (_currentXp / xpForNextLevel).clamp(0.0, 1.0);

  // La liste publique de tous les paliers du jeu
  final List<MilestoneReward> availableMilestones = [
    MilestoneReward(
      level: 10,
      coins: 500,
      sessionName: "BEGINNER INITIATION",
      day: Day.saturday,
    ),
    MilestoneReward(
      level: 20,
      coins: 1000,
      sessionName: "ROOKIE AWAKENING",
      day: Day.sunday,
    ),
    MilestoneReward(
      level: 25,
      coins: 3000,
      sessionName: "🌟 BRONZE SPARTAN 🌟",
      day: Day.saturday,
    ),
    MilestoneReward(
      level: 30,
      coins: 1500,
      sessionName: "APPRENTICE GRIT",
      day: Day.sunday,
    ),
    MilestoneReward(
      level: 40,
      coins: 2000,
      sessionName: "IRON WILL",
      day: Day.saturday,
    ),
    MilestoneReward(
      level: 50,
      coins: 8000,
      sessionName: "🌟 SILVER GLADIATOR 🌟",
      day: Day.sunday,
    ),
    MilestoneReward(
      level: 60,
      coins: 3000,
      sessionName: "VETERAN CORE",
      day: Day.saturday,
    ),
    MilestoneReward(
      level: 70,
      coins: 4000,
      sessionName: "ADVANCED TACTICS",
      day: Day.sunday,
    ),
    MilestoneReward(
      level: 75,
      coins: 15000,
      sessionName: "🌟 GOLDEN TITAN 🌟",
      day: Day.saturday,
    ),
    MilestoneReward(
      level: 80,
      coins: 5000,
      sessionName: "EXPERT CONDITIONING",
      day: Day.sunday,
    ),
    MilestoneReward(
      level: 90,
      coins: 6000,
      sessionName: "ELITE PERFORMANCE",
      day: Day.saturday,
    ),
    MilestoneReward(
      level: 100,
      coins: 30000,
      sessionName: "👑 PLATINUM CHAMPION 👑",
      day: Day.sunday,
    ),
    MilestoneReward(
      level: 110,
      coins: 8000,
      sessionName: "MASTER CLASS",
      day: Day.saturday,
    ),
    MilestoneReward(
      level: 120,
      coins: 10000,
      sessionName: "GRANDMASTER DRILL",
      day: Day.sunday,
    ),
    MilestoneReward(
      level: 125,
      coins: 50000,
      sessionName: "💎 DIAMOND WARRIOR 💎",
      day: Day.saturday,
    ),
    MilestoneReward(
      level: 130,
      coins: 12000,
      sessionName: "UNSTOPPABLE FORCE",
      day: Day.sunday,
    ),
    MilestoneReward(
      level: 140,
      coins: 15000,
      sessionName: "RELENTLESS GRIND",
      day: Day.saturday,
    ),
    MilestoneReward(
      level: 150,
      coins: 80000,
      sessionName: "🔥 MYTHIC HERO 🔥",
      day: Day.sunday,
    ),
    MilestoneReward(
      level: 160,
      coins: 18000,
      sessionName: "SUPREME FOCUS",
      day: Day.saturday,
    ),
    MilestoneReward(
      level: 170,
      coins: 20000,
      sessionName: "ASCENDED REALM",
      day: Day.sunday,
    ),
    MilestoneReward(
      level: 175,
      coins: 120000,
      sessionName: "🌌 ASTRAL CONQUEROR 🌌",
      day: Day.saturday,
    ),
    MilestoneReward(
      level: 180,
      coins: 25000,
      sessionName: "GRAVITY DEFIER",
      day: Day.sunday,
    ),
    MilestoneReward(
      level: 190,
      coins: 30000,
      sessionName: "BEAST MODE ACTIVATED",
      day: Day.saturday,
    ),
    MilestoneReward(
      level: 200,
      coins: 200000,
      sessionName: "⚡ IMMORTAL LEGEND ⚡",
      day: Day.sunday,
    ),
    MilestoneReward(
      level: 210,
      coins: 35000,
      sessionName: "TITAN'S WRATH",
      day: Day.saturday,
    ),
    MilestoneReward(
      level: 220,
      coins: 40000,
      sessionName: "OLYMPIAN STRENGTH",
      day: Day.sunday,
    ),
    MilestoneReward(
      level: 225,
      coins: 250000,
      sessionName: "🔱 DEMIGOD STATUS 🔱",
      day: Day.saturday,
    ),
    MilestoneReward(
      level: 230,
      coins: 45000,
      sessionName: "UNIVERSE SHATTERER",
      day: Day.sunday,
    ),
    MilestoneReward(
      level: 240,
      coins: 50000,
      sessionName: "ABSOLUTE PINNACLE",
      day: Day.saturday,
    ),
    MilestoneReward(
      level: 250,
      coins: 500000,
      sessionName: "🌠 GOD OF FITNESS 🌠",
      day: Day.sunday,
    ),
  ];

  LevelingProvider() {
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _level = prefs.getInt('player_level') ?? 1;
    _currentXp = prefs.getDouble('player_xp') ?? 0.0;
    _coins = prefs.getInt('player_coins') ?? 0;
    final claimed = prefs.getStringList('claimed_milestones') ?? [];
    _claimedMilestones = claimed.map((e) => int.parse(e)).toSet();
    notifyListeners();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('player_level', _level);
    await prefs.setDouble('player_xp', _currentXp);
    await prefs.setInt('player_coins', _coins);
    await prefs.setStringList(
      'claimed_milestones',
      _claimedMilestones.map((e) => e.toString()).toList(),
    );
  }

  // Méthode appelée à la fin d'une session
  Future<double> processWorkoutLogs(
    List<WorkoutLogEntry> logs,
    SessionProvider sessionProvider,
    int durationMillis,
  ) async {
    // 1. Vérification anti-triche : 30 minutes = 30 * 60 * 1000 millisecondes
    if (durationMillis < 1800000) {
      return 0.0; // Pas d'XP si la séance est trop courte
    }

    double gainedXp = 0;

    for (var log in logs) {
      double weightMultiplier = 1.0 + (log.weightAdded / 50.0);
      double baseLogXp = 0;

      switch (log.exerciseType) {
        case ExerciseType.classic:
        case ExerciseType.pyramid:
        case ExerciseType.circuit:
        case ExerciseType.restPause:
        case ExerciseType.amrap:
          baseLogXp = log.repsCompleted * 10.0;
          break;
        case ExerciseType.emom:
        case ExerciseType.multiEmom:
        case ExerciseType.cluster:
          baseLogXp = log.repsCompleted * 12.0;
          break;
        case ExerciseType.isoMax:
        case ExerciseType.isoPositions:
          baseLogXp = log.repsCompleted * 5.0;
          break;
        case ExerciseType.freeTime:
          // Le log repsCompleted stocke le nombre de secondes écoulées
          baseLogXp = log.repsCompleted * 1.0; // 1 XP par seconde
          break;
        case ExerciseType.restBlock:
        case ExerciseType.moduleBlock:
          baseLogXp = 0;
          break;
      }
      gainedXp += baseLogXp * weightMultiplier;
    }

    if (gainedXp > 0) {
      _currentXp += gainedXp;
      _checkLevelUp(sessionProvider);
      await _saveData();
      notifyListeners();
    }

    return gainedXp; // On renvoie l'XP gagné pour pouvoir l'afficher
  }

  void _checkLevelUp(SessionProvider sessionProvider) {
    bool leveledUp = false;
    while (_currentXp >= xpForNextLevel) {
      _currentXp -= xpForNextLevel;
      _level++;
      _coins += 50; // 50 Coins gagnés par niveau classique
      leveledUp = true;
    }
    if (leveledUp) {
      _checkMilestones(sessionProvider);
    }
  }

  void _checkMilestones(SessionProvider sessionProvider) {
    for (var milestone in availableMilestones) {
      int targetLevel = milestone.level;

      if (_level >= targetLevel && !_claimedMilestones.contains(targetLevel)) {
        _coins += milestone.coins;
        _claimedMilestones.add(targetLevel);

        // Débloquer la nouvelle session en l'injectant dans la base de données
        final bonusSession = Session(
          title: milestone.sessionName,
          day: milestone.day,
          exercises: [
            RestBlock(
              restSeconds: 60,
              name: "🏆 ${milestone.sessionName} Unlocked - Customize it!",
            ),
          ],
        );
        sessionProvider.addSession(bonusSession);
      }
    }
  }

  // Optionnel: Méthode pour dépenser des coins dans le futur
  Future<bool> spendCoins(int amount) async {
    if (_coins >= amount) {
      _coins -= amount;
      await _saveData();
      notifyListeners();
      return true;
    }
    return false;
  }
}
