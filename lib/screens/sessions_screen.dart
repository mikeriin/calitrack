// lib/screens/sessions_screen.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import '../main.dart'; // for progressRepository
import '../models/workout_models.dart';
import '../viewmodels/session_provider.dart';

class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  Future<void> _handleImportFile(BuildContext context) async {
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
        await context.read<SessionProvider>().importSessionFromJson(jsonString);

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Workout imported successfully!"),
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

  void _showSessionDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const SessionDialog());
  }

  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<SessionProvider>();
    final mySessions = sessionProvider.allSessions;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSessionDialog(context),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_rounded, size: 24),
        label: const Text(
          "NEW WORKOUT",
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
        ),
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ).copyWith(bottom: 100),
          itemCount: mySessions.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "MY SESSIONS",
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: colorScheme.onSurface),
                    ),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.file_download_outlined),
                      tooltip: "Import workout (.json)",
                      onPressed: () => _handleImportFile(context),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.primary.withValues(
                          alpha: 0.1,
                        ),
                        foregroundColor: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              );
            }
            final session = mySessions[index - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: SessionCard(
                key: ValueKey(session.id),
                session: session,
                onTap: () => context.go('/sessions/details/${session.id}'),
                onDelete: () => sessionProvider.deleteSession(session.id),
                onUpdate: (updatedSession) =>
                    sessionProvider.updateSession(updatedSession),
              ),
            );
          },
        ),
      ),
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
      // Closes the card and saves if clicked while open
      setState(() => _isExpanded = false);
      _saveInlineEdits();
    } else {
      // Opens session details on short press
      widget.onTap();
    }
  }

  void _handleLongPress() {
    if (!_isExpanded) {
      // Opens edit mode on long press
      setState(() => _isExpanded = true);
    }
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
    final realExercisesCount = widget.session.exercises
        .where((e) => e is! RestBlock)
        .length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isExpanded
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleTap,
          onLongPress: _handleLongPress,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ALWAYS VISIBLE HEADER
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
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
                                ?.copyWith(color: colorScheme.onSurface),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  widget.session.day.dayOut.toUpperCase(),
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(color: colorScheme.onPrimary),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "$realExercisesCount EXERCISE(S)",
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
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
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // EXPANDABLE EDIT CONTENT
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: !_isExpanded
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          children: [
                            TextField(
                              controller: _titleCtrl,
                              decoration: InputDecoration(
                                labelText: "Title",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<Day>(
                              initialValue: _selectedDay,
                              decoration: InputDecoration(
                                labelText: "Day",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                isDense: true,
                              ),
                              items: Day.values
                                  .map(
                                    (day) => DropdownMenuItem(
                                      value: day,
                                      child: Text(day.dayOut.toUpperCase()),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedDay = val);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _handleExportFile(context),
                                icon: const Icon(
                                  Icons.ios_share_rounded,
                                  size: 20,
                                ),
                                label: const Text("EXPORT (.JSON)"),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
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
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.surfaceContainerHighest, width: 1),
      ),
      title: Text(
        "NEW WORKOUT",
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(color: colorScheme.primary),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: "Title (e.g. Pull Day A)",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<Day>(
            initialValue: _selectedDay,
            decoration: InputDecoration(
              labelText: "Assigned Day",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
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
      actionsPadding: const EdgeInsets.all(20),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  "CANCEL",
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text("CREATE"),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
