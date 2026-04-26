// lib/screens/session_details_screen.dart

// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../models/workout_models.dart';
import '../viewmodels/session_provider.dart';
import '../viewmodels/asset_provider.dart';

class SessionDetailsScreen extends StatelessWidget {
  final String sessionId;
  const SessionDetailsScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<SessionProvider>();
    final assetProvider = context.watch<AssetProvider>();
    final session =
        sessionProvider.getSessionById(sessionId) ??
        Session(title: "Error", day: Day.monday);
    final progress = sessionProvider.progress;
    final colorScheme = Theme.of(context).colorScheme;
    final conditions = assetProvider.conditions;

    final accentColor = Colors.green;
    final bool isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                                            child: _AppIconWidget(
                                              icon: Icons.trending_up_rounded,
                                              label: condition.name,
                                              color: accentColor,
                                              onTap: () {},
                                            ),
                                          ),
                                        ),
                                        childWhenDragging: Opacity(
                                          opacity: 0.3,
                                          child: _AppIconWidget(
                                            icon: Icons.trending_up_rounded,
                                            label: condition.name,
                                            color: accentColor,
                                            onTap: () {},
                                          ),
                                        ),
                                        child: _AppIconWidget(
                                          icon: Icons.trending_up_rounded,
                                          label: condition.name,
                                          color: accentColor,
                                          onTap: () {},
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
                        _showAssetSelectionDialog(context, session),
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 28),
                    label: const Text(
                      "ADD",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
      body: SafeArea(
        child: ReorderableListView.builder(
          padding: const EdgeInsets.only(bottom: 160),
          physics: const BouncingScrollPhysics(),
          header: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title.toUpperCase(),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        session.day.dayOut.toUpperCase(),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colorScheme.secondary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                if (session.exercises.isNotEmpty && progress.startTime == 0)
                  IconButton.filled(
                    iconSize: 32,
                    padding: const EdgeInsets.all(16),
                    onPressed: () {
                      sessionProvider.startSession(session.id);
                      context.go('/session_of_the_day');
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                      shadowColor: colorScheme.primary.withValues(alpha: 0.4),
                    ),
                  )
                else if (progress.startTime > 0 &&
                    progress.sessionId == session.id &&
                    !progress.isFinished)
                  IconButton.filled(
                    iconSize: 32,
                    padding: const EdgeInsets.all(16),
                    onPressed: () => context.go('/session_of_the_day'),
                    icon: const Icon(Icons.play_arrow_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.secondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                      shadowColor: colorScheme.secondary.withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
          ),
          itemCount: session.exercises.length + 1,
          proxyDecorator: (child, index, animation) => Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: child,
            ),
          ),
          onReorder: (oldIndex, newIndex) {
            if (oldIndex >= session.exercises.length) return;
            if (newIndex > session.exercises.length)
              newIndex = session.exercises.length;
            if (newIndex > oldIndex) newIndex -= 1;
            final items = List<Exercise>.from(session.exercises);
            final item = items.removeAt(oldIndex);
            items.insert(newIndex, item);
            sessionProvider.updateExercisesOrder(session.id, items);
          },
          itemBuilder: (context, index) {
            if (index == session.exercises.length) {
              return Padding(
                key: const ValueKey("footer_clean_button"),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: OutlinedButton.icon(
                    onPressed: () => sessionProvider.cleanSession(session.id),
                    icon: const Icon(Icons.cleaning_services_rounded, size: 24),
                    label: const Text(
                      "CLEAN SESSION",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 1,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      side: BorderSide(color: colorScheme.error, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              );
            }

            final exercise = session.exercises[index];

            if (exercise is ModuleBlock) {
              return Padding(
                key: ValueKey(exercise.id),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                ).copyWith(bottom: 16),
                child: SessionModuleCard(
                  module: exercise,
                  onDelete: () =>
                      sessionProvider.deleteExercise(session.id, exercise.id),
                  onUpdate: (updatedMod) =>
                      sessionProvider.updateExercise(session.id, updatedMod),
                ),
              );
            }

            return Padding(
              key: ValueKey(exercise.id),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
              ).copyWith(bottom: 16),
              child: ExerciseCard(
                exercise: exercise,
                onDelete: () =>
                    sessionProvider.deleteExercise(session.id, exercise.id),
                onUpdate: (updatedEx) =>
                    sessionProvider.updateExercise(session.id, updatedEx),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showAssetSelectionDialog(BuildContext context, Session session) {
    showDialog(
      context: context,
      builder: (context) => AssetSelectionGridDialog(session: session),
    );
  }
}

class AssetSelectionGridDialog extends StatelessWidget {
  final Session session;
  const AssetSelectionGridDialog({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: colorScheme.surfaceContainerHighest,
            width: 1,
          ),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
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
                      "ADD CONTENT",
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
                const SizedBox(height: 12),
                TabBar(
                  labelColor: colorScheme.primary,
                  unselectedLabelColor: colorScheme.onSurfaceVariant,
                  indicatorColor: colorScheme.primary,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                  tabs: const [
                    Tab(text: "EXERCISES"),
                    Tab(text: "MODULES"),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TabBarView(
                    children: [
                      _DialogExercisesGrid(session: session),
                      _buildModulesGrid(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModulesGrid(BuildContext context) {
    final assetProvider = context.watch<AssetProvider>();
    final sessionProvider = context.read<SessionProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final modules = assetProvider.modules;

    if (modules.isEmpty) {
      return Center(
        child: Text(
          "No modules yet.",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        childAspectRatio: 0.55,
      ),
      itemCount: modules.length,
      itemBuilder: (context, index) {
        final mod = modules[index];
        return GestureDetector(
          onTap: () {
            final clonedExercises = mod.exercises.map((ex) {
              final map = ex.toMap();
              map['id'] = const Uuid().v4();
              return Exercise.fromMap(map);
            }).toList();

            final sessionModule = ModuleBlock(
              id: const Uuid().v4(),
              name: mod.name,
              exercises: clonedExercises,
            );

            sessionProvider.addExercise(session.id, sessionModule);
            Navigator.pop(context);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 32,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Text(
                    mod.name.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.orange,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 64,
                width: 64,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.view_module_rounded,
                  color: Colors.orange,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "${mod.exercises.length} EXOS",
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
    );
  }
}

class _DialogExercisesGrid extends StatefulWidget {
  final Session session;
  const _DialogExercisesGrid({required this.session});

  @override
  State<_DialogExercisesGrid> createState() => _DialogExercisesGridState();
}

class _DialogExercisesGridState extends State<_DialogExercisesGrid> {
  ExerciseType? _selectedFilter;

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
      case ExerciseType.freeTime:
        return FreeTime(name: asset.name);
      default:
        return RestBlock(restSeconds: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final assetProvider = context.watch<AssetProvider>();
    final sessionProvider = context.read<SessionProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final allAssets = assetProvider.assets;
    final assets = _selectedFilter == null
        ? allAssets
        : allAssets.where((a) => a.type == _selectedFilter).toList();

    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              _buildFilterChip("ALL", null, colorScheme),
              ...ExerciseType.values.map((type) {
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
              return _AppIconWidget(
                icon: asset.type == ExerciseType.restBlock
                    ? Icons.timer_rounded
                    : (asset.type == ExerciseType.freeTime
                          ? Icons.timer_outlined
                          : Icons.fitness_center_rounded),
                label: asset.name,
                topLabel: asset.type.label.toUpperCase(),
                color: colorScheme.primary,
                onTap: () {
                  final newEx = _createDefaultExercise(asset);
                  sessionProvider.addExercise(widget.session.id, newEx);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ],
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
          style: TextStyle(
            fontSize: 11,
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }
}

class _AppIconWidget extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String? topLabel;
  final VoidCallback onTap;
  const _AppIconWidget({
    required this.icon,
    required this.label,
    required this.color,
    this.topLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (topLabel != null) ...[
            SizedBox(
              height: 32,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Text(
                  topLabel!,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class SessionModuleCard extends StatefulWidget {
  final ModuleBlock module;
  final VoidCallback onDelete;
  final ValueChanged<ModuleBlock> onUpdate;

  const SessionModuleCard({
    super.key,
    required this.module,
    required this.onDelete,
    required this.onUpdate,
  });

  @override
  State<SessionModuleCard> createState() => _SessionModuleCardState();
}

class _SessionModuleCardState extends State<SessionModuleCard> {
  bool _isExpanded = false;

  void _onReorderExercises(int oldIndex, int newIndex) {
    if (newIndex > widget.module.exercises.length) {
      newIndex = widget.module.exercises.length;
    }
    if (oldIndex < newIndex) newIndex -= 1;
    final List<Exercise> currentExercises = List.from(widget.module.exercises);
    final Exercise item = currentExercises.removeAt(oldIndex);
    currentExercises.insert(newIndex, item);

    final updatedModule = ModuleBlock(
      id: widget.module.id,
      name: widget.module.name,
      exercises: currentExercises,
      condition: widget.module.condition,
    );
    widget.onUpdate(updatedModule);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final accentColor = Colors.orange;

    return Container(
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
              child: widget.module.exercises.isNotEmpty
                  ? ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.module.exercises.length,
                      onReorder: _onReorderExercises,
                      itemBuilder: (context, index) {
                        final ex = widget.module.exercises[index];
                        return Padding(
                          key: ValueKey(ex.id),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ExerciseCard(
                            exercise: ex,
                            onDelete: () {
                              final currentList = List<Exercise>.from(
                                widget.module.exercises,
                              );
                              currentList.removeAt(index);
                              widget.onUpdate(
                                ModuleBlock(
                                  id: widget.module.id,
                                  name: widget.module.name,
                                  exercises: currentList,
                                  condition: widget.module.condition,
                                ),
                              );
                            },
                            onUpdate: (updatedEx) {
                              final currentList = List<Exercise>.from(
                                widget.module.exercises,
                              );
                              currentList[index] = updatedEx;
                              widget.onUpdate(
                                ModuleBlock(
                                  id: widget.module.id,
                                  name: widget.module.name,
                                  exercises: currentList,
                                  condition: widget.module.condition,
                                ),
                              );
                            },
                          ),
                        );
                      },
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class ExerciseCard extends StatefulWidget {
  final Exercise exercise;
  final VoidCallback onDelete;
  final void Function(Exercise) onUpdate;
  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.onDelete,
    required this.onUpdate,
  });
  @override
  State<ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<ExerciseCard> {
  bool _isExpanded = false;
  late TextEditingController _setsCtrl,
      _restMinCtrl,
      _restSecCtrl,
      _repsCtrl,
      _weightCtrl;
  late TextEditingController _timeCapCtrl,
      _emomSecCtrl,
      _emomRoundsCtrl,
      _rpMicroSetsCtrl,
      _rpRestSecCtrl,
      _clusterRepsCtrl,
      _clusterIncCtrl;
  List<SubExercise> _movements = [];
  late TextEditingController _subNameCtrl, _subRepsCtrl, _subWeightCtrl;
  late TextEditingController _pyrMinCtrl, _pyrMaxCtrl, _pyrIncCtrl;
  PyramidType _pyrType = PyramidType.upAndDown;
  List<EmomMinuteGroup> _emomMinutes = [];
  int _activeMinuteIndex = 0;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void didUpdateWidget(covariant ExerciseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exercise != widget.exercise) {
      _disposeControllers();
      _initControllers();
    }
  }

  void _initControllers() {
    final ex = widget.exercise;
    _setsCtrl = TextEditingController();
    _restMinCtrl = TextEditingController();
    _restSecCtrl = TextEditingController();
    _repsCtrl = TextEditingController();
    _weightCtrl = TextEditingController();
    _timeCapCtrl = TextEditingController();
    _emomSecCtrl = TextEditingController();
    _emomRoundsCtrl = TextEditingController();
    _rpMicroSetsCtrl = TextEditingController();
    _rpRestSecCtrl = TextEditingController();
    _clusterRepsCtrl = TextEditingController();
    _clusterIncCtrl = TextEditingController();
    _subNameCtrl = TextEditingController();
    _subRepsCtrl = TextEditingController();
    _subWeightCtrl = TextEditingController();
    String formatVal(num v) => v == 0
        ? ''
        : (v is double
              ? (v == v.toInt() ? v.toInt().toString() : v.toString())
              : v.toString());

    if (ex is Classic) {
      _setsCtrl.text = formatVal(ex.sets);
      _repsCtrl.text = formatVal(ex.reps);
      _weightCtrl.text = formatVal(ex.weight);
      _restMinCtrl.text = formatVal(ex.rest ~/ 60);
      _restSecCtrl.text = formatVal(ex.rest % 60);
    } else if (ex is Pyramid) {
      _pyrMinCtrl = TextEditingController(text: formatVal(ex.minReps));
      _pyrMaxCtrl = TextEditingController(text: formatVal(ex.maxReps));
      _pyrIncCtrl = TextEditingController(text: formatVal(ex.increment));
      _weightCtrl.text = formatVal(ex.weight);
      _restMinCtrl.text = formatVal(ex.restSeconds ~/ 60);
      _restSecCtrl.text = formatVal(ex.restSeconds % 60);
      _pyrType = ex.pyramidType;
    } else if (ex is MultiEmom) {
      _emomSecCtrl.text = formatVal(ex.everyXSeconds);
      _emomRoundsCtrl.text = formatVal(ex.totalRounds);
      _emomMinutes = List.from(ex.minutes);
    } else if (ex is Amrap) {
      _timeCapCtrl.text = formatVal(ex.timeCapMinutes);
      _movements = List.from(ex.movements);
    } else if (ex is Emom) {
      _emomSecCtrl.text = formatVal(ex.everyXSeconds);
      _emomRoundsCtrl.text = formatVal(ex.totalRounds);
      _movements = List.from(ex.movements);
    } else if (ex is RestPause) {
      _rpMicroSetsCtrl.text = formatVal(ex.microSets);
      _rpRestSecCtrl.text = formatVal(ex.restSeconds);
    } else if (ex is Cluster) {
      _clusterRepsCtrl.text = formatVal(ex.targetReps);
      _clusterIncCtrl.text = formatVal(ex.incrementFactor);
    } else if (ex is Circuit) {
      _setsCtrl.text = formatVal(ex.sets);
      _restMinCtrl.text = formatVal(ex.restSeconds ~/ 60);
      _restSecCtrl.text = formatVal(ex.restSeconds % 60);
      _movements = List.from(ex.movements);
    } else if (ex is IsoMax) {
      _setsCtrl.text = formatVal(ex.sets);
      _weightCtrl.text = formatVal(ex.weight);
      _restMinCtrl.text = formatVal(ex.restSeconds ~/ 60);
      _restSecCtrl.text = formatVal(ex.restSeconds % 60);
    } else if (ex is IsoPositions) {
      _setsCtrl.text = formatVal(ex.sets);
      _restMinCtrl.text = formatVal(ex.restSeconds ~/ 60);
      _restSecCtrl.text = formatVal(ex.restSeconds % 60);
      _movements = List.from(ex.movements);
    } else if (ex is RestBlock) {
      _restMinCtrl.text = formatVal(ex.restSeconds ~/ 60);
      _restSecCtrl.text = formatVal(ex.restSeconds % 60);
    }
  }

  void _disposeControllers() {
    _setsCtrl.dispose();
    _restMinCtrl.dispose();
    _restSecCtrl.dispose();
    _repsCtrl.dispose();
    _weightCtrl.dispose();
    _timeCapCtrl.dispose();
    _emomSecCtrl.dispose();
    _emomRoundsCtrl.dispose();
    _rpMicroSetsCtrl.dispose();
    _rpRestSecCtrl.dispose();
    _clusterRepsCtrl.dispose();
    _clusterIncCtrl.dispose();
    _subNameCtrl.dispose();
    _subRepsCtrl.dispose();
    _subWeightCtrl.dispose();
    if (widget.exercise is Pyramid) {
      _pyrMinCtrl.dispose();
      _pyrMaxCtrl.dispose();
      _pyrIncCtrl.dispose();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _saveInlineEdits() {
    final ex = widget.exercise;
    final restTotal =
        (int.tryParse(_restMinCtrl.text) ?? 0) * 60 +
        (int.tryParse(_restSecCtrl.text) ?? 0);
    Exercise updatedEx;

    if (ex is Classic)
      updatedEx = Classic(
        id: ex.id,
        name: ex.name,
        sets: int.tryParse(_setsCtrl.text) ?? ex.sets,
        reps: int.tryParse(_repsCtrl.text) ?? ex.reps,
        weight: double.tryParse(_weightCtrl.text) ?? ex.weight,
        rest: restTotal,
        condition: ex.condition,
      );
    else if (ex is Pyramid)
      updatedEx = Pyramid(
        id: ex.id,
        name: ex.name,
        minReps: int.tryParse(_pyrMinCtrl.text) ?? ex.minReps,
        maxReps: int.tryParse(_pyrMaxCtrl.text) ?? ex.maxReps,
        increment: int.tryParse(_pyrIncCtrl.text) ?? ex.increment,
        weight: double.tryParse(_weightCtrl.text) ?? ex.weight,
        restSeconds: restTotal,
        pyramidType: _pyrType,
        condition: ex.condition,
      );
    else if (ex is MultiEmom)
      updatedEx = MultiEmom(
        id: ex.id,
        name: ex.name,
        everyXSeconds: int.tryParse(_emomSecCtrl.text) ?? ex.everyXSeconds,
        totalRounds: int.tryParse(_emomRoundsCtrl.text) ?? ex.totalRounds,
        minutes: _emomMinutes,
        condition: ex.condition,
      );
    else if (ex is Amrap)
      updatedEx = Amrap(
        id: ex.id,
        name: ex.name,
        timeCapMinutes: int.tryParse(_timeCapCtrl.text) ?? ex.timeCapMinutes,
        movements: _movements,
        condition: ex.condition,
      );
    else if (ex is Emom)
      updatedEx = Emom(
        id: ex.id,
        name: ex.name,
        everyXSeconds: int.tryParse(_emomSecCtrl.text) ?? ex.everyXSeconds,
        totalRounds: int.tryParse(_emomRoundsCtrl.text) ?? ex.totalRounds,
        movements: _movements,
        condition: ex.condition,
      );
    else if (ex is RestPause)
      updatedEx = RestPause(
        id: ex.id,
        name: ex.name,
        microSets: int.tryParse(_rpMicroSetsCtrl.text) ?? ex.microSets,
        restSeconds: int.tryParse(_rpRestSecCtrl.text) ?? ex.restSeconds,
        condition: ex.condition,
      );
    else if (ex is Cluster)
      updatedEx = Cluster(
        id: ex.id,
        name: ex.name,
        targetReps: int.tryParse(_clusterRepsCtrl.text) ?? ex.targetReps,
        incrementFactor:
            int.tryParse(_clusterIncCtrl.text) ?? ex.incrementFactor,
        condition: ex.condition,
      );
    else if (ex is Circuit)
      updatedEx = Circuit(
        id: ex.id,
        name: ex.name,
        sets: int.tryParse(_setsCtrl.text) ?? ex.sets,
        restSeconds: restTotal,
        movements: _movements,
        condition: ex.condition,
      );
    else if (ex is IsoMax)
      updatedEx = IsoMax(
        id: ex.id,
        name: ex.name,
        sets: int.tryParse(_setsCtrl.text) ?? ex.sets,
        weight: double.tryParse(_weightCtrl.text) ?? ex.weight,
        restSeconds: restTotal,
        condition: ex.condition,
      );
    else if (ex is IsoPositions)
      updatedEx = IsoPositions(
        id: ex.id,
        name: ex.name,
        sets: int.tryParse(_setsCtrl.text) ?? ex.sets,
        restSeconds: restTotal,
        movements: _movements,
        condition: ex.condition,
      );
    else if (ex is RestBlock)
      updatedEx = RestBlock(
        id: ex.id,
        name: "Rest",
        restSeconds: restTotal,
        condition: ex.condition,
      );
    else
      updatedEx = ex;

    widget.onUpdate(updatedEx);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    final accentColor = Colors.green;

    return DragTarget<ProgressionCondition>(
      hitTestBehavior: HitTestBehavior.opaque,
      onAcceptWithDetails: (details) =>
          widget.onUpdate(widget.exercise.copyWithCondition(details.data)),
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return Container(
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
              color: isHovered
                  ? accentColor
                  : (_isExpanded
                        ? colorScheme.primary
                        : (isLight
                              ? Colors.transparent
                              : colorScheme.surfaceContainerHighest)),
              width: isHovered || _isExpanded ? 2 : 1,
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              onExpansionChanged: (expanded) {
                setState(() => _isExpanded = expanded);
                if (!expanded) _saveInlineEdits();
              },
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.exercise is RestBlock
                      ? Icons.timer_rounded
                      : (widget.exercise is FreeTime
                            ? Icons.timer_outlined
                            : Icons.fitness_center_rounded),
                  color: colorScheme.primary,
                ),
              ),
              title: Text(
                widget.exercise.name.toUpperCase(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              subtitle: _buildSummary(context, accentColor),
              trailing: IconButton(
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
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: _buildInlineFormForType(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummary(BuildContext context, Color accentColor) {
    String summary = "";
    final ex = widget.exercise;
    String formatRest(int seconds) {
      if (seconds <= 0) return "";
      final m = seconds ~/ 60;
      final s = seconds % 60;
      if (m > 0 && s > 0) return " - Rest: ${m}m ${s}s";
      if (m > 0) return " - Rest: ${m}m";
      return " - Rest: ${s}s";
    }

    if (ex is Classic)
      summary =
          "${ex.sets} x ${ex.reps}${ex.weight > 0 ? ' @ ${ex.weight}kg' : ''}${formatRest(ex.rest)}";
    else if (ex is Pyramid)
      summary =
          "PYRAMID ${ex.pyramidType.label.toUpperCase()} [${ex.minReps}-${ex.maxReps}]${ex.weight > 0 ? ' @ ${ex.weight}kg' : ''}${formatRest(ex.restSeconds)}";
    else if (ex is MultiEmom)
      summary = "MULTI-EMOM - ${ex.totalRounds} CIRCUITS";
    else if (ex is Amrap)
      summary = "AMRAP - ${ex.timeCapMinutes} MIN";
    else if (ex is Emom)
      summary = "EMOM - ${ex.totalRounds} ROUNDS";
    else if (ex is RestPause)
      summary =
          "REST-PAUSE - ${ex.microSets} SETS${formatRest(ex.restSeconds)}";
    else if (ex is Cluster)
      summary = "CLUSTER - ${ex.targetReps} REPS";
    else if (ex is Circuit)
      summary = "CIRCUIT - ${ex.sets} ROUNDS${formatRest(ex.restSeconds)}";
    else if (ex is IsoMax)
      summary =
          "ISOMETRIC${ex.weight > 0 ? ' @ ${ex.weight}kg' : ''}${formatRest(ex.restSeconds)}";
    else if (ex is IsoPositions)
      summary = "ISOMETRIC${formatRest(ex.restSeconds)}";
    else if (ex is RestBlock)
      summary = "REST BLOCK${formatRest(ex.restSeconds)}";
    else if (ex is FreeTime)
      summary = "FREE TIME (Stopwatch)";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_isExpanded)
          Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Text(
              summary,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        if (ex.condition != null)
          GestureDetector(
            onDoubleTap: () => widget.onUpdate(ex.copyWithCondition(null)),
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.trending_up_rounded,
                      color: accentColor,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      ex.condition!.name.toUpperCase(),
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  InputDecoration _deco(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      isDense: true,
    );
  }

  Widget _buildInlineFormForType() {
    final ex = widget.exercise;
    final style = const TextStyle(fontWeight: FontWeight.bold);

    if (ex is FreeTime) {
      // Pas de paramètres à éditer pour Free Time.
      return const SizedBox.shrink();
    }

    if (ex is Classic) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _setsCtrl,
                  style: style,
                  keyboardType: TextInputType.number,
                  decoration: _deco("Sets"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _repsCtrl,
                  style: style,
                  keyboardType: TextInputType.number,
                  decoration: _deco("Reps"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _weightCtrl,
                  style: style,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _deco("Weight"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRestFields(),
        ],
      );
    } else if (ex is Pyramid) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pyrMinCtrl,
                  style: style,
                  keyboardType: TextInputType.number,
                  decoration: _deco("Min Reps"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _pyrMaxCtrl,
                  style: style,
                  keyboardType: TextInputType.number,
                  decoration: _deco("Max Reps"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _pyrIncCtrl,
                  style: style,
                  keyboardType: TextInputType.number,
                  decoration: _deco("Step (+/-)"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<PyramidType>(
                  initialValue: _pyrType,
                  decoration: _deco("Pyramid Mode"),
                  items: PyramidType.values
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.label, style: style),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _pyrType = val);
                      _saveInlineEdits();
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _weightCtrl,
                  style: style,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _deco("Weight"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRestFields(),
        ],
      );
    } else if (ex is MultiEmom) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emomSecCtrl,
                  style: style,
                  keyboardType: TextInputType.number,
                  decoration: _deco("Durée (sec)"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _emomRoundsCtrl,
                  style: style,
                  keyboardType: TextInputType.number,
                  decoration: _deco("Total Circuits"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            "CIRCUITS PAR MINUTE",
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          ..._emomMinutes.asMap().entries.map((entry) {
            int mIdx = entry.key;
            EmomMinuteGroup group = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "MINUTE ${mIdx + 1}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 24,
                        ),
                        onPressed: () {
                          setState(() {
                            _emomMinutes.removeAt(mIdx);
                            _saveInlineEdits();
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...group.movements.asMap().entries.map((movEntry) {
                    int subIdx = movEntry.key;
                    SubExercise mov = movEntry.value;
                    return Row(
                      children: [
                        Expanded(
                          child: Text(
                            "• ${mov.reps}x ${mov.name}${mov.weight > 0 ? ' @ ${mov.weight}kg' : ''}",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () {
                            setState(() {
                              _emomMinutes[mIdx].movements.removeAt(subIdx);
                              _saveInlineEdits();
                            });
                          },
                        ),
                      ],
                    );
                  }),
                ],
              ),
            );
          }),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _emomMinutes.isEmpty
                      ? null
                      : (_activeMinuteIndex >= _emomMinutes.length
                            ? 0
                            : _activeMinuteIndex),
                  decoration: _deco("Add movement to Minute"),
                  items: List.generate(
                    _emomMinutes.length,
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text("Minute ${i + 1}", style: style),
                    ),
                  ),
                  onChanged: (val) {
                    if (val != null) setState(() => _activeMinuteIndex = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _subNameCtrl,
                  style: style,
                  decoration: _deco("Movement Name"),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _subRepsCtrl,
                        style: style,
                        keyboardType: TextInputType.number,
                        decoration: _deco("Reps"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _subWeightCtrl,
                        style: style,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _deco("Weight"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.add_box_rounded, size: 32),
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: () {
                        if (_subNameCtrl.text.isNotEmpty &&
                            _subRepsCtrl.text.isNotEmpty &&
                            _emomMinutes.isNotEmpty) {
                          setState(() {
                            int targetIdx =
                                _activeMinuteIndex >= _emomMinutes.length
                                ? 0
                                : _activeMinuteIndex;
                            _emomMinutes[targetIdx].movements.add(
                              SubExercise(
                                name: _subNameCtrl.text,
                                reps: int.tryParse(_subRepsCtrl.text) ?? 0,
                                weight:
                                    double.tryParse(_subWeightCtrl.text) ?? 0.0,
                              ),
                            );
                            _subNameCtrl.clear();
                            _subRepsCtrl.clear();
                            _subWeightCtrl.clear();
                            _saveInlineEdits();
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _emomMinutes.add(
                  EmomMinuteGroup(
                    minuteIndex: _emomMinutes.length + 1,
                    movements: [],
                  ),
                );
                _saveInlineEdits();
              });
            },
            icon: const Icon(Icons.add_circle_outline_rounded),
            label: const Text(
              "ADD NEW MINUTE",
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      );
    } else if (ex is Amrap) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _timeCapCtrl,
            style: style,
            keyboardType: TextInputType.number,
            decoration: _deco("Time Cap (min)"),
          ),
          const SizedBox(height: 16),
          _buildSubMovementsList("MOVEMENTS"),
        ],
      );
    } else if (ex is Emom) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emomSecCtrl,
                  style: style,
                  keyboardType: TextInputType.number,
                  decoration: _deco("Every X sec"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _emomRoundsCtrl,
                  style: style,
                  keyboardType: TextInputType.number,
                  decoration: _deco("Rounds"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSubMovementsList("INTERVAL MOVEMENTS"),
        ],
      );
    } else if (ex is RestPause) {
      return Row(
        children: [
          Expanded(
            child: TextField(
              controller: _rpMicroSetsCtrl,
              style: style,
              keyboardType: TextInputType.number,
              decoration: _deco("Micro Sets"),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _rpRestSecCtrl,
              style: style,
              keyboardType: TextInputType.number,
              decoration: _deco("Rest (sec)"),
            ),
          ),
        ],
      );
    } else if (ex is Cluster) {
      return Row(
        children: [
          Expanded(
            child: TextField(
              controller: _clusterRepsCtrl,
              style: style,
              keyboardType: TextInputType.number,
              decoration: _deco("Total Reps"),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _clusterIncCtrl,
              style: style,
              keyboardType: TextInputType.number,
              decoration: _deco("Inc. factor"),
            ),
          ),
        ],
      );
    } else if (ex is Circuit) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _setsCtrl,
            style: style,
            keyboardType: TextInputType.number,
            decoration: _deco("Rounds"),
          ),
          const SizedBox(height: 16),
          _buildRestFields(title: "REST BETWEEN ROUNDS"),
          const SizedBox(height: 16),
          _buildSubMovementsList("CIRCUIT MOVEMENTS"),
        ],
      );
    } else if (ex is IsoMax) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _setsCtrl,
                  style: style,
                  keyboardType: TextInputType.number,
                  decoration: _deco("Sets"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _weightCtrl,
                  style: style,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _deco("Weight"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRestFields(),
        ],
      );
    } else if (ex is IsoPositions) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _setsCtrl,
            style: style,
            keyboardType: TextInputType.number,
            decoration: _deco("Sets"),
          ),
          const SizedBox(height: 16),
          _buildRestFields(),
          const SizedBox(height: 16),
          _buildSubMovementsList("POSITIONS", repsLabel: "Sec"),
        ],
      );
    } else if (ex is RestBlock) {
      return _buildRestFields();
    }
    return const SizedBox.shrink();
  }

  Widget _buildRestFields({String title = "REST"}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _restMinCtrl,
                style: const TextStyle(fontWeight: FontWeight.bold),
                keyboardType: TextInputType.number,
                decoration: _deco("Min"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _restSecCtrl,
                style: const TextStyle(fontWeight: FontWeight.bold),
                keyboardType: TextInputType.number,
                decoration: _deco("Sec"),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubMovementsList(String title, {String repsLabel = "Reps"}) {
    final style = const TextStyle(fontWeight: FontWeight.bold);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        ..._movements.asMap().entries.map((entry) {
          int idx = entry.key;
          SubExercise mov = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "• ${mov.reps}${repsLabel == 'Sec' ? 's' : 'x'} ${mov.name}${mov.weight > 0 ? ' @ ${mov.weight}kg' : ''}",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  onPressed: () {
                    setState(() => _movements.removeAt(idx));
                    _saveInlineEdits();
                  },
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _subNameCtrl,
                style: style,
                decoration: _deco("Movement Name"),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _subRepsCtrl,
                      style: style,
                      keyboardType: TextInputType.number,
                      decoration: _deco(repsLabel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _subWeightCtrl,
                      style: style,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _deco("Weight"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: Icon(
                      Icons.add_box_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 32,
                    ),
                    onPressed: () {
                      if (_subNameCtrl.text.isNotEmpty &&
                          _subRepsCtrl.text.isNotEmpty) {
                        setState(() {
                          _movements.add(
                            SubExercise(
                              name: _subNameCtrl.text,
                              reps: int.tryParse(_subRepsCtrl.text) ?? 0,
                              weight:
                                  double.tryParse(_subWeightCtrl.text) ?? 0.0,
                            ),
                          );
                          _subNameCtrl.clear();
                          _subRepsCtrl.clear();
                          _subWeightCtrl.clear();
                          _saveInlineEdits();
                        });
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
