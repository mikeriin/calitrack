// lib/screens/session_details_screen.dart

// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
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
    final session = sessionProvider.allSessions.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => Session(title: "Error", day: Day.monday),
    );
    final progress = sessionProvider.progress;
    final colorScheme = Theme.of(context).colorScheme;
    final conditions = assetProvider.conditions;
    final accentColor = const Color(0xFF10B981);

    final bool isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: isKeyboardOpen
          ? null
          : Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                // Very diffuse dither/glow effect under the area
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).scaffoldBackgroundColor.withValues(alpha: 0.9),
                    blurRadius: 30,
                    spreadRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
                          padding: const EdgeInsets.only(right: 24),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: conditions.map((condition) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: SizedBox(
                                  width: 76,
                                  child:
                                      LongPressDraggable<ProgressionCondition>(
                                        data: condition,
                                        delay: const Duration(
                                          milliseconds: 200,
                                        ),
                                        feedback: Material(
                                          color: Colors.transparent,
                                          child: SizedBox(
                                            width: 76,
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
                  const SizedBox(width: 12),
                  FloatingActionButton.extended(
                    onPressed: () =>
                        _showAssetSelectionDialog(context, session),
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text(
                      "ADD",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
      body: SafeArea(
        child: ReorderableListView.builder(
          padding: const EdgeInsets.only(bottom: 140),
          header: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
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
                            ?.copyWith(color: colorScheme.onSurface),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session.day.dayOut.toUpperCase(),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: colorScheme.secondary),
                      ),
                    ],
                  ),
                ),
                if (session.exercises.isNotEmpty && progress.startTime == 0)
                  IconButton.filled(
                    iconSize: 24,
                    onPressed: () {
                      sessionProvider.startSession(session.id);
                      context.go('/session_of_the_day');
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  )
                else if (progress.startTime > 0 &&
                    progress.sessionId == session.id &&
                    !progress.isFinished)
                  IconButton.filled(
                    iconSize: 24,
                    onPressed: () => context.go('/session_of_the_day'),
                    icon: const Icon(Icons.play_arrow_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.secondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          itemCount: session.exercises.length + 1,
          proxyDecorator: (child, index, animation) =>
              Material(color: Colors.transparent, child: child),
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
                  horizontal: 20,
                  vertical: 24,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => sessionProvider.cleanSession(session.id),
                    icon: const Icon(Icons.cleaning_services_rounded, size: 20),
                    label: const Text(
                      "CLEAN SESSION",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      side: BorderSide(
                        color: colorScheme.error.withValues(alpha: 0.5),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              );
            }

            final exercise = session.exercises[index];
            return Padding(
              key: ValueKey(exercise.id),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
              ).copyWith(bottom: 12),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final assetProvider = context.watch<AssetProvider>();
    final sessionProvider = context.read<SessionProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final assets = assetProvider.assets;

    return Dialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.surfaceContainerHighest, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "ADD EXERCISE",
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: colorScheme.primary),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  color: colorScheme.onSurfaceVariant,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.55,
                ),
                itemCount: assets.length,
                itemBuilder: (context, index) {
                  final asset = assets[index];
                  return _AppIconWidget(
                    icon: asset.type == ExerciseType.restBlock
                        ? Icons.timer_rounded
                        : Icons.fitness_center_rounded,
                    label: asset.name,
                    topLabel: asset.type.label.toUpperCase(),
                    color: colorScheme.primary,
                    onTap: () {
                      final newEx = _createDefaultExercise(asset);
                      sessionProvider.addExercise(session.id, newEx);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
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
            Text(
              topLabel!,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
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
    final accentColor = const Color(0xFF10B981);

    return DragTarget<ProgressionCondition>(
      hitTestBehavior: HitTestBehavior.opaque,
      onAcceptWithDetails: (details) =>
          widget.onUpdate(widget.exercise.copyWithCondition(details.data)),
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHovered
                  ? accentColor
                  : (_isExpanded
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest),
              width: isHovered ? 2 : 1,
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
                horizontal: 16,
                vertical: 4,
              ),
              leading: Icon(
                widget.exercise is RestBlock
                    ? Icons.timer_rounded
                    : Icons.fitness_center_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
              title: Text(
                widget.exercise.name.toUpperCase(),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: colorScheme.onSurface),
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_isExpanded)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              summary,
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        if (ex.condition != null)
          GestureDetector(
            onDoubleTap: () => widget.onUpdate(ex.copyWithCondition(null)),
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.trending_up, color: accentColor, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    ex.condition!.name,
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInlineFormForType() {
    final ex = widget.exercise;
    if (ex is Classic) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: _buildTextField(_setsCtrl, "Sets")),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField(_repsCtrl, "Reps")),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextField(_weightCtrl, "Weight", isDecimal: true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRestFields(),
        ],
      );
    } else if (ex is Amrap) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTextField(_timeCapCtrl, "Time Cap (min)"),
          const SizedBox(height: 12),
          _buildSubMovementsList("MOVEMENTS"),
        ],
      );
    } else if (ex is Emom) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: _buildTextField(_emomSecCtrl, "Every X sec")),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField(_emomRoundsCtrl, "Rounds")),
            ],
          ),
          const SizedBox(height: 12),
          _buildSubMovementsList("INTERVAL MOVEMENTS"),
        ],
      );
    } else if (ex is RestPause) {
      return Row(
        children: [
          Expanded(child: _buildTextField(_rpMicroSetsCtrl, "Micro Sets")),
          const SizedBox(width: 8),
          Expanded(child: _buildTextField(_rpRestSecCtrl, "Rest (sec)")),
        ],
      );
    } else if (ex is Cluster) {
      return Row(
        children: [
          Expanded(child: _buildTextField(_clusterRepsCtrl, "Total Reps")),
          const SizedBox(width: 8),
          Expanded(child: _buildTextField(_clusterIncCtrl, "Increment factor")),
        ],
      );
    } else if (ex is Circuit) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTextField(_setsCtrl, "Rounds"),
          const SizedBox(height: 12),
          _buildRestFields(title: "REST BETWEEN ROUNDS"),
          const SizedBox(height: 12),
          _buildSubMovementsList("CIRCUIT MOVEMENTS"),
        ],
      );
    } else if (ex is IsoMax) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: _buildTextField(_setsCtrl, "Sets")),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextField(_weightCtrl, "Weight", isDecimal: true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRestFields(),
        ],
      );
    } else if (ex is IsoPositions) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTextField(_setsCtrl, "Sets"),
          const SizedBox(height: 12),
          _buildRestFields(),
          const SizedBox(height: 12),
          _buildSubMovementsList("POSITIONS", repsLabel: "Sec"),
        ],
      );
    } else if (ex is RestBlock) {
      return _buildRestFields();
    }
    return const SizedBox.shrink();
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool isDecimal = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
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
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildTextField(_restMinCtrl, "Min")),
            const SizedBox(width: 8),
            Expanded(child: _buildTextField(_restSecCtrl, "Sec")),
          ],
        ),
      ],
    );
  }

  Widget _buildSubMovementsList(String title, {String repsLabel = "Reps"}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        ..._movements.asMap().entries.map((entry) {
          int idx = entry.key;
          SubExercise mov = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "• ${mov.reps}${repsLabel == 'Sec' ? 's' : 'x'} ${mov.name}${mov.weight > 0 ? ' @ ${mov.weight}kg' : ''}",
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () {
                    setState(() => _movements.removeAt(idx));
                    _saveInlineEdits();
                  },
                ),
              ],
            ),
          );
        }),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _subNameCtrl,
                decoration: InputDecoration(
                  labelText: "Movement Name",
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _subRepsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: repsLabel,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _subWeightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: "Weight",
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.add_box,
                      color: Theme.of(context).colorScheme.primary,
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
