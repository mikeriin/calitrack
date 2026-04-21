// lib/viewmodels/leveling_provider.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workout_models.dart';
import '../services/progress_repository.dart';
import 'session_provider.dart';

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
    // (Tu peux baisser ce chiffre pour faire tes tests de débug !)
    if (durationMillis < 1800000) {
      return 0.0; // Pas d'XP si la séance est trop courte
    }

    double gainedXp = 0;

    for (var log in logs) {
      double weightMultiplier = 1.0 + (log.weightAdded / 50.0);
      double baseLogXp = 0;

      switch (log.exerciseType) {
        case ExerciseType.classic:
        case ExerciseType.circuit:
        case ExerciseType.restPause:
        case ExerciseType.amrap:
          baseLogXp = log.repsCompleted * 10.0;
          break;
        case ExerciseType.emom:
        case ExerciseType.cluster:
          baseLogXp = log.repsCompleted * 12.0;
          break;
        case ExerciseType.isoMax:
        case ExerciseType.isoPositions:
          baseLogXp = log.repsCompleted * 5.0;
          break;
        case ExerciseType.restBlock:
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
    // Définition des paliers et récompenses
    final milestones = {
      5: _MilestoneReward(
        coins: 200,
        sessionName: "SPARTAN AWAKENING",
        day: Day.saturday,
      ),
      10: _MilestoneReward(
        coins: 500,
        sessionName: "TITAN STRENGTH",
        day: Day.sunday,
      ),
      20: _MilestoneReward(
        coins: 1000,
        sessionName: "OLYMPIAN CONDITIONING",
        day: Day.monday,
      ),
    };

    for (var entry in milestones.entries) {
      int targetLevel = entry.key;
      if (_level >= targetLevel && !_claimedMilestones.contains(targetLevel)) {
        _coins += entry.value.coins;
        _claimedMilestones.add(targetLevel);

        // Débloquer la nouvelle session en l'injectant dans la base de données
        final bonusSession = Session(
          title: entry.value.sessionName,
          day: entry.value.day,
          exercises: [
            RestBlock(
              restSeconds: 60,
              name: "🏆 Milestone Reward Session - Customize It!",
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

class _MilestoneReward {
  final int coins;
  final String sessionName;
  final Day day;

  _MilestoneReward({
    required this.coins,
    required this.sessionName,
    required this.day,
  });
}
