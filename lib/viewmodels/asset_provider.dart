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

  AssetProvider() {
    loadAssets();
  }

  // Rendue publique pour permettre le refresh manuel depuis l'UI (ex: après import)
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

    notifyListeners();
  }

  // --- Import / Export de tous les assets ---

  String exportAssetsToJson() {
    final map = {
      'exercises': _assets.map((e) => e.toMap()).toList(),
      'conditions': _conditions.map((e) => e.toMap()).toList(),
    };
    return jsonEncode(map);
  }

  Future<void> importAssetsFromJson(String jsonString) async {
    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;

      // Import des Exercices
      if (map.containsKey('exercises')) {
        final List<dynamic> exList = map['exercises'];
        for (var exMap in exList) {
          final newAsset = AssetExercise.fromMap(exMap);
          // Vérification de doublon (même nom et même type)
          bool exists = _assets.any(
            (a) =>
                a.name.toLowerCase() == newAsset.name.toLowerCase() &&
                a.type == newAsset.type,
          );

          if (!exists) {
            await _dbService.insertAsset(newAsset);
          }
        }
      }

      // Import des Conditions de progression
      if (map.containsKey('conditions')) {
        final List<dynamic> condList = map['conditions'];
        for (var condMap in condList) {
          final newCond = ProgressionCondition.fromMap(condMap);
          // Vérification de doublon
          bool exists = _conditions.any(
            (c) =>
                c.name.toLowerCase() == newCond.name.toLowerCase() &&
                c.type == newCond.type,
          );

          if (!exists) {
            await _dbService.insertCondition(newCond);
          }
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
      debugPrint("Erreur lors de l'ajout de la condition: $e");
    }
  }

  Future<void> updateCondition(ProgressionCondition updatedCondition) async {
    try {
      await _dbService.insertCondition(updatedCondition);
      await loadAssets();
    } catch (e) {
      debugPrint("Erreur lors de la mise à jour de la condition: $e");
    }
  }

  Future<void> deleteCondition(String conditionId) async {
    try {
      await _dbService.deleteCondition(conditionId);
      await loadAssets();
    } catch (e) {
      debugPrint("Erreur lors de la suppression de la condition: $e");
    }
  }
}
