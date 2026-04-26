// lib/viewmodels/asset_provider.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/workout_models.dart';
import '../services/database_service.dart';

class AssetProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();

  List<AssetExercise> _assets = [];
  List<AssetExercise> get assets => _assets;

  List<ProgressionCondition> _conditions = [];
  List<ProgressionCondition> get conditions => _conditions;

  List<AssetModule> _modules = [];
  List<AssetModule> get modules => _modules;

  AssetProvider() {
    loadAssets();
  }

  Future<void> loadAssets() async {
    try {
      final rawAssets = await _dbService.getAllAssets();
      _assets = List<AssetExercise>.from(rawAssets);
    } catch (e) {
      debugPrint("Erreur lors du chargement des assets: $e");
      _assets = [];
    }

    try {
      final rawConditions = await _dbService.getAllConditions();
      _conditions = List<ProgressionCondition>.from(rawConditions);
    } catch (e) {
      debugPrint("Erreur lors du chargement des conditions: $e");
      _conditions = [];
    }

    try {
      final rawModules = await _dbService.getAllModules();
      _modules = List<AssetModule>.from(rawModules);
    } catch (e) {
      debugPrint("Erreur lors du chargement des modules: $e");
      _modules = [];
    }

    notifyListeners();
  }

  // --- Import / Export ---

  String exportAssetsToJson() {
    final map = {
      'exercises': _assets.map((e) => e.toMap()).toList(),
      'conditions': _conditions.map((e) => e.toMap()).toList(),
      'modules': _modules.map((e) => e.toMap()).toList(),
    };
    return jsonEncode(map);
  }

  Future<void> importAssetsFromJson(String jsonString) async {
    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;

      if (map.containsKey('exercises')) {
        final List<dynamic> exList = map['exercises'];
        for (var exMap in exList) {
          final newAsset = AssetExercise.fromMap(exMap);
          bool exists = _assets.any(
            (a) =>
                a.name.toLowerCase() == newAsset.name.toLowerCase() &&
                a.type == newAsset.type,
          );
          if (!exists) await _dbService.insertAsset(newAsset);
        }
      }

      if (map.containsKey('conditions')) {
        final List<dynamic> condList = map['conditions'];
        for (var condMap in condList) {
          final newCond = ProgressionCondition.fromMap(condMap);
          bool exists = _conditions.any(
            (c) =>
                c.name.toLowerCase() == newCond.name.toLowerCase() &&
                c.type == newCond.type,
          );
          if (!exists) await _dbService.insertCondition(newCond);
        }
      }

      if (map.containsKey('modules')) {
        final List<dynamic> modList = map['modules'];
        for (var modMap in modList) {
          final newMod = AssetModule.fromMap(modMap);
          bool exists = _modules.any(
            (m) => m.name.toLowerCase() == newMod.name.toLowerCase(),
          );
          if (!exists) await _dbService.insertModule(newMod);
        }
      }

      await loadAssets();
    } catch (e) {
      debugPrint("Erreur lors de l'import des assets: $e");
      rethrow;
    }
  }

  // ----------------------------------------------------

  Future<void> addAsset(AssetExercise newAsset) async {
    await _dbService.insertAsset(newAsset);
    await loadAssets();
  }

  Future<void> updateAsset(AssetExercise updatedAsset) async {
    await _dbService.insertAsset(updatedAsset);
    await loadAssets();
  }

  Future<void> deleteAsset(String assetId) async {
    await _dbService.deleteAsset(assetId);
    await loadAssets();
  }

  Future<void> addCondition(ProgressionCondition newCondition) async {
    try {
      await _dbService.insertCondition(newCondition);
      await loadAssets();
    } catch (e) {
      debugPrint("Erreur ajout condition: $e");
    }
  }

  Future<void> updateCondition(ProgressionCondition updatedCondition) async {
    try {
      await _dbService.insertCondition(updatedCondition);
      await loadAssets();
    } catch (e) {
      debugPrint("Erreur update condition: $e");
    }
  }

  Future<void> deleteCondition(String conditionId) async {
    try {
      await _dbService.deleteCondition(conditionId);
      await loadAssets();
    } catch (e) {
      debugPrint("Erreur suppression condition: $e");
    }
  }

  Future<void> addModule(AssetModule newModule) async {
    await _dbService.insertModule(newModule);
    await loadAssets();
  }

  Future<void> updateModule(AssetModule updatedModule) async {
    await _dbService.insertModule(updatedModule);
    await loadAssets();
  }

  Future<void> deleteModule(String moduleId) async {
    await _dbService.deleteModule(moduleId);
    await loadAssets();
  }
}
