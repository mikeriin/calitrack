// lib/screens/session_of_the_day_screen.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/workout_models.dart';
import '../services/progress_repository.dart';
import '../viewmodels/session_provider.dart';
import '../viewmodels/tracker_provider.dart';

class SessionOfTheDayScreen extends StatefulWidget {
  const SessionOfTheDayScreen({super.key});

  @override
  State<SessionOfTheDayScreen> createState() => _SessionOfTheDayScreenState();
}

class _SessionOfTheDayScreenState extends State<SessionOfTheDayScreen> {
  Timer? _globalTimer;
  String _sessionDuration = "00:00:00";
  bool _isCountingDown = false;
  int _countdownNumber = 0;
  bool _showCancelDialog = false;

  bool _hasLoadedHistory = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _startGlobalTimer();
  }

  @override
  void dispose() {
    _globalTimer?.cancel();
    super.dispose();
  }

  void _startGlobalTimer() {
    _globalTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final provider = context.read<SessionProvider>();
      final progress = provider.progress;

      if (progress.startTime > 0 && !progress.isFinished) {
        final elapsed =
            DateTime.now().millisecondsSinceEpoch - progress.startTime;
        setState(() {
          _sessionDuration = _formatDuration(elapsed);
        });
      } else if (progress.isFinished && progress.endTime > 0) {
        final finalDuration = progress.endTime - progress.startTime;
        setState(() {
          _sessionDuration = _formatDuration(finalDuration);
        });
      } else if (progress.startTime == 0) {
        setState(() {
          _sessionDuration = "00:00:00";
        });
      }
    });
  }

  String _formatDuration(int millis) {
    final seconds = (millis / 1000).truncate() % 60;
    final minutes = (millis / (1000 * 60)).truncate() % 60;
    final hours = (millis / (1000 * 60 * 60)).truncate();
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _startInitialCountdown(String sessionId) async {
    setState(() {
      _isCountingDown = true;
    });

    await Future.delayed(const Duration(milliseconds: 50));

    for (int i = 3; i >= 1; i--) {
      if (mounted) setState(() => _countdownNumber = i);
      await Future.delayed(const Duration(seconds: 1));
    }

    if (mounted) {
      context.read<SessionProvider>().startSession(sessionId);
      await Future.delayed(const Duration(milliseconds: 100));
      setState(() {
        _isCountingDown = false;
        _countdownNumber = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SessionProvider>();
    final trackerProvider = context.watch<TrackerProvider>();
    final sessionOfTheDay = provider.sessionOfTheDay;
    final allSessions = provider.allSessions;
    final progress = provider.progress;
    final colorScheme = Theme.of(context).colorScheme;

    final activeSession = progress.sessionId.isNotEmpty
        ? allSessions.where((s) => s.id == progress.sessionId).firstOrNull
        : sessionOfTheDay;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasLoadedHistory) {
        trackerProvider.loadHistory();
        _hasLoadedHistory = true;
      }

      if (progress.isFinished &&
          activeSession != null &&
          !progress.isSaved &&
          !_isSaving) {
        _isSaving = true;
        final duration = progress.endTime - progress.startTime;

        provider
            .saveCompletedWorkout(activeSession, duration, progress.logs)
            .then((_) {
              trackerProvider.loadHistory().then((_) {
                if (mounted) {
                  setState(() {
                    _isSaving = false;
                  });
                }
              });
            });
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            child: _buildMainContent(
              activeSession,
              progress,
              colorScheme,
              provider,
              trackerProvider,
            ),
          ),
          if (_showCancelDialog) _buildCancelDialog(provider, colorScheme),
        ],
      ),
    );
  }

  Widget _buildMainContent(
    Session? activeSession,
    SessionProgress progress,
    ColorScheme colorScheme,
    SessionProvider provider,
    TrackerProvider trackerProvider,
  ) {
    if (activeSession == null) {
      return Center(
        child: Text(
          "REST DAY.",
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (progress.isFinished) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 32),
            SummaryView(
              title: activeSession.title,
              logs: progress.logs,
              totalTime: _sessionDuration,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: () => provider.resetSession(),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  activeSession.id != provider.sessionOfTheDay?.id
                      ? "FINISH WORKOUT"
                      : "FINISH & BACK",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      );
    }

    if (_isCountingDown) {
      return Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _countdownNumber > 0
              ? Text(
                  "$_countdownNumber",
                  key: ValueKey<int>(_countdownNumber),
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 140,
                    color: colorScheme.primary,
                    height: 1,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      );
    }

    final isExplicitlySelected = progress.sessionId.isNotEmpty;
    final isDefaultSessionOfTheDay =
        !isExplicitlySelected &&
        activeSession.id == provider.sessionOfTheDay?.id;
    bool isReallyCompleted = provider.isSessionOfTheDayCompleted;

    if (isReallyCompleted && isDefaultSessionOfTheDay) {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final hasLogForToday = trackerProvider.fullHistory.any((log) {
        final logDate = DateTime.fromMillisecondsSinceEpoch(log.session.date);
        return DateFormat('yyyy-MM-dd').format(logDate) == todayStr &&
            log.session.originalSessionId == activeSession.id;
      });

      if (!hasLogForToday) {
        isReallyCompleted = false;
      }
    }

    if (isDefaultSessionOfTheDay &&
        isReallyCompleted &&
        progress.startTime == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.surfaceContainerHighest,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.check_rounded,
                size: 60,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "WORKOUT DONE",
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              "Great job today. Check your history.",
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 40),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => _startInitialCountdown(activeSession.id),
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text(
                  "REDO SESSION",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.onSurface,
                  side: BorderSide(color: colorScheme.surfaceContainerHighest),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (progress.startTime == 0) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                activeSession.title.toUpperCase(),
                style: Theme.of(context).textTheme.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 60),
              GestureDetector(
                onTap: () => _startInitialCountdown(activeSession.id),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 60,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 60),
              if (activeSession.exercices.isNotEmpty)
                UpcomingExerciseCard(
                  exercice: activeSession.exercices.first,
                  titleLabel: "FIRST EXERCISE",
                ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      );
    }

    double sessionProgress = activeSession.exercices.isNotEmpty
        ? (progress.currentExIdx / activeSession.exercices.length).clamp(
            0.0,
            1.0,
          )
        : 0.0;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: colorScheme.surfaceContainerHighest),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => setState(() => _showCancelDialog = true),
                icon: Icon(
                  Icons.close_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      activeSession.title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: sessionProgress,
                        minHeight: 4,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text(
                _sessionDuration,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                if (progress.currentExIdx < activeSession.exercices.length) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      activeSession.exercices[progress.currentExIdx].name
                          .toUpperCase(),
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  _buildWorkoutRouter(
                    activeSession.exercices[progress.currentExIdx],
                    progress,
                    provider,
                    activeSession,
                  ),
                  const SizedBox(height: 60),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCancelDialog(SessionProvider provider, ColorScheme colorScheme) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        alignment: Alignment.center,
        child: AlertDialog(
          backgroundColor: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colorScheme.surfaceContainerHighest),
          ),
          title: Text(
            "ABORT WORKOUT?",
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          content: Text(
            "Discard session? No log will be recorded.",
            style: TextStyle(color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          actions: [
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () {
                      provider.resetSession();
                      setState(() => _showCancelDialog = false);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "QUIT WORKOUT",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    onPressed: () => setState(() => _showCancelDialog = false),
                    style: TextButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "RESUME",
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutRouter(
    Exercice exercice,
    SessionProgress progress,
    SessionProvider provider,
    Session session,
  ) {
    final exKey = ValueKey(progress.currentExIdx);

    if (exercice is Classic) {
      return ClassicWorkoutView(
        key: exKey,
        exercice: exercice,
        progress: progress,
        provider: provider,
        session: session,
      );
    }
    if (exercice is Amrap) {
      return AmrapWorkoutView(
        key: exKey,
        exercice: exercice,
        progress: progress,
        provider: provider,
        session: session,
      );
    }
    if (exercice is Emom) {
      return EmomWorkoutView(
        key: exKey,
        exercice: exercice,
        progress: progress,
        provider: provider,
        session: session,
      );
    }
    if (exercice is RestPause) {
      return RestPauseWorkoutView(
        key: exKey,
        exercice: exercice,
        progress: progress,
        provider: provider,
        session: session,
      );
    }
    if (exercice is Cluster) {
      return ClusterWorkoutView(
        key: exKey,
        exercice: exercice,
        progress: progress,
        provider: provider,
        session: session,
      );
    }
    if (exercice is Circuit) {
      return CircuitWorkoutView(
        key: exKey,
        exercice: exercice,
        progress: progress,
        provider: provider,
        session: session,
      );
    }
    if (exercice is IsoMax) {
      return IsoMaxWorkoutView(
        key: exKey,
        exercice: exercice,
        progress: progress,
        provider: provider,
        session: session,
      );
    }
    if (exercice is IsoPositions) {
      return IsoPositionsWorkoutView(
        key: exKey,
        exercice: exercice,
        progress: progress,
        provider: provider,
        session: session,
      );
    }
    if (exercice is RestBlock) {
      return RestBlockWorkoutView(
        key: exKey,
        exercice: exercice,
        progress: progress,
        provider: provider,
        session: session,
      );
    }
    return const SizedBox.shrink();
  }
}

// ==========================================
// OUTILS COMMUNS & DESIGN
// ==========================================
void _completeSetOrExercise(
  SessionProvider provider,
  SessionProgress progress,
  Session session,
  WorkoutLogEntry log,
  int totalSets,
  int restTimeSeconds,
) {
  final isLastSet = progress.currentSetIdx >= totalSets;
  final isSessionFinished =
      (progress.currentExIdx >= session.exercices.length - 1) && isLastSet;

  bool isNextRestBlock = false;
  if (!isSessionFinished &&
      progress.currentExIdx + 1 < session.exercices.length) {
    isNextRestBlock = session.exercices[progress.currentExIdx + 1] is RestBlock;
  }

  if (isSessionFinished) {
    provider.updateProgress(
      progress.copyWith(
        isFinished: true,
        isResting: false,
        restEndTime: 0,
        currentExIdx: progress.currentExIdx + 1,
        currentSetIdx: 1,
        logs: [...progress.logs, log],
      ),
    );
  } else if (isLastSet && (restTimeSeconds == 0 || isNextRestBlock)) {
    provider.updateProgress(
      progress.copyWith(
        isFinished: false,
        isResting: false,
        restEndTime: 0,
        currentExIdx: progress.currentExIdx + 1,
        currentSetIdx: 1,
        logs: [...progress.logs, log],
      ),
    );
  } else {
    provider.updateProgress(
      progress.copyWith(
        isFinished: false,
        isResting: true,
        restEndTime:
            DateTime.now().millisecondsSinceEpoch + (restTimeSeconds * 1000),
        logs: [...progress.logs, log],
      ),
    );
  }
}

// ==========================================
// VUES SPECIFIQUES AUX EXERCICES
// ==========================================

class ClassicWorkoutView extends StatefulWidget {
  final Classic exercice;
  final SessionProgress progress;
  final SessionProvider provider;
  final Session session;
  const ClassicWorkoutView({
    super.key,
    required this.exercice,
    required this.progress,
    required this.provider,
    required this.session,
  });
  @override
  State<ClassicWorkoutView> createState() => _ClassicWorkoutViewState();
}

class _ClassicWorkoutViewState extends State<ClassicWorkoutView> {
  final _repsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repsController.text = widget.exercice.reps.toString();
  }

  void _onDone() {
    final reps = int.tryParse(_repsController.text);
    if (reps == null) return;
    FocusScope.of(context).unfocus();
    final log = WorkoutLogEntry(
      exerciseName: widget.exercice.name,
      exerciseType: ExerciseType.classic,
      setIndex: widget.progress.currentSetIdx,
      repsCompleted: reps,
      weightAdded: widget.exercice.weight,
      restTimeSeconds: widget.exercice.rest,
    );
    _completeSetOrExercise(
      widget.provider,
      widget.progress,
      widget.session,
      log,
      widget.exercice.sets,
      widget.exercice.rest,
    );
    _repsController.text = widget.exercice.reps.toString();
  }

  void _skipRest() {
    final isLastSet = widget.progress.currentSetIdx >= widget.exercice.sets;
    widget.provider.updateProgress(
      widget.progress.copyWith(
        isResting: false,
        restEndTime: 0,
        currentSetIdx: isLastSet ? 1 : widget.progress.currentSetIdx + 1,
        currentExIdx: isLastSet
            ? widget.progress.currentExIdx + 1
            : widget.progress.currentExIdx,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final weightLabel = widget.exercice.weight > 0
        ? " @ ${widget.exercice.weight} kg"
        : "";

    return Column(
      children: [
        Text(
          "SET ${widget.progress.currentSetIdx}/${widget.exercice.sets} • ${widget.exercice.reps} TARGET REPS$weightLabel",
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: colorScheme.secondary),
          textAlign: TextAlign.center,
        ),
        if (widget.progress.isResting) ...[
          RestTimer(
            endTime: widget.progress.restEndTime,
            totalSec: widget.exercice.rest,
            onFinish: _skipRest,
          ),
          SizedBox(
            height: 56,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _skipRest,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: colorScheme.surfaceContainerHighest),
              ),
              child: const Text(
                "SKIP RECOVERY",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Builder(
            builder: (context) {
              final isLastSet =
                  widget.progress.currentSetIdx >= widget.exercice.sets;
              final nextExIdx = isLastSet
                  ? widget.progress.currentExIdx + 1
                  : widget.progress.currentExIdx;
              if (nextExIdx < widget.session.exercices.length) {
                return UpcomingExerciseCard(
                  exercice: widget.session.exercices[nextExIdx],
                  titleLabel: isLastSet ? "UP NEXT" : "NEXT SET",
                  nextSetIndex: isLastSet
                      ? null
                      : widget.progress.currentSetIdx + 1,
                  totalSets: isLastSet ? null : widget.exercice.sets,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ] else ...[
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.surfaceContainerHighest),
            ),
            child: Column(
              children: [
                Text(
                  "REPS COMPLETED",
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                TextField(
                  controller: _repsController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  style: Theme.of(
                    context,
                  ).textTheme.displayLarge?.copyWith(fontSize: 72, height: 1.2),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _onDone,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "LOG SET",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class AmrapWorkoutView extends StatefulWidget {
  final Amrap exercice;
  final SessionProgress progress;
  final SessionProvider provider;
  final Session session;
  const AmrapWorkoutView({
    super.key,
    required this.exercice,
    required this.progress,
    required this.provider,
    required this.session,
  });
  @override
  State<AmrapWorkoutView> createState() => _AmrapWorkoutViewState();
}

class _AmrapWorkoutViewState extends State<AmrapWorkoutView> {
  bool _isStarted = false, _isTimeUp = false;
  int _endTime = 0, _roundsCompleted = 0;
  final _extraRepsCtrl = TextEditingController();

  void _startAmrap() {
    FocusScope.of(context).unfocus();
    setState(() {
      _isStarted = true;
      _endTime =
          DateTime.now().millisecondsSinceEpoch +
          (widget.exercice.timeCapMinutes * 60 * 1000);
    });
  }

  void _onTimeUp() => setState(() => _isTimeUp = true);

  void _logScore() {
    FocusScope.of(context).unfocus();
    final extra = int.tryParse(_extraRepsCtrl.text) ?? 0;
    final repsPerRound = widget.exercice.movements.fold(
      0,
      (sum, m) => sum + m.reps,
    );
    final log = WorkoutLogEntry(
      exerciseName: widget.exercice.name,
      exerciseType: ExerciseType.amrap,
      setIndex: 1,
      repsCompleted: (_roundsCompleted * repsPerRound) + extra,
      durationSeconds: widget.exercice.timeCapMinutes * 60,
    );
    _completeSetOrExercise(
      widget.provider,
      widget.progress,
      widget.session,
      log,
      1,
      0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final repsPerRound = widget.exercice.movements.fold(
      0,
      (sum, m) => sum + m.reps,
    );

    return Column(
      children: [
        Text(
          "AMRAP • ${widget.exercice.timeCapMinutes} MIN",
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: colorScheme.secondary),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: widget.exercice.movements
                .map(
                  (m) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Text(
                          "${m.reps}x",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "${m.name}${m.weight > 0 ? " @ ${m.weight}kg" : ""}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 32),

        if (!_isStarted) ...[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _startAmrap,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "START AMRAP",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ] else if (!_isTimeUp) ...[
          RestTimer(
            key: ValueKey(_endTime),
            endTime: _endTime,
            totalSec: widget.exercice.timeCapMinutes * 60,
            onFinish: _onTimeUp,
            isCountdownStyle: true,
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.surfaceContainerHighest),
            ),
            child: Column(
              children: [
                Text(
                  "ROUNDS COMPLETED",
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: () {
                        if (_roundsCompleted > 0) {
                          setState(() => _roundsCompleted--);
                        }
                      },
                      icon: const Icon(Icons.remove_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    Text(
                      "$_roundsCompleted",
                      style: Theme.of(
                        context,
                      ).textTheme.displayLarge?.copyWith(fontSize: 64),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _roundsCompleted++),
                      icon: Icon(
                        Icons.add_rounded,
                        color: colorScheme.onPrimary,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "(${_roundsCompleted * repsPerRound} reps base)",
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: _onTimeUp,
            child: Text(
              "FINISH EARLY",
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ] else ...[
          Icon(Icons.timer_off_rounded, size: 48, color: colorScheme.primary),
          const SizedBox(height: 16),
          Text("TIME'S UP!", style: Theme.of(context).textTheme.headlineMedium),
          Text(
            "$_roundsCompleted ROUNDS COMPLETED",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.surfaceContainerHighest),
            ),
            child: Column(
              children: [
                Text(
                  "EXTRA REPS",
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                TextField(
                  controller: _extraRepsCtrl,
                  keyboardType: TextInputType.number,
                  style: Theme.of(
                    context,
                  ).textTheme.displayLarge?.copyWith(fontSize: 72, height: 1.2),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: "0",
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _logScore,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "LOG AMRAP SCORE",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class EmomWorkoutView extends StatefulWidget {
  final Emom exercice;
  final SessionProgress progress;
  final SessionProvider provider;
  final Session session;
  const EmomWorkoutView({
    super.key,
    required this.exercice,
    required this.progress,
    required this.provider,
    required this.session,
  });
  @override
  State<EmomWorkoutView> createState() => _EmomWorkoutViewState();
}

class _EmomWorkoutViewState extends State<EmomWorkoutView> {
  bool _isStarted = false;
  int _endTime = 0;

  void _startEmom() {
    setState(() {
      _isStarted = true;
      _endTime =
          DateTime.now().millisecondsSinceEpoch +
          (widget.exercice.everyXSeconds * 1000);
    });
  }

  void _onRoundFinished() {
    final currentRound = widget.progress.currentSetIdx;
    if (currentRound < widget.exercice.totalRounds) {
      setState(
        () => _endTime =
            DateTime.now().millisecondsSinceEpoch +
            (widget.exercice.everyXSeconds * 1000),
      );
      widget.provider.updateProgress(
        widget.progress.copyWith(currentSetIdx: currentRound + 1),
      );
    } else {
      _finishExercise();
    }
  }

  void _finishExercise() {
    final repsPerRound = widget.exercice.movements.fold(
      0,
      (sum, m) => sum + m.reps,
    );
    final log = WorkoutLogEntry(
      exerciseName: widget.exercice.name,
      exerciseType: ExerciseType.emom,
      setIndex: 1,
      repsCompleted: repsPerRound * widget.progress.currentSetIdx,
    );
    _completeSetOrExercise(
      widget.provider,
      widget.progress.copyWith(currentSetIdx: widget.exercice.totalRounds),
      widget.session,
      log,
      widget.exercice.totalRounds,
      0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          "ROUND ${widget.progress.currentSetIdx}/${widget.exercice.totalRounds} • EVERY ${widget.exercice.everyXSeconds} SEC",
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: colorScheme.secondary),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: widget.exercice.movements
                .map(
                  (m) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Text(
                          "${m.reps}x",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            m.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 32),

        if (!_isStarted) ...[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _startEmom,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "START EMOM",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ] else ...[
          RestTimer(
            key: ValueKey(_endTime),
            endTime: _endTime,
            totalSec: widget.exercice.everyXSeconds,
            onFinish: _onRoundFinished,
            isCountdownStyle: true,
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: _finishExercise,
            child: Text(
              "END EARLY",
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ],
    );
  }
}

class RestPauseWorkoutView extends StatefulWidget {
  final RestPause exercice;
  final SessionProgress progress;
  final SessionProvider provider;
  final Session session;
  const RestPauseWorkoutView({
    super.key,
    required this.exercice,
    required this.progress,
    required this.provider,
    required this.session,
  });
  @override
  State<RestPauseWorkoutView> createState() => _RestPauseWorkoutViewState();
}

class _RestPauseWorkoutViewState extends State<RestPauseWorkoutView> {
  final _repsController = TextEditingController();
  bool _isLocalResting = false;
  int _endTime = 0;
  final List<int> _history = [];

  void _startRest() {
    FocusScope.of(context).unfocus();
    setState(() {
      _isLocalResting = true;
      _endTime =
          DateTime.now().millisecondsSinceEpoch +
          (widget.exercice.restSeconds * 1000);
    });
  }

  void _onRestFinished() {
    _history.add(int.tryParse(_repsController.text) ?? 0);
    _repsController.clear();
    setState(() => _isLocalResting = false);
    widget.provider.updateProgress(
      widget.progress.copyWith(
        currentSetIdx: widget.progress.currentSetIdx + 1,
      ),
    );
  }

  void _finishExercise() {
    final finalHistory = [..._history, int.tryParse(_repsController.text) ?? 0];
    FocusScope.of(context).unfocus();
    final List<WorkoutLogEntry> newLogs = List.generate(
      finalHistory.length,
      (i) => WorkoutLogEntry(
        exerciseName: widget.exercice.name,
        exerciseType: ExerciseType.restPause,
        setIndex: i + 1,
        repsCompleted: finalHistory[i],
        restTimeSeconds: widget.exercice.restSeconds,
      ),
    );
    final isLastEx =
        widget.progress.currentExIdx >= widget.session.exercices.length - 1;
    widget.provider.updateProgress(
      widget.progress.copyWith(
        isFinished: isLastEx,
        isResting: false,
        restEndTime: 0,
        currentExIdx: widget.progress.currentExIdx + 1,
        currentSetIdx: 1,
        logs: [...widget.progress.logs, ...newLogs],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentSet = widget.progress.currentSetIdx;

    return Column(
      children: [
        Text(
          "MICRO-SET $currentSet/${widget.exercice.microSets}",
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: colorScheme.secondary),
        ),
        if (_isLocalResting) ...[
          RestTimer(
            key: ValueKey(_endTime),
            endTime: _endTime,
            totalSec: widget.exercice.restSeconds,
            onFinish: _onRestFinished,
          ),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: _onRestFinished,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "SKIP REST",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Builder(
            builder: (context) {
              final isLastSet =
                  widget.progress.currentSetIdx >= widget.exercice.microSets;
              final nextExIdx = isLastSet
                  ? widget.progress.currentExIdx + 1
                  : widget.progress.currentExIdx;
              if (nextExIdx < widget.session.exercices.length) {
                return UpcomingExerciseCard(
                  exercice: widget.session.exercices[nextExIdx],
                  titleLabel: isLastSet ? "UP NEXT" : "NEXT MICRO-SET",
                  nextSetIndex: isLastSet
                      ? null
                      : widget.progress.currentSetIdx + 1,
                  totalSets: isLastSet ? null : widget.exercice.microSets,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ] else ...[
          const SizedBox(height: 48),
          if (currentSet < widget.exercice.microSets) ...[
            Text(
              "MAX REPS!",
              style: Theme.of(
                context,
              ).textTheme.displayLarge?.copyWith(fontSize: 48),
            ),
            const SizedBox(height: 48),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.surfaceContainerHighest),
              ),
              child: Column(
                children: [
                  Text(
                    "REPS COMPLETED",
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  TextField(
                    controller: _repsController,
                    keyboardType: TextInputType.number,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 72,
                      height: 1.2,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: "0",
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _startRest,
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  "START ${widget.exercice.restSeconds}S RECOVERY",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.surfaceContainerHighest),
              ),
              child: Column(
                children: [
                  Text(
                    "LAST SET REPS",
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  TextField(
                    controller: _repsController,
                    keyboardType: TextInputType.number,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 72,
                      height: 1.2,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: "0",
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _finishExercise,
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "LOG EXERCISE",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class ClusterWorkoutView extends StatefulWidget {
  final Cluster exercice;
  final SessionProgress progress;
  final SessionProvider provider;
  final Session session;
  const ClusterWorkoutView({
    super.key,
    required this.exercice,
    required this.progress,
    required this.provider,
    required this.session,
  });
  @override
  State<ClusterWorkoutView> createState() => _ClusterWorkoutViewState();
}

class _ClusterWorkoutViewState extends State<ClusterWorkoutView> {
  bool _isStarted = false;
  int _currentCount = 0, _secondsElapsed = 0;
  Timer? _timer;
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCluster() {
    setState(() => _isStarted = true);
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _secondsElapsed++),
    );
  }

  void _incrementReps() {
    setState(() => _currentCount += widget.exercice.incrementFactor);
    if (_currentCount >= widget.exercice.targetReps) _finishExercise();
  }

  void _finishExercise() {
    _timer?.cancel();
    final log = WorkoutLogEntry(
      exerciseName: widget.exercice.name,
      exerciseType: ExerciseType.cluster,
      setIndex: 1,
      repsCompleted: _currentCount,
      durationSeconds: _secondsElapsed,
    );
    _completeSetOrExercise(
      widget.provider,
      widget.progress,
      widget.session,
      log,
      1,
      0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final min = _secondsElapsed ~/ 60;
    final sec = _secondsElapsed % 60;

    return Column(
      children: [
        Text(
          "GOAL: ${widget.exercice.targetReps} REPS",
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: colorScheme.secondary),
        ),
        const SizedBox(height: 48),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              "$_currentCount",
              style: Theme.of(
                context,
              ).textTheme.displayLarge?.copyWith(fontSize: 100, height: 1),
            ),
            Text(
              " / ${widget.exercice.targetReps}",
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          "${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: _isStarted
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 48),

        if (!_isStarted) ...[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _startCluster,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "START CLUSTER",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ] else ...[
          GestureDetector(
            onTap: _incrementReps,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                "+${widget.exercice.incrementFactor}",
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          TextButton(
            onPressed: _finishExercise,
            child: Text(
              "FINISH EARLY",
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ],
    );
  }
}

class CircuitWorkoutView extends StatefulWidget {
  final Circuit exercice;
  final SessionProgress progress;
  final SessionProvider provider;
  final Session session;
  const CircuitWorkoutView({
    super.key,
    required this.exercice,
    required this.progress,
    required this.provider,
    required this.session,
  });
  @override
  State<CircuitWorkoutView> createState() => _CircuitWorkoutViewState();
}

class _CircuitWorkoutViewState extends State<CircuitWorkoutView> {
  late List<TextEditingController> _controllers;
  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    _controllers = widget.exercice.movements
        .map((m) => TextEditingController(text: m.reps.toString()))
        .toList();
  }

  @override
  void didUpdateWidget(CircuitWorkoutView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress.currentSetIdx != widget.progress.currentSetIdx) {
      for (var c in _controllers) {
        c.dispose();
      }
      _initControllers();
    }
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onDone() {
    FocusScope.of(context).unfocus();
    int totalReps = _controllers.fold(
      0,
      (sum, c) => sum + (int.tryParse(c.text) ?? 0),
    );
    final log = WorkoutLogEntry(
      exerciseName: widget.exercice.name,
      exerciseType: ExerciseType.circuit,
      setIndex: widget.progress.currentSetIdx,
      repsCompleted: totalReps,
      restTimeSeconds: widget.exercice.restSeconds,
    );
    _completeSetOrExercise(
      widget.provider,
      widget.progress,
      widget.session,
      log,
      widget.exercice.sets,
      widget.exercice.restSeconds,
    );
  }

  void _skipRest() {
    final isLastSet = widget.progress.currentSetIdx >= widget.exercice.sets;
    widget.provider.updateProgress(
      widget.progress.copyWith(
        isResting: false,
        restEndTime: 0,
        currentSetIdx: isLastSet ? 1 : widget.progress.currentSetIdx + 1,
        currentExIdx: isLastSet
            ? widget.progress.currentExIdx + 1
            : widget.progress.currentExIdx,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Text(
          "ROUND ${widget.progress.currentSetIdx}/${widget.exercice.sets}",
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: colorScheme.secondary),
        ),
        if (widget.progress.isResting) ...[
          RestTimer(
            endTime: widget.progress.restEndTime,
            totalSec: widget.exercice.restSeconds,
            onFinish: _skipRest,
          ),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: _skipRest,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "SKIP RECOVERY",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Builder(
            builder: (context) {
              final isLastSet =
                  widget.progress.currentSetIdx >= widget.exercice.sets;
              final nextExIdx = isLastSet
                  ? widget.progress.currentExIdx + 1
                  : widget.progress.currentExIdx;
              if (nextExIdx < widget.session.exercices.length) {
                return UpcomingExerciseCard(
                  exercice: widget.session.exercices[nextExIdx],
                  titleLabel: isLastSet ? "UP NEXT" : "NEXT ROUND",
                  nextSetIndex: isLastSet
                      ? null
                      : widget.progress.currentSetIdx + 1,
                  totalSets: isLastSet ? null : widget.exercice.sets,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ] else ...[
          const SizedBox(height: 32),
          ...List.generate(widget.exercice.movements.length, (index) {
            final mov = widget.exercice.movements[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.surfaceContainerHighest),
              ),
              child: Column(
                children: [
                  Text(
                    mov.name.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (mov.weight > 0)
                    Text(
                      "@ ${mov.weight} KG",
                      style: TextStyle(
                        color: colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controllers[index],
                    keyboardType: TextInputType.number,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 60,
                      height: 1.2,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _onDone,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "ROUND COMPLETED",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class IsoMaxWorkoutView extends StatefulWidget {
  final IsoMax exercice;
  final SessionProgress progress;
  final SessionProvider provider;
  final Session session;
  const IsoMaxWorkoutView({
    super.key,
    required this.exercice,
    required this.progress,
    required this.provider,
    required this.session,
  });
  @override
  State<IsoMaxWorkoutView> createState() => _IsoMaxWorkoutViewState();
}

class _IsoMaxWorkoutViewState extends State<IsoMaxWorkoutView> {
  String _phase = "IDLE";
  int _prepTime = 5, _secondsElapsed = 0;
  Timer? _timer;
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() {
      _phase = "COUNTDOWN";
      _prepTime = 5;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_prepTime > 1) {
        setState(() => _prepTime--);
      } else {
        timer.cancel();
        _startHold();
      }
    });
  }

  void _startHold() {
    setState(() {
      _phase = "RUNNING";
      _secondsElapsed = 0;
    });
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _secondsElapsed++),
    );
  }

  void _stopAndSave() {
    _timer?.cancel();
    final log = WorkoutLogEntry(
      exerciseName: widget.exercice.name,
      exerciseType: ExerciseType.isoMax,
      setIndex: widget.progress.currentSetIdx,
      repsCompleted: (_secondsElapsed - 3).clamp(0, 999),
      weightAdded: widget.exercice.weight,
      restTimeSeconds: widget.exercice.restSeconds,
    );
    _completeSetOrExercise(
      widget.provider,
      widget.progress,
      widget.session,
      log,
      widget.exercice.sets,
      widget.exercice.restSeconds,
    );
    if (mounted) {
      setState(() {
        _phase = "IDLE";
        _secondsElapsed = 0;
      });
    }
  }

  void _skipRest() {
    final isLastSet = widget.progress.currentSetIdx >= widget.exercice.sets;
    widget.provider.updateProgress(
      widget.progress.copyWith(
        isResting: false,
        restEndTime: 0,
        currentSetIdx: isLastSet ? 1 : widget.progress.currentSetIdx + 1,
        currentExIdx: isLastSet
            ? widget.progress.currentExIdx + 1
            : widget.progress.currentExIdx,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (widget.progress.isResting) {
      return Column(
        children: [
          RestTimer(
            endTime: widget.progress.restEndTime,
            totalSec: widget.exercice.restSeconds,
            onFinish: _skipRest,
          ),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: _skipRest,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "SKIP RECOVERY",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Builder(
            builder: (context) {
              final isLastSet =
                  widget.progress.currentSetIdx >= widget.exercice.sets;
              final nextExIdx = isLastSet
                  ? widget.progress.currentExIdx + 1
                  : widget.progress.currentExIdx;
              if (nextExIdx < widget.session.exercices.length) {
                return UpcomingExerciseCard(
                  exercice: widget.session.exercices[nextExIdx],
                  titleLabel: isLastSet ? "UP NEXT" : "NEXT SET",
                  nextSetIndex: isLastSet
                      ? null
                      : widget.progress.currentSetIdx + 1,
                  totalSets: isLastSet ? null : widget.exercice.sets,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      );
    }
    return Column(
      children: [
        Text(
          "SET ${widget.progress.currentSetIdx}/${widget.exercice.sets} • ISO MAX",
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: colorScheme.secondary),
        ),
        const SizedBox(height: 48),
        if (_phase == "IDLE") ...[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _startCountdown,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "START",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ] else if (_phase == "COUNTDOWN") ...[
          Text("GET READY", style: Theme.of(context).textTheme.headlineSmall),
          Text(
            "-$_prepTime",
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontSize: 120,
              color: colorScheme.secondary,
            ),
          ),
        ] else if (_phase == "RUNNING") ...[
          Text(
            "HOLD!",
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: colorScheme.primary),
          ),
          Text(
            "$_secondsElapsed",
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontSize: 120,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _stopAndSave,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "STOP & LOG",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class IsoPositionsWorkoutView extends StatefulWidget {
  final IsoPositions exercice;
  final SessionProgress progress;
  final SessionProvider provider;
  final Session session;
  const IsoPositionsWorkoutView({
    super.key,
    required this.exercice,
    required this.progress,
    required this.provider,
    required this.session,
  });
  @override
  State<IsoPositionsWorkoutView> createState() =>
      _IsoPositionsWorkoutViewState();
}

class _IsoPositionsWorkoutViewState extends State<IsoPositionsWorkoutView> {
  String _phase = "IDLE";
  int _prepTime = 5, _currentHoldIndex = 0, _currentHoldTime = 0;
  Timer? _timer;
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startSequence() {
    if (widget.exercice.movements.isEmpty) return;
    setState(() {
      _phase = "PREP";
      _prepTime = 5;
      _currentHoldIndex = 0;
      _currentHoldTime = widget.exercice.movements[0].reps;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_phase == "PREP") {
        if (_prepTime > 1) {
          setState(() => _prepTime--);
        } else {
          setState(() => _phase = "RUNNING");
        }
      } else if (_phase == "RUNNING") {
        if (_currentHoldTime > 1) {
          setState(() => _currentHoldTime--);
        } else {
          if (_currentHoldIndex < widget.exercice.movements.length - 1) {
            setState(() {
              _currentHoldIndex++;
              _currentHoldTime =
                  widget.exercice.movements[_currentHoldIndex].reps;
            });
          } else {
            _stopAndSave();
          }
        }
      }
    });
  }

  void _stopAndSave() {
    _timer?.cancel();
    final log = WorkoutLogEntry(
      exerciseName: widget.exercice.name,
      exerciseType: ExerciseType.isoPositions,
      setIndex: widget.progress.currentSetIdx,
      repsCompleted: widget.exercice.movements.fold(
        0,
        (sum, m) => sum + m.reps,
      ),
      restTimeSeconds: widget.exercice.restSeconds,
    );
    _completeSetOrExercise(
      widget.provider,
      widget.progress,
      widget.session,
      log,
      widget.exercice.sets,
      widget.exercice.restSeconds,
    );
    if (mounted) setState(() => _phase = "IDLE");
  }

  void _skipRest() {
    final isLastSet = widget.progress.currentSetIdx >= widget.exercice.sets;
    widget.provider.updateProgress(
      widget.progress.copyWith(
        isResting: false,
        restEndTime: 0,
        currentSetIdx: isLastSet ? 1 : widget.progress.currentSetIdx + 1,
        currentExIdx: isLastSet
            ? widget.progress.currentExIdx + 1
            : widget.progress.currentExIdx,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (widget.progress.isResting) {
      return Column(
        children: [
          RestTimer(
            endTime: widget.progress.restEndTime,
            totalSec: widget.exercice.restSeconds,
            onFinish: _skipRest,
          ),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: _skipRest,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "SKIP RECOVERY",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Builder(
            builder: (context) {
              final isLastSet =
                  widget.progress.currentSetIdx >= widget.exercice.sets;
              final nextExIdx = isLastSet
                  ? widget.progress.currentExIdx + 1
                  : widget.progress.currentExIdx;
              if (nextExIdx < widget.session.exercices.length) {
                return UpcomingExerciseCard(
                  exercice: widget.session.exercices[nextExIdx],
                  titleLabel: isLastSet ? "UP NEXT" : "NEXT SET",
                  nextSetIndex: isLastSet
                      ? null
                      : widget.progress.currentSetIdx + 1,
                  totalSets: isLastSet ? null : widget.exercice.sets,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      );
    }

    return Column(
      children: [
        Text(
          "SET ${widget.progress.currentSetIdx}/${widget.exercice.sets} • ISO POSITIONS",
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: colorScheme.secondary),
        ),
        const SizedBox(height: 32),
        if (_phase == "IDLE") ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: widget.exercice.movements
                  .map(
                    (m) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            "${m.reps}s",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "${m.name}${m.weight > 0 ? " @ ${m.weight}kg" : ""}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _startSequence,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "START SEQUENCE",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ] else if (_phase == "PREP") ...[
          Text("GET READY", style: Theme.of(context).textTheme.headlineSmall),
          Text(
            "-$_prepTime",
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontSize: 120,
              color: colorScheme.secondary,
            ),
          ),
        ] else if (_phase == "RUNNING") ...[
          ...List.generate(widget.exercice.movements.length, (index) {
            final isActive = index == _currentHoldIndex;
            final mov = widget.exercice.movements[index];
            if (isActive) {
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(24),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border.all(color: colorScheme.primary, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      mov.name.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "$_currentHoldTime",
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 80,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                mov.name.toUpperCase(),
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            );
          }),
        ],
      ],
    );
  }
}

class RestBlockWorkoutView extends StatefulWidget {
  final RestBlock exercice;
  final SessionProgress progress;
  final SessionProvider provider;
  final Session session;
  const RestBlockWorkoutView({
    super.key,
    required this.exercice,
    required this.progress,
    required this.provider,
    required this.session,
  });
  @override
  State<RestBlockWorkoutView> createState() => _RestBlockWorkoutViewState();
}

class _RestBlockWorkoutViewState extends State<RestBlockWorkoutView> {
  @override
  void initState() {
    super.initState();
    if (!widget.progress.isResting) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.provider.updateProgress(
          widget.progress.copyWith(
            isResting: true,
            restEndTime:
                DateTime.now().millisecondsSinceEpoch +
                (widget.exercice.restSeconds * 1000),
          ),
        );
      });
    }
  }

  void _skipRest() {
    final isSessionFinished =
        (widget.progress.currentExIdx >= widget.session.exercices.length - 1);
    widget.provider.updateProgress(
      widget.progress.copyWith(
        isFinished: isSessionFinished,
        isResting: false,
        restEndTime: 0,
        currentSetIdx: 1,
        currentExIdx: widget.progress.currentExIdx + 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.progress.isResting) return const SizedBox.shrink();
    return Column(
      children: [
        Text(
          "REST BLOCK",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
        RestTimer(
          endTime: widget.progress.restEndTime,
          totalSec: widget.exercice.restSeconds,
          onFinish: _skipRest,
        ),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: _skipRest,
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "SKIP RECOVERY",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Builder(
          builder: (context) {
            final nextExIdx = widget.progress.currentExIdx + 1;
            if (nextExIdx < widget.session.exercices.length) {
              return UpcomingExerciseCard(
                exercice: widget.session.exercices[nextExIdx],
                titleLabel: "UP NEXT",
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}

// ==== Composants UI réutilisés ====

class RestTimer extends StatefulWidget {
  final int endTime, totalSec;
  final VoidCallback onFinish;
  final bool isCountdownStyle;
  const RestTimer({
    super.key,
    required this.endTime,
    required this.totalSec,
    required this.onFinish,
    this.isCountdownStyle = false,
  });
  @override
  State<RestTimer> createState() => _RestTimerState();
}

class _RestTimerState extends State<RestTimer> {
  Timer? _timer;
  int _timeLeft = 0;
  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    final remaining =
        ((widget.endTime - DateTime.now().millisecondsSinceEpoch) / 1000)
            .truncate();
    if (remaining <= 0) {
      _timer?.cancel();
      widget.onFinish();
    } else {
      if (mounted) setState(() => _timeLeft = remaining);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get formattedTime {
    if (_timeLeft >= 60) {
      int m = _timeLeft ~/ 60;
      int s = _timeLeft % 60;
      return '$m:${s.toString().padLeft(2, '0')}';
    }
    return '$_timeLeft';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progressRatio = widget.totalSec > 0
        ? (_timeLeft / widget.totalSec).clamp(0.0, 1.0)
        : 0.0;
    final actualProgress = widget.isCountdownStyle
        ? (1.0 - progressRatio)
        : progressRatio;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 220,
            height: 220,
            child: CircularProgressIndicator(
              value: actualProgress,
              strokeWidth: 8,
              strokeCap: StrokeCap.round,
              color: colorScheme.primary,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
          Text(
            formattedTime,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontSize: 72,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class UpcomingExerciseCard extends StatelessWidget {
  final Exercice exercice;
  final String titleLabel;
  final int? nextSetIndex, totalSets;

  const UpcomingExerciseCard({
    super.key,
    required this.exercice,
    required this.titleLabel,
    this.nextSetIndex,
    this.totalSets,
  });

  String _getSummary() {
    final ex = exercice;
    if (nextSetIndex != null && totalSets != null) {
      // Suite du même exercice
      if (ex is Classic) return "${ex.reps} reps @ ${ex.weight}kg";
      if (ex is IsoMax) return "Hold @ ${ex.weight}kg";
      if (ex is Circuit) return "Circuit round";
      return "Next set";
    } else {
      // Début d'un nouvel exercice
      if (ex is Classic) return "${ex.sets}x${ex.reps} @ ${ex.weight}kg";
      if (ex is Amrap) return "AMRAP - ${ex.timeCapMinutes} MIN";
      if (ex is Emom) return "EMOM - ${ex.totalRounds} ROUNDS";
      if (ex is RestPause) return "REST-PAUSE - ${ex.microSets} SETS";
      if (ex is Cluster) return "CLUSTER - ${ex.targetReps} REPS";
      if (ex is Circuit) return "CIRCUIT - ${ex.sets} ROUNDS";
      if (ex is IsoMax) return "ISOMETRIC - MAX HOLD";
      if (ex is IsoPositions) return "ISOMETRIC POSITIONS";
      if (ex is RestBlock) return "REST BLOCK - ${ex.restSeconds}s";
    }
    return "";
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final summary = _getSummary();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.surfaceContainerHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titleLabel,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colorScheme.secondary),
          ),
          const SizedBox(height: 8),
          Text(
            exercice.name.toUpperCase(),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              summary,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SummaryView extends StatelessWidget {
  final String title;
  final List<WorkoutLogEntry> logs;
  final String totalTime;
  const SummaryView({
    super.key,
    required this.title,
    required this.logs,
    required this.totalTime,
  });
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Map<String, List<WorkoutLogEntry>> groupedLogs = {};
    for (var log in logs) {
      groupedLogs.putIfAbsent(log.exerciseName, () => []).add(log);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.surfaceContainerHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "WORKOUT SUMMARY",
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colorScheme.secondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ...groupedLogs.entries.map((entry) {
            final exLogs = entry.value;
            if (exLogs.isEmpty ||
                exLogs.first.exerciseType == ExerciseType.restBlock) {
              return const SizedBox.shrink();
            }
            final type = exLogs.first.exerciseType;
            final setsCount = exLogs.length;
            String detailsStr = "";

            switch (type) {
              case ExerciseType.classic:
                final allSameWeight =
                    exLogs.map((l) => l.weightAdded).toSet().length <= 1;
                if (allSameWeight) {
                  final w = exLogs.first.weightAdded;
                  detailsStr =
                      "$setsCount SETS • [${exLogs.map((l) => l.repsCompleted).join("-")}] REPS${w > 0 ? " @ ${w}kg" : ""}";
                } else {
                  detailsStr =
                      "$setsCount SETS • ${exLogs.map((l) => "${l.repsCompleted}${l.weightAdded > 0 ? " @ ${l.weightAdded}kg" : ""}").join(" / ")}";
                }
                break;
              case ExerciseType.isoMax:
              case ExerciseType.isoPositions:
                detailsStr =
                    "$setsCount SETS • [${exLogs.map((l) => "${l.repsCompleted}s").join("-")}]";
                break;
              case ExerciseType.restPause:
                detailsStr =
                    "$setsCount MICRO-SETS • [${exLogs.map((l) => l.repsCompleted).join("-")}] REPS";
                break;
              case ExerciseType.emom:
                detailsStr =
                    "1 SET • ${exLogs.fold<int>(0, (sum, l) => sum + l.repsCompleted)} TOTAL REPS";
                break;
              case ExerciseType.cluster:
                final min = exLogs.first.durationSeconds ~/ 60;
                final sec = exLogs.first.durationSeconds % 60;
                detailsStr =
                    "1 SET • ${exLogs.first.repsCompleted} REPS IN ${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}";
                break;
              case ExerciseType.amrap:
                detailsStr =
                    "1 SET • ${exLogs.first.durationSeconds ~/ 60} MIN";
                break;
              case ExerciseType.circuit:
                detailsStr = "$setsCount ROUNDS COMPLETED";
                break;
              default:
                break;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    detailsStr,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  "TOTAL TIME",
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  totalTime,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
