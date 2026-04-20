// lib/screens/assets_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/workout_models.dart';
import '../viewmodels/asset_provider.dart';

class AssetsScreen extends StatelessWidget {
  const AssetsScreen({super.key});

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
          toolbarHeight: 0,
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

class _ExercisesTabView extends StatelessWidget {
  const _ExercisesTabView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AssetProvider>();
    final assets = provider.assets;
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
      body: ListView.builder(
        padding: const EdgeInsets.all(20).copyWith(bottom: 100),
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
    );
  }
}

class _ConditionsTabView extends StatelessWidget {
  const _ConditionsTabView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AssetProvider>();
    final conditions = provider.conditions;
    final accentColor = const Color(0xFF10B981); // Emerald Green for conditions
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
              _saveInlineEdits();
            }
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Icon(
            Icons.fitness_center_rounded,
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
  late TextEditingController _nameCtrl;
  late TextEditingController _targetSetsCtrl;
  late TextEditingController _targetRepsCtrl;
  late TextEditingController _weightIncrementCtrl;

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
              _saveInlineEdits();
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
