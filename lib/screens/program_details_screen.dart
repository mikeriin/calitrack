// lib/screens/program_details_screen.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import '../main.dart'; // pour progressRepository
import '../models/workout_models.dart';
import '../viewmodels/session_provider.dart';

class ProgramDetailsScreen extends StatefulWidget {
  final String programId;
  const ProgramDetailsScreen({super.key, required this.programId});
  @override
  State<ProgramDetailsScreen> createState() => _ProgramDetailsScreenState();
}

class _ProgramDetailsScreenState extends State<ProgramDetailsScreen> {
  Future<void> _handleExportProgram(
    BuildContext context,
    Program program,
  ) async {
    try {
      final jsonStr = jsonEncode(program.toMap());
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
        final fileName = "${program.name.replaceAll(' ', '_')}_export.json";
        final file = File('$targetDir/$fileName');
        await file.writeAsString(jsonStr);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Program saved to $targetDir/$fileName',
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
    }
  }

  void _showAddOptions(BuildContext context, Program program) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.only(bottom: 32, top: 24, left: 8, right: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.view_week_rounded,
                  color: colorScheme.secondary,
                ),
              ),
              title: const Text(
                "NEW WEEK",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              subtitle: const Text("Add an empty week to the program"),
              onTap: () {
                Navigator.pop(ctx);
                program.weeks.add(
                  ProgramWeek(name: "Week ${program.weeks.length + 1}"),
                );
                context.read<SessionProvider>().updateProgram(program);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.fitness_center_rounded,
                  color: colorScheme.primary,
                ),
              ),
              title: const Text(
                "NEW WORKOUT",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              subtitle: const Text("Create a session inside this program"),
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (ctx) => _ProgramSessionDialog(program: program),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<SessionProvider>();
    final program = sessionProvider.allPrograms.firstWhere(
      (p) => p.id == widget.programId,
      orElse: () => Program(name: "Error"),
    );
    final colorScheme = Theme.of(context).colorScheme;
    final bool isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    List<dynamic> flatItems = [];
    for (var week in program.weeks) {
      flatItems.add(week);
      flatItems.addAll(week.sessions);
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: isKeyboardOpen
          ? null
          : Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  FloatingActionButton.extended(
                    onPressed: () => _showAddOptions(context, program),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        program.name.toUpperCase(),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${program.weeks.length} WEEKS",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colorScheme.secondary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.ios_share_rounded, size: 28),
                  color: colorScheme.primary,
                  tooltip: "Export Program",
                  onPressed: () => _handleExportProgram(context, program),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
          itemCount: flatItems.length + 1,
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
            if (oldIndex >= flatItems.length) return;
            if (newIndex > flatItems.length) newIndex = flatItems.length;
            if (oldIndex < newIndex) newIndex -= 1;
            final item = flatItems.removeAt(oldIndex);
            flatItems.insert(newIndex, item);

            List<ProgramWeek> newWeeks = [];
            ProgramWeek? currentWeek;
            for (var flatItem in flatItems) {
              if (flatItem is ProgramWeek) {
                currentWeek = ProgramWeek(
                  id: flatItem.id,
                  name: flatItem.name,
                  sessions: [],
                );
                newWeeks.add(currentWeek);
              } else if (flatItem is Session) {
                if (currentWeek != null) {
                  currentWeek.sessions.add(flatItem);
                } else {
                  currentWeek = ProgramWeek(
                    name: "Week 1",
                    sessions: [flatItem],
                  );
                  newWeeks.add(currentWeek);
                }
              }
            }
            program.weeks = newWeeks;
            sessionProvider.updateProgram(program);
          },
          itemBuilder: (context, index) {
            if (index == flatItems.length) {
              return Padding(
                key: const ValueKey("footer_clean_prog"),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      for (var week in program.weeks) {
                        Map<Day, Session> merged = {};
                        for (var session in week.sessions) {
                          if (merged.containsKey(session.day)) {
                            merged[session.day]!.exercises.addAll(
                              session.exercises,
                            );
                          } else {
                            merged[session.day] = Session(
                              id: session.id,
                              title: session.title,
                              day: session.day,
                              exercises: List.from(session.exercises),
                            );
                          }
                        }
                        week.sessions = merged.values.toList();
                      }
                      sessionProvider.updateProgram(program);
                    },
                    icon: const Icon(Icons.cleaning_services_rounded, size: 24),
                    label: const Text(
                      "CLEAN PROGRAM",
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

            final item = flatItems[index];
            if (item is ProgramWeek) {
              return WeekCard(
                key: ValueKey("week_${item.id}"),
                week: item,
                program: program,
                index: index,
              );
            } else if (item is Session) {
              bool isFirst = false;
              if (index > 0 && flatItems[index - 1] is ProgramWeek) {
                isFirst = true;
              }
              bool isLast = true;
              if (index + 1 < flatItems.length &&
                  flatItems[index + 1] is Session) {
                isLast = false;
              }
              return ProgramSessionCard(
                key: ValueKey("sess_${item.id}"),
                session: item,
                program: program,
                index: index,
                isFirstSessionOfWeek: isFirst,
                isLastSessionOfWeek: isLast,
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class WeekCard extends StatefulWidget {
  final ProgramWeek week;
  final Program program;
  final int index;
  const WeekCard({
    super.key,
    required this.week,
    required this.program,
    required this.index,
  });
  @override
  State<WeekCard> createState() => _WeekCardState();
}

class _WeekCardState extends State<WeekCard> {
  bool _isExpanded = false;
  late TextEditingController _titleCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.week.name);
  }

  @override
  void didUpdateWidget(WeekCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.week != widget.week) _titleCtrl.text = widget.week.name;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _saveInlineEdits() {
    widget.week.name = _titleCtrl.text.trim().isEmpty
        ? "Unnamed Week"
        : _titleCtrl.text.trim();
    context.read<SessionProvider>().updateProgram(widget.program);
  }

  void _handleTap() {
    if (_isExpanded) {
      setState(() => _isExpanded = false);
      _saveInlineEdits();
    } else {
      setState(() => _isExpanded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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
                ? colorScheme.secondary
                : (isLight
                      ? Colors.transparent
                      : colorScheme.surfaceContainerHighest),
            width: _isExpanded ? 2 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleTap,
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.view_week_rounded,
                          color: colorScheme.secondary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          widget.week.name.toUpperCase(),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: colorScheme.onSurface,
                              ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 24,
                          color: colorScheme.error,
                        ),
                        onPressed: () {
                          widget.program.weeks.removeWhere(
                            (w) => w.id == widget.week.id,
                          );
                          context.read<SessionProvider>().updateProgram(
                            widget.program,
                          );
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.error.withValues(
                            alpha: 0.1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: !_isExpanded
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: TextField(
                            controller: _titleCtrl,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              labelText: "Week Name",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                              isDense: true,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProgramSessionCard extends StatefulWidget {
  final Session session;
  final Program program;
  final int index;
  final bool isFirstSessionOfWeek;
  final bool isLastSessionOfWeek;
  const ProgramSessionCard({
    super.key,
    required this.session,
    required this.program,
    required this.index,
    this.isFirstSessionOfWeek = false,
    this.isLastSessionOfWeek = false,
  });
  @override
  State<ProgramSessionCard> createState() => _ProgramSessionCardState();
}

class _ProgramSessionCardState extends State<ProgramSessionCard> {
  bool _isExpanded = false;
  late TextEditingController _titleCtrl;
  late Day _selectedDay;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.session.title);
    _selectedDay = widget.session.day;
  }

  @override
  void didUpdateWidget(ProgramSessionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      _titleCtrl.text = widget.session.title;
      _selectedDay = widget.session.day;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _saveInlineEdits() {
    final updatedSession = Session(
      id: widget.session.id,
      title: _titleCtrl.text.trim().isEmpty
          ? "Unnamed Workout"
          : _titleCtrl.text.trim(),
      day: _selectedDay,
      exercises: widget.session.exercises,
    );
    context.read<SessionProvider>().updateSession(updatedSession);
  }

  void _handleTap() {
    if (_isExpanded) {
      setState(() => _isExpanded = false);
      _saveInlineEdits();
    } else {
      context.push('/sessions/details/${widget.session.id}');
    }
  }

  void _handleLongPress() {
    if (!_isExpanded) setState(() => _isExpanded = true);
  }

  Future<void> _handleExportFile(BuildContext context) async {
    try {
      final jsonStr = jsonEncode(widget.session.toMap());
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
        final fileName =
            "${widget.session.title.replaceAll(' ', '_')}_export.json";
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final isCompleted = widget.program.completedSessionIds.contains(
      widget.session.id,
    );
    final realExercisesCount = widget.session.exercises
        .where((e) => e is! RestBlock)
        .length;
    final lineColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.3);
    final topOffset = widget.isFirstSessionOfWeek ? -12.0 : 0.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: topOffset,
          bottom: widget.isLastSessionOfWeek ? null : 0,
          height: widget.isLastSessionOfWeek ? (60.0 - topOffset) : null,
          left: 54, // Centré avec l'icône Week
          child: Container(
            width: 3,
            decoration: BoxDecoration(
              color: lineColor,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        Positioned(
          top: 58,
          left: 54,
          width: 16,
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              color: lineColor,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(70, 8, 24, 12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
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
                    : (isCompleted
                          ? colorScheme.primary.withValues(alpha: 0.5)
                          : (isLight
                                ? Colors.transparent
                                : colorScheme.surfaceContainerHighest)),
                width: _isExpanded || isCompleted ? 2 : 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _handleTap,
                onLongPress: _handleLongPress,
                borderRadius: BorderRadius.circular(20),
                child: Opacity(
                  opacity: isCompleted && !_isExpanded ? 0.7 : 1.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.session.title.toUpperCase(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: colorScheme.onSurface,
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
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
                                          widget.session.day.dayOut
                                              .toUpperCase(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: colorScheme.primary,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 12,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          "$realExercisesCount EXERCISE(S)",
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (isCompleted)
                              Padding(
                                padding: const EdgeInsets.only(right: 12.0),
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  color: colorScheme.primary,
                                  size: 32,
                                ),
                              ),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                color: colorScheme.error,
                                size: 24,
                              ),
                              onPressed: () => context
                                  .read<SessionProvider>()
                                  .deleteSession(widget.session.id),
                              style: IconButton.styleFrom(
                                backgroundColor: colorScheme.error.withValues(
                                  alpha: 0.1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        child: !_isExpanded
                            ? const SizedBox(width: double.infinity)
                            : Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  20,
                                  20,
                                ),
                                child: Column(
                                  children: [
                                    TextField(
                                      controller: _titleCtrl,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      decoration: InputDecoration(
                                        labelText: "Title",
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        filled: true,
                                        fillColor: colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    DropdownButtonFormField<Day>(
                                      initialValue: _selectedDay,
                                      decoration: InputDecoration(
                                        labelText: "Day",
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        filled: true,
                                        fillColor: colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.3),
                                      ),
                                      items: Day.values
                                          .map(
                                            (day) => DropdownMenuItem(
                                              value: day,
                                              child: Text(
                                                day.dayOut.toUpperCase(),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => _selectedDay = val);
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 24),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 56,
                                      child: OutlinedButton.icon(
                                        onPressed: () =>
                                            _handleExportFile(context),
                                        icon: const Icon(
                                          Icons.ios_share_rounded,
                                          size: 20,
                                        ),
                                        label: const Text(
                                          "EXPORT (.JSON)",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          side: BorderSide(
                                            color: colorScheme.primary,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgramSessionDialog extends StatefulWidget {
  final Program program;
  const _ProgramSessionDialog({required this.program});
  @override
  State<_ProgramSessionDialog> createState() => _ProgramSessionDialogState();
}

class _ProgramSessionDialogState extends State<_ProgramSessionDialog> {
  late TextEditingController _titleController;
  Day _selectedDay = Day.monday;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colorScheme.surfaceContainerHighest, width: 1),
      ),
      title: Text(
        "NEW WORKOUT",
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w900,
        ),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            style: const TextStyle(fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: "Title",
              hintText: "e.g. Pull Day A",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<Day>(
            initialValue: _selectedDay,
            decoration: InputDecoration(
              labelText: "Assigned Day",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
            ),
            items: Day.values
                .map(
                  (day) => DropdownMenuItem(
                    value: day,
                    child: Text(
                      day.dayOut.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                )
                .toList(),
            onChanged: (Day? newValue) {
              if (newValue != null) setState(() => _selectedDay = newValue);
            },
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.all(24),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  "CANCEL",
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  if (_titleController.text.trim().isNotEmpty) {
                    final newSession = Session(
                      title: _titleController.text.trim(),
                      day: _selectedDay,
                    );
                    if (widget.program.weeks.isEmpty) {
                      widget.program.weeks.add(
                        ProgramWeek(name: "Week 1", sessions: [newSession]),
                      );
                    } else {
                      widget.program.weeks.last.sessions.add(newSession);
                    }
                    context.read<SessionProvider>().updateProgram(
                      widget.program,
                    );
                    Navigator.pop(context);
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "CREATE",
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
