// lib/viewmodels/asset_provider.dart

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
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    try {
      final rawAssets = await _dbService.getAllAssets();
      // On retire le sort alphabétique, ils resteront dans l'ordre d'insertion (création)
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

  Future<void> addAsset(AssetExercise newAsset) async {
    await _dbService.insertAsset(newAsset);
    await _loadAssets();
  }

  Future<void> updateAsset(AssetExercise updatedAsset) async {
    await _dbService.insertAsset(updatedAsset);
    await _loadAssets();
  }

  Future<void> deleteAsset(String assetId) async {
    await _dbService.deleteAsset(assetId);
    await _loadAssets();
  }

  Future<void> addCondition(ProgressionCondition newCondition) async {
    try {
      await _dbService.insertCondition(newCondition);
      await _loadAssets();
    } catch (e) {
      debugPrint("Erreur lors de l'ajout de la condition: $e");
    }
  }

  Future<void> updateCondition(ProgressionCondition updatedCondition) async {
    try {
      await _dbService.insertCondition(updatedCondition);
      await _loadAssets();
    } catch (e) {
      debugPrint("Erreur lors de la mise à jour de la condition: $e");
    }
  }

  Future<void> deleteCondition(String conditionId) async {
    try {
      await _dbService.deleteCondition(conditionId);
      await _loadAssets();
    } catch (e) {
      debugPrint("Erreur lors de la suppression de la condition: $e");
    }
  }
}
