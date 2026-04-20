import 'package:flutter/material.dart';
import '../models/workout_models.dart';
import '../services/database_service.dart';

class AssetProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();

  // --- ETAT ---
  List<AssetExercise> _assets = [];
  List<AssetExercise> get assets => _assets;

  List<ProgressionCondition> _conditions = [];
  List<ProgressionCondition> get conditions => _conditions;

  AssetProvider() {
    _loadAssets();
  }

  // --- LECTURE ---
  Future<void> _loadAssets() async {
    _assets = await _dbService.getAllAssets();
    try {
      // Assurez-vous d'implémenter getAllConditions() dans DatabaseService
      _conditions = await _dbService.getAllConditions();
    } catch (e) {
      _conditions = []; // Fallback si la table n'existe pas encore
    }
    notifyListeners();
  }

  // --- CRUD ASSETS ---

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

  // --- CRUD CONDITIONS ---

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
      // insertCondition gère l'update grâce au ConflictAlgorithm.replace dans la BDD
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
