// lib/screens/assets_screen.dart

// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import '../main.dart';
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
      length: 3,
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
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
            tabs: const [
              Tab(text: "EXERCISES"),
              Tab(text: "MODULES"),
              Tab(text: "CONDITIONS"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ExercisesTabView(),
            _ModulesTabView(),
            _ConditionsTabView(),
          ],
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
                ...ExerciseType.values.map((type) {
                  // On empêche le filtre sur le moduleBlock interne qui n'est pas censé apparaitre en pur asset Exercise
                  if (type == ExerciseType.moduleBlock)
                    return const SizedBox.shrink();
                  return _buildFilterChip(
                    type.name.toUpperCase(),
                    type,
                    colorScheme,
                  );
                }),
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

class _ModulesTabView extends StatelessWidget {
  const _ModulesTabView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AssetProvider>();
    final modules = provider.modules;
    final conditions = provider.conditions;
    final bool isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final accentColor = Colors.orange;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: isKeyboardOpen
          ? null
          : Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).scaffoldBackgroundColor.withValues(alpha: 0.95),
                    blurRadius: 40,
                    spreadRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (conditions.isNotEmpty)
                    Flexible(
                      child: ShaderMask(
                        shaderCallback: (Rect bounds) {
                          return const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.white,
                              Colors.white,
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.85, 1.0],
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.dstIn,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(right: 32),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: conditions.map((condition) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 12.0),
                                child: SizedBox(
                                  width: 80,
                                  child:
                                      LongPressDraggable<ProgressionCondition>(
                                        data: condition,
                                        delay: const Duration(
                                          milliseconds: 200,
                                        ),
                                        feedback: Material(
                                          color: Colors.transparent,
                                          child: SizedBox(
                                            width: 80,
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  height: 64,
                                                  width: 64,
                                                  decoration: BoxDecoration(
                                                    color: Colors.green
                                                        .withValues(
                                                          alpha: 0.15,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.trending_up_rounded,
                                                    color: Colors.green,
                                                    size: 32,
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                Text(
                                                  condition.name,
                                                  textAlign: TextAlign.center,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        childWhenDragging: Opacity(
                                          opacity: 0.3,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                height: 64,
                                                width: 64,
                                                decoration: BoxDecoration(
                                                  color: Colors.green
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: const Icon(
                                                  Icons.trending_up_rounded,
                                                  color: Colors.green,
                                                  size: 32,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                condition.name,
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              height: 64,
                                              width: 64,
                                              decoration: BoxDecoration(
                                                color: Colors.green.withValues(
                                                  alpha: 0.15,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: const Icon(
                                                Icons.trending_up_rounded,
                                                color: Colors.green,
                                                size: 32,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              condition.name,
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 16),
                  FloatingActionButton.extended(
                    onPressed: () =>
                        provider.addModule(AssetModule(name: "New Module")),
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    icon: const Icon(Icons.view_module_rounded, size: 24),
                    label: const Text(
                      "NEW MODULE",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
      body: ListView.builder(
        padding: const EdgeInsets.all(24).copyWith(bottom: 160, top: 24),
        physics: const BouncingScrollPhysics(),
        itemCount: modules.length,
        itemBuilder: (context, index) {
          final module = modules[index];
          return ModuleCard(
            key: ValueKey(module.id),
            module: module,
            onDelete: () => provider.deleteModule(module.id),
            onUpdate: (updated) => provider.updateModule(updated),
          );
        },
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
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
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
            accentColor: Colors.green,
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
                        .where((t) => t != ExerciseType.moduleBlock)
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

class ModuleCard extends StatefulWidget {
  final AssetModule module;
  final VoidCallback onDelete;
  final ValueChanged<AssetModule> onUpdate;

  const ModuleCard({
    super.key,
    required this.module,
    required this.onDelete,
    required this.onUpdate,
  });

  @override
  State<ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<ModuleCard> {
  bool _isExpanded = false;
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.module.name);
  }

  @override
  void didUpdateWidget(ModuleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.module != widget.module) {
      _nameCtrl.text = widget.module.name;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _saveInlineEdits() {
    final updatedModule = AssetModule(
      id: widget.module.id,
      name: _nameCtrl.text.trim().isEmpty
          ? "Unnamed Module"
          : _nameCtrl.text.trim(),
      exercises: widget.module.exercises,
    );
    widget.onUpdate(updatedModule);
  }

  void _onReorderExercises(int oldIndex, int newIndex) {
    if (newIndex > widget.module.exercises.length)
      newIndex = widget.module.exercises.length;
    if (oldIndex < newIndex) newIndex -= 1;
    final List<Exercise> currentExercises = List.from(widget.module.exercises);
    final Exercise item = currentExercises.removeAt(oldIndex);
    currentExercises.insert(newIndex, item);

    final updatedModule = AssetModule(
      id: widget.module.id,
      name: widget.module.name,
      exercises: currentExercises,
    );
    widget.onUpdate(updatedModule);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final accentColor = Colors.orange;

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
              ? accentColor
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
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.view_module_rounded, color: accentColor),
          ),
          title: Text(
            widget.module.name.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          subtitle: Text(
            "${widget.module.exercises.length} Exercises",
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
                  TextField(
                    controller: _nameCtrl,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    decoration: _buildInputDeco("Module Name", colorScheme),
                  ),
                  const SizedBox(height: 16),

                  if (widget.module.exercises.isNotEmpty)
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.module.exercises.length,
                      onReorder: _onReorderExercises,
                      itemBuilder: (context, index) {
                        final ex = widget.module.exercises[index];
                        return Container(
                          key: ValueKey(ex.id),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          // List Tile ultra-simple: AUCUNE MODIFICATION DÉTAILLÉE N'EST PERMISE ICI
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: Icon(
                              ex is RestBlock
                                  ? Icons.timer_rounded
                                  : Icons.fitness_center_rounded,
                              color: accentColor,
                            ),
                            title: Text(
                              ex.name.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.drag_handle_rounded,
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.5),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    color: colorScheme.error,
                                  ),
                                  onPressed: () {
                                    final currentList = List<Exercise>.from(
                                      widget.module.exercises,
                                    );
                                    currentList.removeAt(index);
                                    widget.onUpdate(
                                      AssetModule(
                                        id: widget.module.id,
                                        name: widget.module.name,
                                        exercises: currentList,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () => _showAddExerciseToModuleDialog(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text(
                        "ADD EXERCISE",
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accentColor,
                        side: BorderSide(color: accentColor, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
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

  void _showAddExerciseToModuleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _ModuleAssetSelectionDialog(
        onPicked: (newEx) {
          final currentList = List<Exercise>.from(widget.module.exercises);
          currentList.add(newEx);
          widget.onUpdate(
            AssetModule(
              id: widget.module.id,
              name: widget.module.name,
              exercises: currentList,
            ),
          );
        },
      ),
    );
  }
}

class _ModuleAssetSelectionDialog extends StatelessWidget {
  final ValueChanged<Exercise> onPicked;
  const _ModuleAssetSelectionDialog({required this.onPicked});

  Exercise _createDefaultExercise(AssetExercise asset) {
    switch (asset.type) {
      case ExerciseType.classic:
        return Classic(
          name: asset.name,
          sets: 0,
          reps: 0,
          weight: 0.0,
          rest: 0,
        );
      case ExerciseType.pyramid:
        return Pyramid(
          name: asset.name,
          minReps: 0,
          maxReps: 0,
          increment: 0,
          restSeconds: 0,
        );
      case ExerciseType.multiEmom:
        return MultiEmom(
          name: asset.name,
          everyXSeconds: 60,
          totalRounds: 1,
          minutes: [],
        );
      case ExerciseType.amrap:
        return Amrap(name: asset.name, timeCapMinutes: 0);
      case ExerciseType.emom:
        return Emom(name: asset.name, everyXSeconds: 0, totalRounds: 0);
      case ExerciseType.restPause:
        return RestPause(name: asset.name, microSets: 0, restSeconds: 0);
      case ExerciseType.cluster:
        return Cluster(name: asset.name, targetReps: 0, incrementFactor: 1);
      case ExerciseType.circuit:
        return Circuit(name: asset.name, sets: 0, restSeconds: 0);
      case ExerciseType.isoMax:
        return IsoMax(name: asset.name, sets: 0, restSeconds: 0);
      case ExerciseType.isoPositions:
        return IsoPositions(name: asset.name, sets: 0, restSeconds: 0);
      case ExerciseType.restBlock:
        return RestBlock(restSeconds: 0);
      default:
        return RestBlock(restSeconds: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final assetProvider = context.watch<AssetProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final assets = assetProvider.assets;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colorScheme.surfaceContainerHighest, width: 1),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "ADD EXERCISE",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 28),
                    onPressed: () => Navigator.pop(context),
                    color: colorScheme.onSurfaceVariant,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 20,
                    childAspectRatio: 0.55,
                  ),
                  itemCount: assets.length,
                  itemBuilder: (context, index) {
                    final asset = assets[index];
                    return GestureDetector(
                      onTap: () {
                        onPicked(_createDefaultExercise(asset));
                        Navigator.pop(context);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            asset.type.label.toUpperCase(),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: colorScheme.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 64,
                            width: 64,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              asset.type == ExerciseType.restBlock
                                  ? Icons.timer_rounded
                                  : Icons.fitness_center_rounded,
                              color: colorScheme.primary,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            asset.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
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
