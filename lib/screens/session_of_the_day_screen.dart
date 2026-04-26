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
import 'package:wakelock_plus/wakelock_plus.dart';
import '../viewmodels/leveling_provider.dart';

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
    final progress = provider.progress;
    final colorScheme = Theme.of(context).colorScheme;

    final rawActiveSession = progress.sessionId.isNotEmpty
        ? provider.getSessionById(progress.sessionId) ?? sessionOfTheDay
        : sessionOfTheDay;

    Session? activeSession;
    if (rawActiveSession != null) {
      List<Exercise> flattenedExercises = [];
      for (var ex in rawActiveSession.exercises) {
        if (ex is ModuleBlock) {
          flattenedExercises.addAll(ex.exercises);
        } else {
          flattenedExercises.add(ex);
        }
      }
      activeSession = Session(
        id: rawActiveSession.id,
        title: rawActiveSession.title,
        day: rawActiveSession.day,
        exercises: flattenedExercises,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasLoadedHistory) {
        trackerProvider.loadHistory();
        _hasLoadedHistory = true;
      }

      if (progress.startTime > 0 &&
          !progress.isFinished &&
          provider.keepAwake) {
        WakelockPlus.enable();
      } else {
        WakelockPlus.disable();
      }

      if (progress.isFinished &&
          activeSession != null &&
          !progress.isSaved &&
          !_isSaving) {
        _isSaving = true;
        final duration = progress.endTime - progress.startTime;

        final levelingProvider = context.read<LevelingProvider>();

        provider
            .saveCompletedWorkout(activeSession, duration, progress.logs)
            .then((_) async {
              final gainedXp = await levelingProvider.processWorkoutLogs(
                progress.logs,
                provider,
                duration,
              );

              if (!context.mounted) return;

              if (duration < 1800000) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      "Workout too short (< 30 min). No XP earned this time!",
                    ),
                    backgroundColor: colorScheme.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              } else if (gainedXp > 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "🎉 Congrats! You've gained +${gainedXp.toInt()} XP!",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: colorScheme.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }

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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bedtime_rounded,
              size: 80,
              color: colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 24),
            Text(
              "REST DAY",
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      );
    }

    if (progress.isFinished) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary.withValues(alpha: 0.1),
              ),
              child: Icon(
                Icons.emoji_events_rounded,
                size: 64,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            SummaryView(
              title: activeSession.title,
              logs: progress.logs,
              totalTime: _sessionDuration,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: FilledButton(
                onPressed: () => provider.resetSession(),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  elevation: 8,
                  shadowColor: colorScheme.primary.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  activeSession.id != provider.sessionOfTheDay?.id
                      ? "FINISH WORKOUT"
                      : "FINISH & BACK",
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1,
                  ),
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
          transitionBuilder: (Widget child, Animation<double> animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          child: _countdownNumber > 0
              ? Text(
                  "$_countdownNumber",
                  key: ValueKey<int>(_countdownNumber),
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 180,
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
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.check_rounded,
                size: 64,
                color: colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              "WORKOUT DONE",
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            Text(
              "Great job today. Check your history.",
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              height: 56,
              width: 200,
              child: OutlinedButton.icon(
                onPressed: () => _startInitialCountdown(activeSession.id),
                icon: const Icon(Icons.refresh_rounded, size: 24),
                label: const Text(
                  "REDO SESSION",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.onSurface,
                  side: BorderSide(
                    color: colorScheme.surfaceContainerHighest,
                    width: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                activeSession.title.toUpperCase(),
                style: Theme.of(
                  context,
                ).textTheme.headlineLarge?.copyWith(height: 1.2),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 64),
              GestureDetector(
                onTap: () => _startInitialCountdown(activeSession.id),
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.4),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 72,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 64),
              if (activeSession.exercises.isNotEmpty)
                UpcomingExerciseCard(
                  exercise: activeSession.exercises.first,
                  titleLabel: "FIRST EXERCISE",
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      );
    }

    double sessionProgress = activeSession.exercises.isNotEmpty
        ? (progress.currentExIdx / activeSession.exercises.length).clamp(
            0.0,
            1.0,
          )
        : 0.0;

    return Column(
      children: [
        // Top Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).scaffoldBackgroundColor.withValues(alpha: 0.9),
            border: Border(
              bottom: BorderSide(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
              ),
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
                  size: 28,
                ),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      activeSession.title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: sessionProgress,
                        minHeight: 6,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Text(
                _sessionDuration,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
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
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                if (progress.currentExIdx < activeSession.exercises.length) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 40, bottom: 32),
                    child: Text(
                      activeSession.exercises[progress.currentExIdx].name
                          .toUpperCase(),
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(height: 1.2),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  _buildWorkoutRouter(
                    activeSession.exercises[progress.currentExIdx],
                    progress,
                    provider,
                    activeSession,
                  ),
                  const SizedBox(height: 80),
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
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        alignment: Alignment.center,
        child: AlertDialog(
          backgroundColor: colorScheme.surface,
          elevation: 24,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: colorScheme.surfaceContainerHighest,
              width: 1,
            ),
          ),
          title: Text(
            "ABORT WORKOUT?",
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          content: Text(
            "Discard session? No log will be recorded.",
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          actions: [
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: () {
                      provider.resetSession();
                      setState(() => _showCancelDialog = false);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "QUIT WORKOUT",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: TextButton(
                    onPressed: () => setState(() => _showCancelDialog = false),
                    style: TextButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      "RESUME",
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
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
    Exercise exercise,
    SessionProgress progress,
    SessionProvider provider,
    Session session,
  ) {
    final exKey = ValueKey(progress.currentExIdx);

    if (exercise is Classic) {
      return ClassicWorkoutView(
        key: exKey,
        exercise: exercise,
        progress: progress,
        provider: provider,
        session: session,
      );
    }
    if (exercise is Pyramid) {
      return PyramidWorkoutView(
        key: exKey,
        exercise: exercise,
        progress: progress,
        provider: provider,
        session: session,
      );
    }
    if (exercise is MultiEmom) {
      return MultiEmomWorkoutView(
        key: exKey,
        exercise: exercise,
        progress: progress,
        provider: provider,
        session: session,
      );
    }
    if (exercise is Amrap) {
      return AmrapWorkoutView(
        key: exKey,
        exercise: exercise,
        progress: progress,
        provider: provider,
        session: session,
      );
    }
    if (exercise is Emom) {
      return EmomWorkoutView(
        key: exKey,
        exercise: exercise,
        progress: progress,
        provider: provider,
        session: session,
      );
    }
    if (exercise is RestPause) {
      return RestPauseWorkoutView(
        key: exKey,
        exercise: exercise,
        progress: progress,
        provider: provider,
        session: session,
      );
    }
    if (exercise is Cluster) {
      return ClusterWorkoutView(
        key: exKey,
        exercise: exercise,
        progress: progress,
        provider: provider,
        session: session,
      );
    }
    if (exercise is Circuit) {
      return CircuitWorkoutView(
        key: exKey,
        exercise: exercise,
        progress: progress,
        provider: provider,
        session: session,
      );
    }
    if (exercise is IsoMax) {
      return IsoMaxWorkoutView(
        key: exKey,
        exercise: exercise,
        progress: progress,
        provider: provider,
        session: session,
      );
    }
    if (exercise is IsoPositions) {
      return IsoPositionsWorkoutView(
        key: exKey,
        exercise: exercise,
        progress: progress,
        provider: provider,
        session: session,
      );
    }
    if (exercise is RestBlock) {
      return RestBlockWorkoutView(
        key: exKey,
        exercise: exercise,
        progress: progress,
        provider: provider,
        session: session,
      );
    }
    if (exercise is FreeTime) {
      return FreeTimeWorkoutView(
        key: exKey,
        exercise: exercise,
        progress: progress,
        provider: provider,
        session: session,
      );
    }
    return const SizedBox.shrink();
  }
}

// ==========================================
// COMMON TOOLS & DESIGN
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
      (progress.currentExIdx >= session.exercises.length - 1) && isLastSet;

  bool isNextRestBlock = false;
  if (!isSessionFinished &&
      progress.currentExIdx + 1 < session.exercises.length) {
    isNextRestBlock = session.exercises[progress.currentExIdx + 1] is RestBlock;
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
        activeExState: const {}, // Toujours nettoyer l'état à la fin !
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
        activeExState: const {},
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
        activeExState: const {},
      ),
    );
  }
}

InputDecoration _digitalInputDecoration(ColorScheme colorScheme) {
  return InputDecoration(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    filled: true,
    fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
    contentPadding: const EdgeInsets.symmetric(vertical: 24),
  );
}

// ==========================================
// EXERCISE SPECIFIC VIEWS
// ==========================================

class FreeTimeWorkoutView extends StatefulWidget {
  final FreeTime exercise;
  final SessionProgress progress;
  final SessionProvider provider;
  final Session session;
  const FreeTimeWorkoutView({
    super.key,
    required this.exercise,
    required this.progress,
    required this.provider,
    required this.session,
  });
  @override
  State<FreeTimeWorkoutView> createState() => _FreeTimeWorkoutViewState();
}

class _FreeTimeWorkoutViewState extends State<FreeTimeWorkoutView> {
  Timer? _timer;

  bool get _isRunning => widget.progress.activeExState['isRunning'] ?? false;
  int get _accumulatedMillis =>
      widget.progress.activeExState['accumulatedMillis'] ?? 0;
  int get _lastStartTime => widget.progress.activeExState['lastStartTime'] ?? 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isRunning && mounted) {
        setState(() {}); // Déclenche un rebuild pour MAJ l'affichage
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleTimer() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_isRunning) {
      widget.provider.updateProgress(
        widget.progress.copyWith(
          activeExState: {
            'isRunning': false,
            'accumulatedMillis': _accumulatedMillis + (now - _lastStartTime),
            'lastStartTime': 0,
          },
        ),
      );
    } else {
      widget.provider.updateProgress(
        widget.progress.copyWith(
          activeExState: {
            'isRunning': true,
            'accumulatedMillis': _accumulatedMillis,
            'lastStartTime': now,
          },
        ),
      );
    }
  }

  void _finishExercise(int finalSeconds) {
    final log = WorkoutLogEntry(
      exerciseName: widget.exercise.name,
      exerciseType: ExerciseType.freeTime,
      setIndex: 1,
      repsCompleted: finalSeconds,
      durationSeconds: finalSeconds,
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

    int secondsElapsed = _accumulatedMillis ~/ 1000;
    if (_isRunning) {
      secondsElapsed =
          (_accumulatedMillis +
              (DateTime.now().millisecondsSinceEpoch - _lastStartTime)) ~/
          1000;
    }

    final min = secondsElapsed ~/ 60;
    final sec = secondsElapsed % 60;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "FREE TIME • STOPWATCH",
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: colorScheme.primary),
          ),
        ),
        const SizedBox(height: 64),
        Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: _isRunning
                    ? colorScheme.primary.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
            border: Border.all(
              color: _isRunning
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest,
              width: 4,
            ),
          ),
          child: Text(
            "${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}",
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontSize: 72,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: _isRunning ? colorScheme.primary : colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 64),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FloatingActionButton.large(
              onPressed: _toggleTimer,
              backgroundColor: _isRunning
                  ? colorScheme.errorContainer
                  : colorScheme.primary,
              foregroundColor: _isRunning
                  ? colorScheme.onErrorContainer
                  : colorScheme.onPrimary,
              elevation: 8,
              child: Icon(
                _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 40,
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),
        SizedBox(
          width: double.infinity,
          height: 64,
          child: FilledButton(
            onPressed: () => _finishExercise(secondsElapsed),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.secondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              "LOG EXERCISE",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ClassicWorkoutView extends StatefulWidget {
  final Classic exercise;
  final SessionProgress progress;
  final SessionProvider provider;
  final Session session;
  const ClassicWorkoutView({
    super.key,
    required this.exercise,
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
    _repsController.text =
        widget.progress.activeExState['input'] ??
        widget.exercise.reps.toString();
  }

  @override
  void didUpdateWidget(ClassicWorkoutView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress.currentSetIdx != widget.progress.currentSetIdx) {
      _repsController.text =
          widget.progress.activeExState['input'] ??
          widget.exercise.reps.toString();
    }
  }

  void _onDone() {
    final reps = int.tryParse(_repsController.text);
    if (reps == null) return;
    FocusScope.of(context).unfocus();
    final log = WorkoutLogEntry(
      exerciseName: widget.exercise.name,
      exerciseType: ExerciseType.classic,
      setIndex: widget.progress.currentSetIdx,
      repsCompleted: reps,
      weightAdded: widget.exercise.weight,
      restTimeSeconds: widget.exercise.rest,
    );
    _completeSetOrExercise(
      widget.provider,
      widget.progress,
      widget.session,
      log,
      widget.exercise.sets,
      widget.exercise.rest,
    );
  }

  void _skipRest() {
    final isLastSet = widget.progress.currentSetIdx >= widget.exercise.sets;
    widget.provider.updateProgress(
      widget.progress.copyWith(
        isResting: false,
        restEndTime: 0,
        currentSetIdx: isLastSet ? 1 : widget.progress.currentSetIdx + 1,
        currentExIdx: isLastSet
            ? widget.progress.currentExIdx + 1
            : widget.progress.currentExIdx,
        activeExState: const {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final weightLabel = widget.exercise.weight > 0
        ? " @ ${widget.exercise.weight} kg"
        : "";

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "SET ${widget.progress.currentSetIdx}/${widget.exercise.sets} • ${widget.exercise.reps} TARGET REPS$weightLabel",
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: colorScheme.primary),
            textAlign: TextAlign.center,
          ),
        ),
        if (widget.progress.isResting) ...[
          RestTimer(
            endTime: widget.progress.restEndTime,
            totalSec: widget.exercise.rest,
            onFinish: _skipRest,
          ),
          SizedBox(
            height: 64,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _skipRest,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                side: BorderSide(
                  color: colorScheme.surfaceContainerHighest,
                  width: 2,
                ),
              ),
              child: Text(
                "SKIP RECOVERY",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Builder(
            builder: (context) {
              final isLastSet =
                  widget.progress.currentSetIdx >= widget.exercise.sets;
              final nextExIdx = isLastSet
                  ? widget.progress.currentExIdx + 1
                  : widget.progress.currentExIdx;
              if (nextExIdx < widget.session.exercises.length) {
                return UpcomingExerciseCard(
                  exercise: widget.session.exercises[nextExIdx],
                  titleLabel: isLastSet ? "UP NEXT" : "NEXT SET",
                  nextSetIndex: isLastSet
                      ? null
                      : widget.progress.currentSetIdx + 1,
                  totalSets: isLastSet ? null : widget.exercise.sets,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ] else ...[
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: isLight
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
              border: isLight
                  ? null
                  : Border.all(color: colorScheme.surfaceContainerHighest),
            ),
            child: Column(
              children: [
                Text(
                  "REPS COMPLETED",
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _repsController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onChanged: (val) {
                    widget.provider.updateProgress(
                      widget.progress.copyWith(
                        activeExState: {
                          ...widget.progress.activeExState,
                          'input': val,
                        },
                      ),
                    );
                  },
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 80,
                    height: 1,
                    color: colorScheme.primary,
                  ),
                  decoration: _digitalInputDecoration(colorScheme),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 64,
            child: FilledButton(
              onPressed: _onDone,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                elevation: 4,
                shadowColor: colorScheme.primary.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                "LOG SET",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class AmrapWorkoutView extends StatefulWidget {
  final Amrap exercise;
  final SessionProgress progress;
  final SessionProvider provider;
  final Session session;
  const AmrapWorkoutView({
    super.key,
    required this.exercise,
    required this.progress,
    required this.provider,
    required this.session,
  });
  @override
  State<AmrapWorkoutView> createState() => _AmrapWorkoutViewState();
}

class _AmrapWorkoutViewState extends State<AmrapWorkoutView> {
  final _extraRepsCtrl = TextEditingController();

  bool get _isStarted => widget.progress.activeExState['isStarted'] ?? false;
  int get _endTime => widget.progress.activeExState['endTime'] ?? 0;
  int get _roundsCompleted =>
      widget.progress.activeExState['roundsCompleted'] ?? 0;
  bool get _isTimeUp => widget.progress.activeExState['isTimeUp'] ?? false;

  void _startAmrap() {
    FocusScope.of(context).unfocus();
    widget.provider.updateProgress(
      widget.progress.copyWith(
        activeExState: {
          'isStarted': true,
          'endTime':
              DateTime.now().millisecondsSinceEpoch +
              (widget.exercise.timeCapMinutes * 60 * 1000),
          'roundsCompleted': 0,
          'isTimeUp': false,
        },
      ),
    );
  }

  void _onTimeUp() {
    widget.provider.updateProgress(
      widget.progress.copyWith(
        activeExState: {...widget.progress.activeExState, 'isTimeUp': true},
      ),
    );
  }

  void _updateRounds(int newRounds) {
    widget.provider.updateProgress(
      widget.progress.copyWith(
        activeExState: {
          ...widget.progress.activeExState,
          'roundsCompleted': newRounds,
        },
      ),
    );
  }

  void _logScore() {
    FocusScope.of(context).unfocus();
    final extra = int.tryParse(_extraRepsCtrl.text) ?? 0;
    final repsPerRound = widget.exercise.movements.fold(
      0,
      (sum, m) => sum + m.reps,
    );
    final log = WorkoutLogEntry(
      exerciseName: widget.exercise.name,
      exerciseType: ExerciseType.amrap,
      setIndex: 1,
      repsCompleted: (_roundsCompleted * repsPerRound) + extra,
      durationSeconds: widget.exercise.timeCapMinutes * 60,
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
    final isLight = Theme.of(context).brightness == Brightness.light;
    final repsPerRound = widget.exercise.movements.fold(
      0,
      (sum, m) => sum + m.reps,
    );

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "AMRAP • ${widget.exercise.timeCapMinutes} MIN",
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: colorScheme.primary),
          ),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isLight
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                    ),
                  ]
                : null,
            border: isLight
                ? null
                : Border.all(color: colorScheme.surfaceContainerHighest),
          ),
          child: Column(
            children: widget.exercise.movements
                .map(
                  (m) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "${m.reps}x",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: colorScheme.primary,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            "${m.name}${m.weight > 0 ? " @ ${m.weight}kg" : ""}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
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
        const SizedBox(height: 40),

        if (!_isStarted) ...[
          SizedBox(
            width: double.infinity,
            height: 64,
            child: FilledButton(
              onPressed: _startAmrap,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                "START AMRAP",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ] else if (!_isTimeUp) ...[
          RestTimer(
            key: ValueKey(_endTime),
            endTime: _endTime,
            totalSec: widget.exercise.timeCapMinutes * 60,
            onFinish: _onTimeUp,
            isCountdownStyle: true,
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: isLight
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                      ),
                    ]
                  : null,
              border: isLight
                  ? null
                  : Border.all(color: colorScheme.surfaceContainerHighest),
            ),
            child: Column(
              children: [
                Text(
                  "ROUNDS COMPLETED",
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: () {
                        if (_roundsCompleted > 0) {
                          _updateRounds(_roundsCompleted - 1);
                        }
                      },
                      icon: const Icon(Icons.remove_rounded, size: 32),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                    Text(
                      "$_roundsCompleted",
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 80,
                        color: colorScheme.primary,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _updateRounds(_roundsCompleted + 1),
                      icon: Icon(
                        Icons.add_rounded,
                        size: 32,
                        color: colorScheme.onPrimary,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  "(${_roundsCompleted * repsPerRound} reps base)",
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          TextButton(
            onPressed: _onTimeUp,
            child: Text(
              "FINISH EARLY",
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ] else ...[
          Icon(Icons.timer_off_rounded, size: 64, color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            "TIME'S UP!",
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text(
            "$_roundsCompleted ROUNDS COMPLETED",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: isLight
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                      ),
                    ]
                  : null,
              border: isLight
                  ? null
                  : Border.all(color: colorScheme.surfaceContainerHighest),
            ),
            child: Column(
              children: [
                Text(
                  "EXTRA REPS",
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _extraRepsCtrl,
                  keyboardType: TextInputType.number,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 80,
                    height: 1,
                    color: colorScheme.primary,
                  ),
                  decoration: _digitalInputDecoration(
                    colorScheme,
                  ).copyWith(hintText: "0"),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 64,
            child: FilledButton(
              onPressed: _logScore,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                "LOG AMRAP SCORE",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class EmomWorkoutView extends StatefulWidget {
  final Emom exercise;
  final SessionProgress progress;
  final SessionProvider provider;
  final Session session;
  const EmomWorkoutView({
    super.key,
    required this.exercise,
    required this.progress,
    required this.provider,
    required this.session,
  });
  @override
  State<EmomWorkoutView> createState() => _EmomWorkoutViewState();
}

class _EmomWorkoutViewState extends State<EmomWorkoutView> {
  bool get _isStarted => widget.progress.activeExState['isStarted'] ?? false;
  int get _endTime => widget.progress.activeExState['endTime'] ?? 0;

  void _startEmom() {
    widget.provider.updateProgress(
      widget.progress.copyWith(
        activeExState: {
          'isStarted': true,
          'endTime':
              DateTime.now().millisecondsSinceEpoch +
              (widget.exercise.everyXSeconds * 1000),
        },
      ),
    );
  }

  void _onRoundFinished() {
    final currentRound = widget.progress.currentSetIdx;
    if (currentRound < widget.exercise.totalRounds) {
      widget.provider.updateProgress(
        widget.progress.copyWith(
          currentSetIdx: currentRound + 1,
          activeExState: {
            'isStarted': true,
            'endTime':
                DateTime.now().millisecondsSinceEpoch +
                (widget.exercise.everyXSeconds * 1000),
          },
        ),
      );
    } else {
      _finishExercise();
    }
  }

  void _finishExercise() {
    final repsPerRound = widget.exercise.movements.fold(
      0,
      (sum, m) => sum + m.reps,
    );
    final weight = widget.exercise.movements.isNotEmpty
        ? widget.exercise.movements.first.weight
        : 0.0;

    final log = WorkoutLogEntry(
      exerciseName: widget.exercise.name,
      exerciseType: ExerciseType.emom,
      setIndex: 1,
      repsCompleted: repsPerRound * widget.progress.currentSetIdx,
      weightAdded: weight, // On passe le poids pour l'afficher dans le résumé
    );
    _completeSetOrExercise(
      widget.provider,
      widget.progress.copyWith(currentSetIdx: widget.exercise.totalRounds),
      widget.session,
      log,
      widget.exercise.totalRounds,
      0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "ROUND ${widget.progress.currentSetIdx}/${widget.exercise.totalRounds} • EVERY ${widget.exercise.everyXSeconds} SEC",
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: colorScheme.primary),
          ),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isLight
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                    ),
                  ]
                : null,
            border: isLight
                ? null
                : Border.all(color: colorScheme.surfaceContainerHighest),
          ),
          child: Column(
            children: widget.exercise.movements
                .map(
                  (m) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "${m.reps}x",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: colorScheme.primary,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            "${m.name}${m.weight > 0 ? ' @ ${m.weight}kg' : ''}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
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
        const SizedBox(height: 40),

        if (!_isStarted) ...[
          SizedBox(
            width: double.infinity,
            height: 64,
            child: FilledButton(
              onPressed: _startEmom,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                "START EMOM",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ] else ...[
          RestTimer(
            key: ValueKey(_endTime),
            endTime: _endTime,
            totalSec: widget.exercise.everyXSeconds,
            onFinish: _onRoundFinished,
            isCountdownStyle: true,
          ),
          const SizedBox(height: 32),
          TextButton(
            onPressed: _finishExercise,
            child: Text(
              "END EARLY",
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class RestPauseWorkoutView extends StatefulWidget {
  final RestPause exercise;
  final SessionProgress progress;
  final SessionProvider provider;
  final Session session;
  const RestPauseWorkoutView({
    super.key,
    required this.exercise,
    required this.progress,
    required this.provider,
    required this.session,
  });
  @override
  State<RestPauseWorkoutView> createState() => _RestPauseWorkoutViewState();
}

class _RestPauseWorkoutViewState extends State<RestPauseWorkoutView> {
  final _repsController = TextEditingController();

  bool get _isLocalResting =>
      widget.progress.activeExState['isLocalResting'] ?? false;
  int get _endTime => widget.progress.activeExState['endTime'] ?? 0;
  List<int> get _history =>
      List<int>.from(widget.progress.activeExState['history'] ?? []);

  @override
  void initState() {
    super.initState();
    _repsController.text = widget.progress.activeExState['input'] ?? "";
  }

  void _startRest() {
    FocusScope.of(context).unfocus();
    final h = _history;
    h.add(int.tryParse(_repsController.text) ?? 0);
    widget.provider.updateProgress(
      widget.progress.copyWith(
        activeExState: {
          'isLocalResting': true,
          'endTime':
              DateTime.now().millisecondsSinceEpoch +
              (widget.exercise.restSeconds * 1000),
          'history': h,
          'input': '',
        },
      ),
    );
    _repsController.clear();
  }

  void _onRestFinished() {
    widget.provider.updateProgress(
      widget.progress.copyWith(
        currentSetIdx: widget.progress.currentSetIdx + 1,
        activeExState: {
          'isLocalResting': false,
          'history': _history,
          'input': '',
        },
      ),
    );
  }

  void _finishExercise() {
    final finalHistory = [..._history, int.tryParse(_repsController.text) ?? 0];
    FocusScope.of(context).unfocus();
    final List<WorkoutLogEntry> newLogs = List.generate(
      finalHistory.length,
      (i) => WorkoutLogEntry(
        exerciseName: widget.exercise.name,
        exerciseType: ExerciseType.restPause,
        setIndex: i + 1,
        repsCompleted: finalHistory[i],
        restTimeSeconds: widget.exercise.restSeconds,
      ),
    );
    final isLastEx =
        widget.progress.currentExIdx >= widget.session.exercises.length - 1;
    widget.provider.updateProgress(
      widget.progress.copyWith(
        isFinished: isLastEx,
        isResting: false,
        restEndTime: 0,
        currentExIdx: widget.progress.currentExIdx + 1,
        currentSetIdx: 1,
        logs: [...widget.progress.logs, ...newLogs],
        activeExState: const {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final currentSet = widget.progress.currentSetIdx;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "MICRO-SET $currentSet/${widget.exercise.microSets}",
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: colorScheme.primary),
          ),
        ),
        if (_isLocalResting) ...[
          RestTimer(
            key: ValueKey(_endTime),
            endTime: _endTime,
            totalSec: widget.exercise.restSeconds,
            onFinish: _onRestFinished,
          ),
          SizedBox(
            width: double.infinity,
            height: 64,
            child: OutlinedButton(
              onPressed: _onRestFinished,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                side: BorderSide(
                  color: colorScheme.surfaceContainerHighest,
                  width: 2,
                ),
              ),
              child: Text(
                "SKIP REST",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Builder(
            builder: (context) {
              final isLastSet =
                  widget.progress.currentSetIdx >= widget.exercise.microSets;
              final nextExIdx = isLastSet
                  ? widget.progress.currentExIdx + 1
                  : widget.progress.currentExIdx;
              if (nextExIdx < widget.session.exercises.length) {
                return UpcomingExerciseCard(
                  exercise: widget.session.exercises[nextExIdx],
                  titleLabel: isLastSet ? "UP NEXT" : "NEXT MICRO-SET",
                  nextSetIndex: isLastSet
                      ? null
                      : widget.progress.currentSetIdx + 1,
                  totalSets: isLastSet ? null : widget.exercise.microSets,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ] else ...[
          const SizedBox(height: 48),
          if (currentSet < widget.exercise.microSets) ...[
            Text(
              "MAX REPS!",
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontSize: 56,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 48),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: isLight
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                        ),
                      ]
                    : null,
                border: isLight
                    ? null
                    : Border.all(color: colorScheme.surfaceContainerHighest),
              ),
              child: Column(
                children: [
                  Text(
                    "REPS COMPLETED",
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _repsController,
                    keyboardType: TextInputType.number,
                    onChanged: (val) {
                      widget.provider.updateProgress(
                        widget.progress.copyWith(
                          activeExState: {
                            ...widget.progress.activeExState,
                            'input': val,
                          },
                        ),
                      );
                    },
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 80,
                      height: 1,
                      color: colorScheme.primary,
                    ),
                    decoration: _digitalInputDecoration(
                      colorScheme,
                    ).copyWith(hintText: "0"),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: FilledButton(
                onPressed: _startRest,
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  "START ${widget.exercise.restSeconds}S RECOVERY",
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: isLight
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                        ),
                      ]
                    : null,
                border: isLight
                    ? null
                    : Border.all(color: colorScheme.surfaceContainerHighest),
              ),
              child: Column(
                children: [
                  Text(
                    "LAST SET REPS",
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _repsController,
                    keyboardType: TextInputType.number,
                    onChanged: (val) {
                      widget.provider.updateProgress(
                        widget.progress.copyWith(
                          activeExState: {
                            ...widget.progress.activeExState,
                            'input': val,
                          },
                        ),
                      );
                    },
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 80,
                      height: 1,
                      color: colorScheme.primary,
                    ),
                    decoration: _digitalInputDecoration(
                      colorScheme,
                    ).copyWith(hintText: "0"),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: FilledButton(
                onPressed: _finishExercise,
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  "LOG EXERCISE",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1,
                  ),
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
  final Cluster exercise;
  final SessionProgress progress;
  final SessionProvider provider;
  final Session session;
  const ClusterWorkoutView({
    super.key,
    required this.exercise,
    required this.progress,
    required this.provider,
    required this.session,
  });
  @override
  State<ClusterWorkoutView> createState() => _ClusterWorkoutViewState();
}

class _ClusterWorkoutViewState extends State<ClusterWorkoutView> {
  Timer? _timer;

  bool get _isStarted => widget.progress.activeExState['isStarted'] ?? false;
  int get _currentCount => widget.progress.activeExState['currentCount'] ?? 0;
  int get _startTime => widget.progress.activeExState['startTime'] ?? 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isStarted && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCluster() {
    widget.provider.updateProgress(
      widget.progress.copyWith(
        activeExState: {
          'isStarted': true,
          'currentCount': 0,
          'startTime': DateTime.now().millisecondsSinceEpoch,
        },
      ),
    );
  }

  void _incrementReps() {
    final newCount = _currentCount + widget.exercise.incrementFactor;
    if (newCount >= widget.exercise.targetReps) {
      _finishExercise(newCount);
    } else {
      widget.provider.updateProgress(
        widget.progress.copyWith(
          activeExState: {
            ...widget.progress.activeExState,
            'currentCount': newCount,
          },
        ),
      );
    }
  }

  void _finishExercise(int finalCount) {
    final elapsed =
        (DateTime.now().millisecondsSinceEpoch - _startTime) ~/ 1000;
    final log = WorkoutLogEntry(
      exerciseName: widget.exercise.name,
      exerciseType: ExerciseType.cluster,
      setIndex: 1,
      repsCompleted: finalCount,
      durationSeconds: elapsed,
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
    int secondsElapsed = _isStarted
        ? (DateTime.now().millisecondsSinceEpoch - _startTime) ~/ 1000
        : 0;
    final min = secondsElapsed ~/ 60;
    final sec = secondsElapsed % 60;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "GOAL: ${widget.exercise.targetReps} REPS",
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: colorScheme.primary),
          ),
        ),
        const SizedBox(height: 64),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              "$_currentCount",
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontSize: 120,
                height: 1,
                color: colorScheme.primary,
              ),
            ),
            Text(
              " / ${widget.exercise.targetReps}",
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            "${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: _isStarted
                  ? colorScheme.onSurface
                  : colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 64),

        if (!_isStarted) ...[
          SizedBox(
            width: double.infinity,
            height: 64,
            child: FilledButton(
              onPressed: _startCluster,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                "START CLUSTER",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ] else ...[
          GestureDetector(
            onTap: _incrementReps,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                "+${widget.exercise.incrementFactor}",
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),
          TextButton(
            onPressed: () => _finishExercise(_currentCount),
            child: Text(
              "FINISH EARLY",
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class CircuitWorkoutView extends StatefulWidget {
  final Circuit exercise;
  final SessionProgress progress;
  final SessionProvider provider;
  final Session session;
  const CircuitWorkoutView({
    super.key,
    required this.exercise,
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
    List<String> savedInputs = List<String>.from(
      widget.progress.activeExState['inputs'] ?? [],
    );
    _controllers = List.generate(widget.exercise.movements.length, (index) {
      String val = widget.exercise.movements[index].reps.toString();
      if (index < savedInputs.length) val = savedInputs[index];
      return TextEditingController(text: val);
    });
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

  void _saveInputs() {
    final inputs = _controllers.map((c) => c.text).toList();
    widget.provider.updateProgress(
      widget.progress.copyWith(
        activeExState: {...widget.progress.activeExState, 'inputs': inputs},
      ),
    );
  }

  void _onDone() {
    FocusScope.of(context).unfocus();
    int totalReps = _controllers.fold(
      0,
      (sum, c) => sum + (int.tryParse(c.text) ?? 0),
    );
    final log = WorkoutLogEntry(
      exerciseName: widget.exercise.name,
      exerciseType: ExerciseType.circuit,
      setIndex: widget.progress.currentSetIdx,
      repsCompleted: totalReps,
      restTimeSeconds: widget.exercise.restSeconds,
    );
    _completeSetOrExercise(
      widget.provider,
      widget.progress,
      widget.session,
      log,
      widget.exercise.sets,
      widget.exercise.restSeconds,
    );
  }

  void _skipRest() {
    final isLastSet = widget.progress.currentSetIdx >= widget.exercise.sets;
    widget.provider.updateProgress(
      widget.progress.copyWith(
        isResting: false,
        restEndTime: 0,
        currentSetIdx: isLastSet ? 1 : widget.progress.currentSetIdx + 1,
        currentExIdx: isLastSet
            ? widget.progress.currentExIdx + 1
            : widget.progress.currentExIdx,
        activeExState: const {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "ROUND ${widget.progress.currentSetIdx}/${widget.exercise.sets}",
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: colorScheme.primary),
          ),
        ),
        if (widget.progress.isResting) ...[
          RestTimer(
            endTime: widget.progress.restEndTime,
            totalSec: widget.exercise.restSeconds,
            onFinish: _skipRest,
          ),
          SizedBox(
            width: double.infinity,
            height: 64,
            child: OutlinedButton(
              onPressed: _skipRest,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                side: BorderSide(
                  color: colorScheme.surfaceContainerHighest,
                  width: 2,
                ),
              ),
              child: Text(
                "SKIP RECOVERY",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Builder(
            builder: (context) {
              final isLastSet =
                  widget.progress.currentSetIdx >= widget.exercise.sets;
              final nextExIdx = isLastSet
                  ? widget.progress.currentExIdx + 1
                  : widget.progress.currentExIdx;
              if (nextExIdx < widget.session.exercises.length) {
                return UpcomingExerciseCard(
                  exercise: widget.session.exercises[nextExIdx],
                  titleLabel: isLastSet ? "UP NEXT" : "NEXT ROUND",
                  nextSetIndex: isLastSet
                      ? null
                      : widget.progress.currentSetIdx + 1,
                  totalSets: isLastSet ? null : widget.exercise.sets,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ] else ...[
          const SizedBox(height: 40),
          ...List.generate(widget.exercise.movements.length, (index) {
            final mov = widget.exercise.movements[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: isLight
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                        ),
                      ]
                    : null,
                border: isLight
                    ? null
                    : Border.all(color: colorScheme.surfaceContainerHighest),
              ),
              child: Column(
                children: [
                  Text(
                    mov.name.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (mov.weight > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "@ ${mov.weight} KG",
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _controllers[index],
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _saveInputs(),
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 64,
                      height: 1,
                      color: colorScheme.primary,
                    ),
                    decoration: _digitalInputDecoration(colorScheme),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 64,
            child: FilledButton(
              onPressed: _onDone,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                "ROUND COMPLETED",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class IsoMaxWorkoutView extends StatefulWidget {
  final IsoMax exercise;
  final SessionProgress progress;
  final SessionProvider provider;
  final Session session;
  const IsoMaxWorkoutView({
    super.key,
    required this.exercise,
    required this.progress,
    required this.provider,
    required this.session,
  });
  @override
  State<IsoMaxWorkoutView> createState() => _IsoMaxWorkoutViewState();
}

class _IsoMaxWorkoutViewState extends State<IsoMaxWorkoutView> {
  String get _phase => widget.progress.activeExState['phase'] ?? "IDLE";
  int get _timestamp => widget.progress.activeExState['timestamp'] ?? 0;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_phase != "IDLE" && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    widget.provider.updateProgress(
      widget.progress.copyWith(
        activeExState: {
          'phase': 'COUNTDOWN',
          'timestamp': DateTime.now().millisecondsSinceEpoch + 5000,
        },
      ),
    );
  }

  void _startHold() {
    widget.provider.updateProgress(
      widget.progress.copyWith(
        activeExState: {
          'phase': 'RUNNING',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      ),
    );
  }

  void _stopAndSave(int secondsElapsed) {
    final log = WorkoutLogEntry(
      exerciseName: widget.exercise.name,
      exerciseType: ExerciseType.isoMax,
      setIndex: widget.progress.currentSetIdx,
      repsCompleted: (secondsElapsed).clamp(0, 999),
      weightAdded: widget.exercise.weight,
      restTimeSeconds: widget.exercise.restSeconds,
    );
    _completeSetOrExercise(
      widget.provider,
      widget.progress,
      widget.session,
      log,
      widget.exercise.sets,
      widget.exercise.restSeconds,
    );
  }

  void _skipRest() {
    final isLastSet = widget.progress.currentSetIdx >= widget.exercise.sets;
    widget.provider.updateProgress(
      widget.progress.copyWith(
        isResting: false,
        restEndTime: 0,
        currentSetIdx: isLastSet ? 1 : widget.progress.currentSetIdx + 1,
        currentExIdx: isLastSet
            ? widget.progress.currentExIdx + 1
            : widget.progress.currentExIdx,
        activeExState: const {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    int prepTime = 5;
    int secondsElapsed = 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (_phase == "COUNTDOWN") {
      prepTime = ((_timestamp - now) / 1000).ceil();
      if (prepTime <= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_phase == "COUNTDOWN") _startHold();
        });
        prepTime = 0;
      }
    } else if (_phase == "RUNNING") {
      secondsElapsed = ((now - _timestamp) / 1000).floor();
    }

    if (widget.progress.isResting) {
      return Column(
        children: [
          RestTimer(
            endTime: widget.progress.restEndTime,
            totalSec: widget.exercise.restSeconds,
            onFinish: _skipRest,
          ),
          SizedBox(
            width: double.infinity,
            height: 64,
            child: OutlinedButton(
              onPressed: _skipRest,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                side: BorderSide(
                  color: colorScheme.surfaceContainerHighest,
                  width: 2,
                ),
              ),
              child: Text(
                "SKIP RECOVERY",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Builder(
            builder: (context) {
              final isLastSet =
                  widget.progress.currentSetIdx >= widget.exercise.sets;
              final nextExIdx = isLastSet
                  ? widget.progress.currentExIdx + 1
                  : widget.progress.currentExIdx;
              if (nextExIdx < widget.session.exercises.length) {
                return UpcomingExerciseCard(
                  exercise: widget.session.exercises[nextExIdx],
                  titleLabel: isLastSet ? "UP NEXT" : "NEXT SET",
                  nextSetIndex: isLastSet
                      ? null
                      : widget.progress.currentSetIdx + 1,
                  totalSets: isLastSet ? null : widget.exercise.sets,
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "SET ${widget.progress.currentSetIdx}/${widget.exercise.sets} • ISO MAX",
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: colorScheme.primary),
          ),
        ),
        const SizedBox(height: 64),
        if (_phase == "IDLE") ...[
          SizedBox(
            width: double.infinity,
            height: 64,
            child: FilledButton(
              onPressed: _startCountdown,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                "START",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ] else if (_phase == "COUNTDOWN") ...[
          Text(
            "GET READY",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              letterSpacing: 2,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "-$prepTime",
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontSize: 140,
              color: colorScheme.primary,
            ),
          ),
        ] else if (_phase == "RUNNING") ...[
          Text(
            "HOLD!",
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: colorScheme.primary,
              letterSpacing: 2,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "$secondsElapsed",
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontSize: 140,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 64),
          SizedBox(
            width: double.infinity,
            height: 64,
            child: FilledButton(
              onPressed: () => _stopAndSave(secondsElapsed),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                "STOP & LOG",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class IsoPositionsWorkoutView extends StatefulWidget {
  final IsoPositions exercise;
  final SessionProgress progress;
  final SessionProvider provider;
  final Session session;
  const IsoPositionsWorkoutView({
    super.key,
    required this.exercise,
    required this.progress,
    required this.provider,
    required this.session,
  });
  @override
  State<IsoPositionsWorkoutView> createState() =>
      _IsoPositionsWorkoutViewState();
}

class _IsoPositionsWorkoutViewState extends State<IsoPositionsWorkoutView> {
  String get _phase => widget.progress.activeExState['phase'] ?? "IDLE";
  int get _sequenceStartTime =>
      widget.progress.activeExState['sequenceStartTime'] ?? 0;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_phase != "IDLE" && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startSequence() {
    if (widget.exercise.movements.isEmpty) return;
    widget.provider.updateProgress(
      widget.progress.copyWith(
        activeExState: {
          'phase': 'ACTIVE',
          'sequenceStartTime': DateTime.now().millisecondsSinceEpoch,
        },
      ),
    );
  }

  void _stopAndSave() {
    final log = WorkoutLogEntry(
      exerciseName: widget.exercise.name,
      exerciseType: ExerciseType.isoPositions,
      setIndex: widget.progress.currentSetIdx,
      repsCompleted: widget.exercise.movements.fold(
        0,
        (sum, m) => sum + m.reps,
      ),
      restTimeSeconds: widget.exercise.restSeconds,
    );
    _completeSetOrExercise(
      widget.provider,
      widget.progress,
      widget.session,
      log,
      widget.exercise.sets,
      widget.exercise.restSeconds,
    );
  }

  void _skipRest() {
    final isLastSet = widget.progress.currentSetIdx >= widget.exercise.sets;
    widget.provider.updateProgress(
      widget.progress.copyWith(
        isResting: false,
        restEndTime: 0,
        currentSetIdx: isLastSet ? 1 : widget.progress.currentSetIdx + 1,
        currentExIdx: isLastSet
            ? widget.progress.currentExIdx + 1
            : widget.progress.currentExIdx,
        activeExState: const {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    if (widget.progress.isResting) {
      return Column(
        children: [
          RestTimer(
            endTime: widget.progress.restEndTime,
            totalSec: widget.exercise.restSeconds,
            onFinish: _skipRest,
          ),
          SizedBox(
            width: double.infinity,
            height: 64,
            child: OutlinedButton(
              onPressed: _skipRest,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                side: BorderSide(
                  color: colorScheme.surfaceContainerHighest,
                  width: 2,
                ),
              ),
              child: Text(
                "SKIP RECOVERY",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Builder(
            builder: (context) {
              final isLastSet =
                  widget.progress.currentSetIdx >= widget.exercise.sets;
              final nextExIdx = isLastSet
                  ? widget.progress.currentExIdx + 1
                  : widget.progress.currentExIdx;
              if (nextExIdx < widget.session.exercises.length) {
                return UpcomingExerciseCard(
                  exercise: widget.session.exercises[nextExIdx],
                  titleLabel: isLastSet ? "UP NEXT" : "NEXT SET",
                  nextSetIndex: isLastSet
                      ? null
                      : widget.progress.currentSetIdx + 1,
                  totalSets: isLastSet ? null : widget.exercise.sets,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      );
    }

    int prepTime = 5;
    int currentHoldIndex = 0;
    int currentHoldTime = 0;
    String displayPhase = "IDLE";

    if (_phase == "ACTIVE") {
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsedTotal = (now - _sequenceStartTime) ~/ 1000;

      if (elapsedTotal < 5) {
        displayPhase = "PREP";
        prepTime = 5 - elapsedTotal;
      } else {
        displayPhase = "RUNNING";
        int timeConsumed = 5; // Prep time
        bool finished = false;

        for (int i = 0; i < widget.exercise.movements.length; i++) {
          final movDuration =
              widget.exercise.movements[i].reps; // reps is duration here
          if (elapsedTotal < timeConsumed + movDuration) {
            currentHoldIndex = i;
            currentHoldTime = (timeConsumed + movDuration) - elapsedTotal;
            finished = false;
            break;
          }
          timeConsumed += movDuration;
          finished = true;
        }

        if (finished) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_phase == "ACTIVE") _stopAndSave();
          });
          displayPhase = "IDLE"; // Avoid visual glitch on last frame
        }
      }
    } else {
      displayPhase = "IDLE";
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "SET ${widget.progress.currentSetIdx}/${widget.exercise.sets} • ISO POSITIONS",
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: colorScheme.primary),
          ),
        ),
        const SizedBox(height: 40),
        if (displayPhase == "IDLE") ...[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: isLight
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                      ),
                    ]
                  : null,
              border: isLight
                  ? null
                  : Border.all(color: colorScheme.surfaceContainerHighest),
            ),
            child: Column(
              children: widget.exercise.movements
                  .map(
                    (m) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "${m.reps}s",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: colorScheme.primary,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              "${m.name}${m.weight > 0 ? " @ ${m.weight}kg" : ""}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
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
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 64,
            child: FilledButton(
              onPressed: _startSequence,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                "START SEQUENCE",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ] else if (displayPhase == "PREP") ...[
          Text(
            "GET READY",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              letterSpacing: 2,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "-$prepTime",
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontSize: 140,
              color: colorScheme.primary,
            ),
          ),
        ] else if (displayPhase == "RUNNING") ...[
          ...List.generate(widget.exercise.movements.length, (index) {
            final isActive = index == currentHoldIndex;
            final mov = widget.exercise.movements[index];
            if (isActive) {
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: const EdgeInsets.all(32),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  border: Border.all(color: colorScheme.primary, width: 3),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Text(
                      mov.name.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "$currentHoldTime",
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 100,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                mov.name.toUpperCase(),
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}

class RestBlockWorkoutView extends StatefulWidget {
  final RestBlock exercise;
  final SessionProgress progress;
  final SessionProvider provider;
  final Session session;
  const RestBlockWorkoutView({
    super.key,
    required this.exercise,
    required this.progress,
    required this.provider,
    required this.session,
  });
  @override
  State<RestBlockWorkoutView> createState() => _RestBlockWorkoutViewState();
}

class PyramidWorkoutView extends StatefulWidget {
  final Pyramid exercise;
  final SessionProgress progress;
  final SessionProvider provider;
  final Session session;
  const PyramidWorkoutView({
    super.key,
    required this.exercise,
    required this.progress,
    required this.provider,
    required this.session,
  });
  @override
  State<PyramidWorkoutView> createState() => _PyramidWorkoutViewState();
}

class _PyramidWorkoutViewState extends State<PyramidWorkoutView> {
  final _repsController = TextEditingController();
  late List<int> _repSequence;

  @override
  void initState() {
    super.initState();
    _calculateSequence();
    _repsController.text =
        widget.progress.activeExState['input'] ??
        _getTargetRepsForCurrentSet().toString();
  }

  void _calculateSequence() {
    _repSequence = [];
    final min = widget.exercise.minReps;
    final max = widget.exercise.maxReps;
    final inc = widget.exercise.increment.abs() == 0
        ? 1
        : widget.exercise.increment.abs();

    if (widget.exercise.pyramidType == PyramidType.up ||
        widget.exercise.pyramidType == PyramidType.upAndDown) {
      int current = min;
      while (current <= max) {
        _repSequence.add(current);
        current += inc;
      }
      if (_repSequence.last != max) _repSequence.add(max);

      if (widget.exercise.pyramidType == PyramidType.upAndDown) {
        current = _repSequence.last - inc;
        while (current >= min) {
          _repSequence.add(current);
          current -= inc;
        }
        if (_repSequence.last != min) _repSequence.add(min);
      }
    } else {
      int current = max;
      while (current >= min) {
        _repSequence.add(current);
        current -= inc;
      }
      if (_repSequence.last != min) _repSequence.add(min);
    }
  }

  int _getTargetRepsForCurrentSet() {
    int idx = widget.progress.currentSetIdx - 1;
    if (idx >= 0 && idx < _repSequence.length) return _repSequence[idx];
    return 0;
  }

  void _onDone() {
    final reps = int.tryParse(_repsController.text);
    if (reps == null) return;
    FocusScope.of(context).unfocus();
    final log = WorkoutLogEntry(
      exerciseName: widget.exercise.name,
      exerciseType: ExerciseType.pyramid,
      setIndex: widget.progress.currentSetIdx,
      repsCompleted: reps,
      weightAdded: widget.exercise.weight,
      restTimeSeconds: widget.exercise.restSeconds,
    );
    _completeSetOrExercise(
      widget.provider,
      widget.progress,
      widget.session,
      log,
      _repSequence.length,
      widget.exercise.restSeconds,
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && widget.progress.currentSetIdx < _repSequence.length) {
        _repsController.text = _repSequence[widget.progress.currentSetIdx]
            .toString();
      }
    });
  }

  void _skipRest() {
    final isLastSet = widget.progress.currentSetIdx >= _repSequence.length;
    widget.provider.updateProgress(
      widget.progress.copyWith(
        isResting: false,
        restEndTime: 0,
        currentSetIdx: isLastSet ? 1 : widget.progress.currentSetIdx + 1,
        currentExIdx: isLastSet
            ? widget.progress.currentExIdx + 1
            : widget.progress.currentExIdx,
        activeExState: const {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final totalSets = _repSequence.length;
    final targetReps = _getTargetRepsForCurrentSet();
    final weightLabel = widget.exercise.weight > 0
        ? " @ ${widget.exercise.weight} kg"
        : "";

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "STEP ${widget.progress.currentSetIdx}/$totalSets • $targetReps TARGET REPS$weightLabel",
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: colorScheme.primary),
          ),
        ),
        if (widget.progress.isResting) ...[
          RestTimer(
            endTime: widget.progress.restEndTime,
            totalSec: widget.exercise.restSeconds,
            onFinish: _skipRest,
          ),
          SizedBox(
            width: double.infinity,
            height: 64,
            child: OutlinedButton(
              onPressed: _skipRest,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                side: BorderSide(
                  color: colorScheme.surfaceContainerHighest,
                  width: 2,
                ),
              ),
              child: Text(
                "SKIP RECOVERY",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Builder(
            builder: (context) {
              final isLastSet =
                  widget.progress.currentSetIdx >= _repSequence.length;
              final nextExIdx = isLastSet
                  ? widget.progress.currentExIdx + 1
                  : widget.progress.currentExIdx;
              if (nextExIdx < widget.session.exercises.length) {
                return UpcomingExerciseCard(
                  exercise: widget.session.exercises[nextExIdx],
                  titleLabel: isLastSet ? "UP NEXT" : "NEXT STEP",
                  nextSetIndex: isLastSet
                      ? null
                      : widget.progress.currentSetIdx + 1,
                  totalSets: isLastSet ? null : _repSequence.length,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ] else ...[
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: isLight
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                      ),
                    ]
                  : null,
              border: isLight
                  ? null
                  : Border.all(color: colorScheme.surfaceContainerHighest),
            ),
            child: Column(
              children: [
                Text(
                  "REPS COMPLETED",
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _repsController,
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    widget.provider.updateProgress(
                      widget.progress.copyWith(
                        activeExState: {
                          ...widget.progress.activeExState,
                          'input': val,
                        },
                      ),
                    );
                  },
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 80,
                    height: 1,
                    color: colorScheme.primary,
                  ),
                  decoration: _digitalInputDecoration(colorScheme),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 64,
            child: FilledButton(
              onPressed: _onDone,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                "LOG STEP",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class MultiEmomWorkoutView extends StatefulWidget {
  final MultiEmom exercise;
  final SessionProgress progress;
  final SessionProvider provider;
  final Session session;
  const MultiEmomWorkoutView({
    super.key,
    required this.exercise,
    required this.progress,
    required this.provider,
    required this.session,
  });
  @override
  State<MultiEmomWorkoutView> createState() => _MultiEmomWorkoutViewState();
}

class _MultiEmomWorkoutViewState extends State<MultiEmomWorkoutView> {
  bool get _isStarted => widget.progress.activeExState['isStarted'] ?? false;
  int get _endTime => widget.progress.activeExState['endTime'] ?? 0;

  int get _totalIntervals =>
      widget.exercise.minutes.length * widget.exercise.totalRounds;

  EmomMinuteGroup get _currentMinuteData {
    if (widget.exercise.minutes.isEmpty) {
      return EmomMinuteGroup(minuteIndex: 1, movements: []);
    }
    return widget.exercise.minutes[(widget.progress.currentSetIdx - 1) %
        widget.exercise.minutes.length];
  }

  void _startEmom() {
    if (widget.exercise.minutes.isEmpty) return;
    widget.provider.updateProgress(
      widget.progress.copyWith(
        activeExState: {
          'isStarted': true,
          'endTime':
              DateTime.now().millisecondsSinceEpoch +
              (widget.exercise.everyXSeconds * 1000),
        },
      ),
    );
  }

  void _onMinuteFinished() {
    final currentMin = widget.progress.currentSetIdx;
    if (currentMin < _totalIntervals) {
      widget.provider.updateProgress(
        widget.progress.copyWith(
          currentSetIdx: currentMin + 1,
          activeExState: {
            'isStarted': true,
            'endTime':
                DateTime.now().millisecondsSinceEpoch +
                (widget.exercise.everyXSeconds * 1000),
          },
        ),
      );
    } else {
      _finishExercise();
    }
  }

  void _finishExercise() {
    int totalRepsDone = 0;
    for (var mGroup in widget.exercise.minutes) {
      totalRepsDone += mGroup.movements.fold(0, (sum, m) => sum + m.reps);
    }
    totalRepsDone *= widget.exercise.totalRounds;

    final log = WorkoutLogEntry(
      exerciseName: widget.exercise.name,
      exerciseType: ExerciseType.multiEmom,
      setIndex: 1,
      repsCompleted: totalRepsDone,
      durationSeconds: _totalIntervals * widget.exercise.everyXSeconds,
    );
    _completeSetOrExercise(
      widget.provider,
      widget.progress.copyWith(currentSetIdx: _totalIntervals),
      widget.session,
      log,
      _totalIntervals,
      0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final currentGroup = _currentMinuteData;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "ROUND ${widget.progress.currentSetIdx}/$_totalIntervals • EVERY ${widget.exercise.everyXSeconds} SEC",
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: colorScheme.primary),
          ),
        ),
        const SizedBox(height: 32),

        if (!_isStarted) ...[
          ...widget.exercise.minutes.map(
            (mGroup) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 8),
                  child: Text(
                    "MINUTE ${mGroup.minuteIndex}",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: colorScheme.primary,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: isLight
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 20,
                            ),
                          ]
                        : null,
                    border: isLight
                        ? null
                        : Border.all(
                            color: colorScheme.surfaceContainerHighest,
                          ),
                  ),
                  child: Column(
                    children: mGroup.movements.isEmpty
                        ? [
                            const Text(
                              "REST / NO MOVEMENTS",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ]
                        : mGroup.movements
                              .map(
                                (mov) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primary.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          "${mov.reps}x",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: colorScheme.primary,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          "${mov.name.toUpperCase()}${mov.weight > 0 ? " @ ${mov.weight}kg" : ""}",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
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
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 64,
            child: FilledButton(
              onPressed: _startEmom,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                "START CIRCUIT",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: isLight
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                      ),
                    ]
                  : null,
              border: isLight
                  ? null
                  : Border.all(color: colorScheme.surfaceContainerHighest),
            ),
            child: Column(
              children: [
                Text(
                  "MINUTE ${currentGroup.minuteIndex}",
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ...currentGroup.movements.map(
                  (m) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "${m.reps}x",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: colorScheme.primary,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            m.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (currentGroup.movements.isEmpty)
                  const Text(
                    "REST / NO MOVEMENTS",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          RestTimer(
            key: ValueKey(_endTime),
            endTime: _endTime,
            totalSec: widget.exercise.everyXSeconds,
            onFinish: _onMinuteFinished,
            isCountdownStyle: true,
          ),
          const SizedBox(height: 40),
          Builder(
            builder: (context) {
              final currentMinTotal = widget.progress.currentSetIdx;
              if (currentMinTotal < _totalIntervals) {
                final nextMinuteData = widget
                    .exercise
                    .minutes[currentMinTotal % widget.exercise.minutes.length];
                String summary = nextMinuteData.movements.isEmpty
                    ? "REST"
                    : nextMinuteData.movements
                          .map((m) => "${m.reps}x ${m.name}")
                          .join(" • ");
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "UP NEXT",
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "MINUTE ${nextMinuteData.minuteIndex}",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        summary,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                final nextExIdx = widget.progress.currentExIdx + 1;
                if (nextExIdx < widget.session.exercises.length) {
                  return UpcomingExerciseCard(
                    exercise: widget.session.exercises[nextExIdx],
                    titleLabel: "UP NEXT",
                  );
                }
                return const SizedBox.shrink();
              }
            },
          ),
          const SizedBox(height: 32),
          TextButton(
            onPressed: _finishExercise,
            child: Text(
              "END EARLY",
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ],
    );
  }
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
                (widget.exercise.restSeconds * 1000),
          ),
        );
      });
    }
  }

  void _skipRest() {
    final isSessionFinished =
        (widget.progress.currentExIdx >= widget.session.exercises.length - 1);
    widget.provider.updateProgress(
      widget.progress.copyWith(
        isFinished: isSessionFinished,
        isResting: false,
        restEndTime: 0,
        currentSetIdx: 1,
        currentExIdx: widget.progress.currentExIdx + 1,
        activeExState: const {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.progress.isResting) return const SizedBox.shrink();
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            "REST BLOCK",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 24),
        RestTimer(
          endTime: widget.progress.restEndTime,
          totalSec: widget.exercise.restSeconds,
          onFinish: _skipRest,
        ),
        SizedBox(
          width: double.infinity,
          height: 64,
          child: OutlinedButton(
            onPressed: _skipRest,
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              side: BorderSide(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                width: 2,
              ),
            ),
            child: Text(
              "SKIP RECOVERY",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),
        Builder(
          builder: (context) {
            final nextExIdx = widget.progress.currentExIdx + 1;
            if (nextExIdx < widget.session.exercises.length) {
              return UpcomingExerciseCard(
                exercise: widget.session.exercises[nextExIdx],
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

// ==== Reusable UI Components ====

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
    final isLight = Theme.of(context).brightness == Brightness.light;
    final progressRatio = widget.totalSec > 0
        ? (_timeLeft / widget.totalSec).clamp(0.0, 1.0)
        : 0.0;
    final actualProgress = widget.isCountdownStyle
        ? (1.0 - progressRatio)
        : progressRatio;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.surface,
              boxShadow: isLight
                  ? [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ]
                  : null,
            ),
          ),
          SizedBox(
            width: 240,
            height: 240,
            child: CircularProgressIndicator(
              value: actualProgress,
              strokeWidth: 12,
              strokeCap: StrokeCap.round,
              color: colorScheme.primary,
              backgroundColor: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
            ),
          ),
          Text(
            formattedTime,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontSize: 80,
              color: colorScheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class UpcomingExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final String titleLabel;
  final int? nextSetIndex, totalSets;

  const UpcomingExerciseCard({
    super.key,
    required this.exercise,
    required this.titleLabel,
    this.nextSetIndex,
    this.totalSets,
  });

  String _getSummary() {
    final ex = exercise;
    if (nextSetIndex != null && totalSets != null) {
      if (ex is Classic) return "Set $nextSetIndex of $totalSets";
      if (ex is Pyramid) return "Step $nextSetIndex of $totalSets";
      if (ex is IsoMax) return "Hold @ ${ex.weight}kg";
      if (ex is Circuit) return "Round $nextSetIndex of $totalSets";
      if (ex is Emom) return "Round $nextSetIndex of $totalSets";
      if (ex is MultiEmom) return "Interval $nextSetIndex of $totalSets";
      if (ex is Amrap) return "Ongoing";
      return "Next set";
    } else {
      if (ex is Classic) return "${ex.sets}x${ex.reps} @ ${ex.weight}kg";
      if (ex is Pyramid) return "PYRAMID - MAX ${ex.maxReps} REPS";
      if (ex is MultiEmom) return "MULTI-EMOM - ${ex.totalRounds} CIRCUITS";
      if (ex is Amrap) return "AMRAP - ${ex.timeCapMinutes} MIN";
      if (ex is Emom) return "EMOM - ${ex.totalRounds} ROUNDS";
      if (ex is RestPause) return "REST-PAUSE - ${ex.microSets} SETS";
      if (ex is Cluster) return "CLUSTER - ${ex.targetReps} REPS";
      if (ex is Circuit) return "CIRCUIT - ${ex.sets} ROUNDS";
      if (ex is IsoMax) return "ISOMETRIC - MAX HOLD";
      if (ex is IsoPositions) return "ISOMETRIC POSITIONS";
      if (ex is RestBlock) return "REST BLOCK - ${ex.restSeconds}s";
      if (ex is FreeTime) return "FREE TIME (Stopwatch)";
    }
    return "";
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final summary = _getSummary();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isLight
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
        border: isLight
            ? null
            : Border.all(color: colorScheme.surfaceContainerHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.forward_rounded, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                titleLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            exercise.name.toUpperCase(),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              summary,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 16,
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
    final isLight = Theme.of(context).brightness == Brightness.light;
    final Map<String, List<WorkoutLogEntry>> groupedLogs = {};
    for (var log in logs) {
      groupedLogs.putIfAbsent(log.exerciseName, () => []).add(log);
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isLight
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                ),
              ]
            : null,
        border: isLight
            ? null
            : Border.all(color: colorScheme.surfaceContainerHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "WORKOUT SUMMARY",
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.primary,
              letterSpacing: 2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            title.toUpperCase(),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
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
              case ExerciseType.pyramid:
                detailsStr =
                    "$setsCount SETS • PYRAMID [${exLogs.map((l) => l.repsCompleted).join("-")}] REPS";
                break;
              case ExerciseType.multiEmom:
                detailsStr = "1 SET • CIRCUIT EMOM COMPLETED";
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
                final w = exLogs.first.weightAdded;
                detailsStr =
                    "1 SET • ${exLogs.fold<int>(0, (sum, l) => sum + l.repsCompleted)} TOTAL REPS${w > 0 ? ' @ ${w}kg' : ''}";
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
              case ExerciseType.freeTime:
                final duration = exLogs.first.durationSeconds;
                final min = duration ~/ 60;
                final sec = duration % 60;
                detailsStr =
                    "1 SET • ${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}";
                break;
              default:
                break;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detailsStr,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  "TOTAL TIME",
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  totalTime,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: colorScheme.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
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
