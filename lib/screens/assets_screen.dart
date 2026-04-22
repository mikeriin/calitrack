// lib/screens/assets_screen.dart

// ignore_for_file: curly_braces_in_flow_control_structures

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
      } else if (Platform.isAndroid)
        defaultPath = (await getDownloadsDirectory())?.path;

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
            content: const Text(
              "Assets imported successfully!",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "Import failed. Invalid file format.",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
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
              content: Text(
                'Saved to $targetDir/$fileName',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Export Error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Export failed.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            behavior: SnackBarBehavior.floating,
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
          title: Text(
            "ASSETS",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 24,
              letterSpacing: 1.0,
              color: colorScheme.onSurface,
            ),
          ),
          centerTitle: false,
          actions: [
            IconButton(
              icon: Icon(
                Icons.file_download_outlined,
                color: colorScheme.primary,
              ),
              tooltip: "Import Assets (.json)",
              onPressed: () => _handleImportAssets(context),
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.ios_share_rounded, color: colorScheme.primary),
              tooltip: "Export All Assets (.json)",
              onPressed: () => _handleExportAssets(context),
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
              ),
            ),
            const SizedBox(width: 16),
          ],
          bottom: TabBar(
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            indicatorColor: colorScheme.primary,
            indicatorWeight: 4,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: colorScheme.surfaceContainerHighest,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
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
              onPressed: () => provider.addAsset(
                AssetExercise(name: "New Exercise", type: ExerciseType.classic),
              ),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              icon: const Icon(Icons.fitness_center_rounded, size: 24),
              label: const Text(
                "NEW EXERCISE",
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ),
      body: Column(
        children: [
          SizedBox(
            height: 72,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              physics: const BouncingScrollPhysics(),
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
              padding: const EdgeInsets.all(24).copyWith(bottom: 120, top: 0),
              physics: const BouncingScrollPhysics(),
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
      padding: const EdgeInsets.only(right: 12.0),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
          ),
        ),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedFilter = type),
        backgroundColor: colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.5,
        ),
        selectedColor: colorScheme.primary,
        checkmarkColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}

// ... (vers la ligne 218)
class _ConditionsTabView extends StatelessWidget {
  const _ConditionsTabView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AssetProvider>();
    final conditions = provider.conditions;
    // final colorScheme = Theme.of(context).colorScheme;
    final bool isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: isKeyboardOpen
          ? null
          : FloatingActionButton.extended(
              onPressed: () => provider.addCondition(
                ProgressionCondition(
                  name: "New Condition",
                  type: ProgressionType.linearWeight,
                  targetSets: 0,
                  targetReps: 0,
                  weightIncrement: 0.0,
                ),
              ),
              backgroundColor: Colors.green, // <--- Modifié ici
              foregroundColor: Colors.white, // <--- Assure un bon contraste
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              icon: const Icon(Icons.trending_up_rounded, size: 24),
              label: const Text(
                "NEW CONDITION",
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ),
      body: ListView.builder(
        padding: const EdgeInsets.all(24).copyWith(bottom: 120),
        physics: const BouncingScrollPhysics(),
        itemCount: conditions.length,
        itemBuilder: (context, index) {
          final condition = conditions[index];
          return ConditionCard(
            key: ValueKey(condition.id),
            condition: condition,
            onDelete: () => provider.deleteCondition(condition.id),
            onUpdate: (updated) => provider.updateCondition(updated),
            accentColor: Colors.green, // <--- Modifié ici
          );
        },
      ),
    );
  }
}

// Helper pour Input
InputDecoration _buildInputDeco(String label, ColorScheme colorScheme) {
  return InputDecoration(
    labelText: label,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    filled: true,
    fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
    isDense: true,
  );
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
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isLight
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
        border: Border.all(
          color: _isExpanded
              ? colorScheme.primary
              : (isLight
                    ? Colors.transparent
                    : colorScheme.surfaceContainerHighest),
          width: _isExpanded ? 2 : 1,
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
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              widget.asset.type == ExerciseType.restBlock
                  ? Icons.timer_rounded
                  : Icons.fitness_center_rounded,
              color: colorScheme.primary,
            ),
          ),
          title: Text(
            widget.asset.name.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          subtitle: Text(
            widget.asset.type.label,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
          trailing: IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: colorScheme.error),
            onPressed: widget.onDelete,
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.error.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                children: [
                  DropdownButtonFormField<ExerciseType>(
                    initialValue: _selectedType,
                    isExpanded: true,
                    decoration: _buildInputDeco("Format", colorScheme),
                    items: ExerciseType.values
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(
                              type.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    decoration: _buildInputDeco("Exercise Name", colorScheme),
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
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isLight
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
        border: Border.all(
          color: _isExpanded
              ? widget.accentColor
              : (isLight
                    ? Colors.transparent
                    : colorScheme.surfaceContainerHighest),
          width: _isExpanded ? 2 : 1,
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
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.trending_up_rounded, color: widget.accentColor),
          ),
          title: Text(
            widget.condition.name.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          subtitle: Text(
            widget.condition.type.label,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "${widget.condition.targetSets}x${widget.condition.targetReps}\n+${widget.condition.weightIncrement}kg",
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: widget.accentColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: colorScheme.error,
                ),
                onPressed: widget.onDelete,
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.error.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                children: [
                  DropdownButtonFormField<ProgressionType>(
                    initialValue: _selectedType,
                    isExpanded: true,
                    decoration: _buildInputDeco("Type", colorScheme),
                    items: ProgressionType.values
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(
                              type.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    decoration: _buildInputDeco("Name", colorScheme),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _targetSetsCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          decoration: _buildInputDeco("Sets", colorScheme),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _targetRepsCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          decoration: _buildInputDeco("Reps", colorScheme),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _weightIncrementCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    decoration: _buildInputDeco("Inc. (kg)", colorScheme),
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
