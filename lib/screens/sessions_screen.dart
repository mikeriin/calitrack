// lib/screens/sessions_screen.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_selector/file_selector.dart';
import '../main.dart';
import '../models/workout_models.dart';
import '../viewmodels/session_provider.dart';
import '../viewmodels/asset_provider.dart';

class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  void _showCreateOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
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
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.calendar_month_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              title: const Text(
                "NEW PROGRAM",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              subtitle: const Text("Create a structured multi-week plan"),
              onTap: () {
                Navigator.pop(ctx);
                _showProgramDialog(context);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.fitness_center_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              title: const Text(
                "NEW STANDALONE WORKOUT",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              subtitle: const Text("Create a single day session"),
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (context) => const SessionDialog(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showProgramDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const ProgramDialog());
  }

  Future<void> _handleImportSession(BuildContext context) async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'JSON Files',
        extensions: <String>['json'],
      );
      final XFile? file = await openFile(
        acceptedTypeGroups: <XTypeGroup>[typeGroup],
      );
      if (file != null) {
        final jsonString = await file.readAsString();
        if (!context.mounted) return;
        await context.read<SessionProvider>().importSessionFromJson(jsonString);
        if (!context.mounted) return;
        await context.read<AssetProvider>().loadAssets();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Workout imported successfully!',
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
      debugPrint("Import Error: $e");
    }
  }

  Future<void> _handleImportProgram(BuildContext context) async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'JSON Files',
        extensions: <String>['json'],
      );
      final XFile? file = await openFile(
        acceptedTypeGroups: <XTypeGroup>[typeGroup],
      );
      if (file != null) {
        final jsonString = await file.readAsString();
        if (!context.mounted) return;
        await context.read<SessionProvider>().importProgramFromJson(jsonString);
        if (!context.mounted) return;
        await context.read<AssetProvider>().loadAssets();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Program imported successfully!',
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
      debugPrint("Import Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<SessionProvider>();
    final myPrograms = sessionProvider.allPrograms;
    final mySessions = sessionProvider.allSessions;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateOptions(context),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.add_rounded, size: 28),
        label: const Text(
          "CREATE",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 32,
          ).copyWith(bottom: 120),
          physics: const BouncingScrollPhysics(),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "MY PROGRAMS",
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                IconButton(
                  onPressed: () => _handleImportProgram(context),
                  icon: Icon(
                    Icons.file_download_outlined,
                    color: colorScheme.primary,
                  ),
                  tooltip: "Import Program",
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (myPrograms.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 32.0),
                child: Text(
                  "No programs yet. Create one to start structuring your training!",
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ...myPrograms.map(
              (prog) => Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: ProgramCard(key: ValueKey(prog.id), program: prog),
              ),
            ),

            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "WORKOUTS",
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                IconButton(
                  onPressed: () => _handleImportSession(context),
                  icon: Icon(
                    Icons.file_download_outlined,
                    color: colorScheme.primary,
                  ),
                  tooltip: "Import Workout",
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (mySessions.isEmpty)
              Text(
                "No standalone sessions. Create one or import a file.",
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ...mySessions.map(
              (session) => Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: SessionCard(
                  key: ValueKey(session.id),
                  session: session,
                  onTap: () => context.push('/sessions/details/${session.id}'),
                  onDelete: () => sessionProvider.deleteSession(session.id),
                  onUpdate: (updatedSession) =>
                      sessionProvider.updateSession(updatedSession),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProgramCard extends StatefulWidget {
  final Program program;
  const ProgramCard({super.key, required this.program});
  @override
  State<ProgramCard> createState() => _ProgramCardState();
}

class _ProgramCardState extends State<ProgramCard> {
  bool _isExpanded = false;
  late TextEditingController _titleCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.program.name);
  }

  @override
  void didUpdateWidget(ProgramCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.program != widget.program) {
      _titleCtrl.text = widget.program.name;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _saveInlineEdits() {
    final updatedProgram = widget.program;
    updatedProgram.name = _titleCtrl.text.trim().isEmpty
        ? "Unnamed Program"
        : _titleCtrl.text.trim();
    context.read<SessionProvider>().updateProgram(updatedProgram);
  }

  void _handleTap() {
    if (_isExpanded) {
      setState(() => _isExpanded = false);
      _saveInlineEdits();
    } else {
      context.push('/programs/details/${widget.program.id}');
    }
  }

  void _handleLongPress() {
    if (!_isExpanded) setState(() => _isExpanded = true);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    int totalSessions = widget.program.weeks.fold(
      0,
      (sum, w) => sum + w.sessions.length,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
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
        border: Border.all(
          color: _isExpanded || widget.program.isActive
              ? colorScheme.primary
              : (isLight
                    ? Colors.transparent
                    : colorScheme.surfaceContainerHighest),
          width: widget.program.isActive || _isExpanded ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleTap,
          onLongPress: _handleLongPress,
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Checkbox(
                      value: widget.program.isActive,
                      onChanged: (val) => context
                          .read<SessionProvider>()
                          .toggleProgramActive(widget.program.id, val ?? false),
                      activeColor: colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.program.name.toUpperCase(),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "${widget.program.weeks.length} WEEKS • $totalSessions SESSIONS",
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  letterSpacing: 1,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: colorScheme.error,
                      ),
                      onPressed: () => context
                          .read<SessionProvider>()
                          .deleteProgram(widget.program.id),
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
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: TextField(
                          controller: _titleCtrl,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: "Program Title",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.3),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProgramDialog extends StatefulWidget {
  const ProgramDialog({super.key});
  @override
  State<ProgramDialog> createState() => _ProgramDialogState();
}

class _ProgramDialogState extends State<ProgramDialog> {
  late TextEditingController _titleController;

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
        "NEW PROGRAM",
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w900,
        ),
        textAlign: TextAlign.center,
      ),
      content: TextField(
        controller: _titleController,
        style: const TextStyle(fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          labelText: "Program Name",
          hintText: "e.g. Hypertrophy PPL",
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        ),
      ),
      actionsPadding: const EdgeInsets.all(24),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  "CANCEL",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  if (_titleController.text.trim().isNotEmpty) {
                    context.read<SessionProvider>().addProgram(
                      Program(name: _titleController.text.trim(), weeks: []),
                    );
                    Navigator.pop(context);
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
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

class SessionCard extends StatefulWidget {
  final Session session;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<Session> onUpdate;
  const SessionCard({
    super.key,
    required this.session,
    required this.onTap,
    required this.onDelete,
    required this.onUpdate,
  });
  @override
  State<SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<SessionCard> {
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
  void didUpdateWidget(SessionCard oldWidget) {
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
    widget.onUpdate(updatedSession);
  }

  void _handleTap() {
    if (_isExpanded) {
      setState(() => _isExpanded = false);
      _saveInlineEdits();
    } else {
      widget.onTap();
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
              content: Text('Saved to $targetDir/$fileName'),
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
    final realExercisesCount = widget.session.exercises
        .where((e) => e is! RestBlock)
        .length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
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
        border: Border.all(
          color: _isExpanded
              ? colorScheme.primary
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
          onLongPress: _handleLongPress,
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.session.title.toUpperCase(),
                            style: Theme.of(context).textTheme.titleLarge
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
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  widget.session.day.dayOut.toUpperCase(),
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                "$realExercisesCount EXERCISE(S)",
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: colorScheme.error,
                      ),
                      onPressed: widget.onDelete,
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
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
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
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<Day>(
                              initialValue: _selectedDay,
                              decoration: InputDecoration(
                                labelText: "Day",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: colorScheme.surfaceContainerHighest
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
                                onPressed: () => _handleExportFile(context),
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
                                    borderRadius: BorderRadius.circular(16),
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
    );
  }
}

class SessionDialog extends StatefulWidget {
  const SessionDialog({super.key});
  @override
  State<SessionDialog> createState() => _SessionDialogState();
}

class _SessionDialogState extends State<SessionDialog> {
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
                    context.read<SessionProvider>().addSession(
                      Session(
                        title: _titleController.text.trim(),
                        day: _selectedDay,
                      ),
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
