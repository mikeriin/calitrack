// lib/screens/assets_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import '../main.dart'; // Pour accéder à progressRepository
import '../models/workout_models.dart';
import '../viewmodels/asset_provider.dart';

class AssetsScreen extends StatelessWidget {
  const AssetsScreen({super.key});

  Future<void> _handleImportAssets(BuildContext context) async {
    try {
      final customFolder = progressRepository.dataFolder;
      String? defaultPath;
      if (customFolder != null && customFolder.isNotEmpty) {
        defaultPath = customFolder;
      } else if (Platform.isAndroid) {
        final dir = await getDownloadsDirectory();
        defaultPath = dir?.path;
      }

      const XTypeGroup jsonType = XTypeGroup(
        label: 'JSON Files',
        extensions: <String>['json'],
      );
      final XFile? file = await openFile(
        acceptedTypeGroups: [jsonType],
        initialDirectory: defaultPath,
      );

      if (file != null) {
        final jsonString = await file.readAsString();
        if (!context.mounted) return;
        await context.read<AssetProvider>().importAssetsFromJson(jsonString);

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Assets imported successfully!"),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Import failed. Invalid file format."),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _handleExportAssets(BuildContext context) async {
    try {
      final provider = context.read<AssetProvider>();
      final jsonStr = provider.exportAssetsToJson();
      final folderPath = progressRepository.dataFolder;
      String? targetDir = folderPath;

      if (targetDir == null || targetDir.isEmpty) {
        if (Platform.isAndroid) {
          targetDir = (await getDownloadsDirectory())?.path;
        } else {
          targetDir = (await getApplicationDocumentsDirectory()).path;
        }
      }

      if (targetDir != null) {
        final fileName = "calitrack_assets_export.json";
        final file = File('$targetDir/$fileName');
        await file.writeAsString(jsonStr);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved to $targetDir/$fileName'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Export Error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Export failed.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          title: const Text(
            "ASSETS",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: "Import Assets (.json)",
              onPressed: () => _handleImportAssets(context),
            ),
            IconButton(
              icon: const Icon(Icons.ios_share_rounded),
              tooltip: "Export All Assets (.json)",
              onPressed: () => _handleExportAssets(context),
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            indicatorColor: colorScheme.primary,
            indicatorWeight: 2,
            dividerColor: colorScheme.surfaceContainerHighest,
            tabs: const [
              Tab(text: "EXERCISES"),
              Tab(text: "CONDITIONS"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_ExercisesTabView(), _ConditionsTabView()],
        ),
      ),
    );
  }
}

class _ExercisesTabView extends StatefulWidget {
  const _ExercisesTabView();

  @override
  State<_ExercisesTabView> createState() => _ExercisesTabViewState();
}

class _ExercisesTabViewState extends State<_ExercisesTabView> {
  ExerciseType? _selectedFilter;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AssetProvider>();
    final allAssets = provider.assets;

    // Filtrage
    final assets = _selectedFilter == null
        ? allAssets
        : allAssets.where((a) => a.type == _selectedFilter).toList();

    final colorScheme = Theme.of(context).colorScheme;
    final bool isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: isKeyboardOpen
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                provider.addAsset(
                  AssetExercise(
                    name: "New Exercise",
                    type: ExerciseType.classic,
                  ),
                );
              },
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              icon: const Icon(Icons.fitness_center_rounded, size: 20),
              label: const Text(
                "NEW EXERCISE",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
      body: Column(
        children: [
          // Barre de filtres horizontale
          SizedBox(
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _buildFilterChip("ALL", null, colorScheme),
                ...ExerciseType.values.map(
                  (type) => _buildFilterChip(
                    type.name.toUpperCase(),
                    type,
                    colorScheme,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20).copyWith(bottom: 100, top: 0),
              itemCount: assets.length,
              itemBuilder: (context, index) {
                final asset = assets[index];
                return AssetCard(
                  key: ValueKey(asset.id),
                  asset: asset,
                  onDelete: () => provider.deleteAsset(asset.id),
                  onUpdate: (updated) => provider.updateAsset(updated),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    ExerciseType? type,
    ColorScheme colorScheme,
  ) {
    final isSelected = _selectedFilter == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedFilter = type),
        backgroundColor: colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.5,
        ),
        selectedColor: colorScheme.primary.withValues(alpha: 0.2),
        checkmarkColor: colorScheme.primary,
        side: BorderSide.none,
      ),
    );
  }
}

class _ConditionsTabView extends StatelessWidget {
  const _ConditionsTabView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AssetProvider>();
    final conditions = provider.conditions;
    final accentColor = const Color(0xFF10B981);
    final bool isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: isKeyboardOpen
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                provider.addCondition(
                  ProgressionCondition(
                    name: "New Condition",
                    type: ProgressionType.linearWeight,
                    targetSets: 0,
                    targetReps: 0,
                    weightIncrement: 0.0,
                  ),
                );
              },
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              icon: const Icon(Icons.trending_up_rounded, size: 20),
              label: const Text(
                "NEW CONDITION",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20).copyWith(bottom: 100),
        itemCount: conditions.length,
        itemBuilder: (context, index) {
          final condition = conditions[index];
          return ConditionCard(
            key: ValueKey(condition.id),
            condition: condition,
            onDelete: () => provider.deleteCondition(condition.id),
            onUpdate: (updated) => provider.updateCondition(updated),
            accentColor: accentColor,
          );
        },
      ),
    );
  }
}

class AssetCard extends StatefulWidget {
  final AssetExercise asset;
  final VoidCallback onDelete;
  final ValueChanged<AssetExercise> onUpdate;

  const AssetCard({
    super.key,
    required this.asset,
    required this.onDelete,
    required this.onUpdate,
  });

  @override
  State<AssetCard> createState() => _AssetCardState();
}

class _AssetCardState extends State<AssetCard> {
  bool _isExpanded = false;
  late TextEditingController _nameCtrl;
  late ExerciseType _selectedType;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.asset.name);
    _selectedType = widget.asset.type;
  }

  @override
  void didUpdateWidget(AssetCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset) {
      _nameCtrl.text = widget.asset.name;
      _selectedType = widget.asset.type;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _saveInlineEdits() {
    final updatedAsset = AssetExercise(
      id: widget.asset.id,
      name: _nameCtrl.text.trim().isEmpty
          ? "Unnamed Exercise"
          : _nameCtrl.text.trim(),
      type: _selectedType,
    );
    widget.onUpdate(updatedAsset);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isExpanded
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          onExpansionChanged: (expanded) {
            setState(() => _isExpanded = expanded);
            if (!expanded) {
              Future.delayed(const Duration(milliseconds: 250), () {
                if (mounted) _saveInlineEdits();
              });
            }
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Icon(
            widget.asset.type == ExerciseType.restBlock
                ? Icons.timer_rounded
                : Icons.fitness_center_rounded,
            color: colorScheme.onSurfaceVariant,
          ),
          title: Text(
            widget.asset.name.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            widget.asset.type.label,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          trailing: IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: colorScheme.error),
            onPressed: widget.onDelete,
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.error.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  DropdownButtonFormField<ExerciseType>(
                    initialValue: _selectedType,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: "Format",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                    items: ExerciseType.values
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(type.label),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedType = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: "Exercise Name",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ConditionCard extends StatefulWidget {
  final ProgressionCondition condition;
  final VoidCallback onDelete;
  final ValueChanged<ProgressionCondition> onUpdate;
  final Color accentColor;

  const ConditionCard({
    super.key,
    required this.condition,
    required this.onDelete,
    required this.onUpdate,
    required this.accentColor,
  });

  @override
  State<ConditionCard> createState() => _ConditionCardState();
}

class _ConditionCardState extends State<ConditionCard> {
  bool _isExpanded = false;
  late ProgressionType _selectedType;
  late TextEditingController _nameCtrl,
      _targetSetsCtrl,
      _targetRepsCtrl,
      _weightIncrementCtrl;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void didUpdateWidget(ConditionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.condition != widget.condition) {
      _disposeControllers();
      _initControllers();
    }
  }

  void _initControllers() {
    _selectedType = widget.condition.type;
    _nameCtrl = TextEditingController(text: widget.condition.name);
    _targetSetsCtrl = TextEditingController(
      text: widget.condition.targetSets.toString(),
    );
    _targetRepsCtrl = TextEditingController(
      text: widget.condition.targetReps.toString(),
    );
    _weightIncrementCtrl = TextEditingController(
      text: widget.condition.weightIncrement.toString(),
    );
  }

  void _disposeControllers() {
    _nameCtrl.dispose();
    _targetSetsCtrl.dispose();
    _targetRepsCtrl.dispose();
    _weightIncrementCtrl.dispose();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _saveInlineEdits() {
    final updatedCondition = ProgressionCondition(
      id: widget.condition.id,
      name: _nameCtrl.text.trim().isEmpty
          ? "Unnamed Condition"
          : _nameCtrl.text.trim(),
      type: _selectedType,
      targetSets: int.tryParse(_targetSetsCtrl.text) ?? 0,
      targetReps: int.tryParse(_targetRepsCtrl.text) ?? 0,
      weightIncrement: double.tryParse(_weightIncrementCtrl.text) ?? 0.0,
    );
    widget.onUpdate(updatedCondition);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isExpanded
              ? widget.accentColor
              : colorScheme.surfaceContainerHighest,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          onExpansionChanged: (expanded) {
            setState(() => _isExpanded = expanded);
            if (!expanded) {
              Future.delayed(const Duration(milliseconds: 250), () {
                if (mounted) _saveInlineEdits();
              });
            }
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Icon(Icons.trending_up_rounded, color: widget.accentColor),
          title: Text(
            widget.condition.name.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            widget.condition.type.label,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "${widget.condition.targetSets}x${widget.condition.targetReps}\n+${widget.condition.weightIncrement}kg",
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: widget.accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: colorScheme.error,
                ),
                onPressed: widget.onDelete,
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.error.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  DropdownButtonFormField<ProgressionType>(
                    initialValue: _selectedType,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: "Type",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                    items: ProgressionType.values
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(type.label),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedType = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: "Name",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _targetSetsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Sets",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _targetRepsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Reps",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _weightIncrementCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: "Inc. (kg)",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
