// lib/screens/sessions_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/workout_models.dart';
import '../viewmodels/session_provider.dart';

class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  void _showSessionDialog(BuildContext context, {Session? existingSession}) {
    showDialog(
      context: context,
      builder: (context) => SessionDialog(existingSession: existingSession),
    );
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
          "NEW",
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
                child: Text(
                  "YOUR PROGRAMS",
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
              );
            }

            final session = mySessions[index - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: SessionCard(
                session: session,
                onTap: () => context.go('/sessions/details/${session.id}'),
                onLongPress: () =>
                    _showSessionDialog(context, existingSession: session),
                onDelete: () => sessionProvider.deleteSession(session.id),
              ),
            );
          },
        ),
      ),
    );
  }
}

class SessionCard extends StatelessWidget {
  final Session session;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;

  const SessionCard({
    super.key,
    required this.session,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final realExercisesCount = session.exercices
        .where((e) => e is! RestBlock)
        .length;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.surfaceContainerHighest,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title.toUpperCase(),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colorScheme.onSurface,
                        ),
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
                              session.day.dayOut.toUpperCase(),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: colorScheme.onPrimary),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "$realExercisesCount EXERCISE(S)",
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
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
                  onPressed: onDelete,
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.error.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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

class SessionDialog extends StatefulWidget {
  final Session? existingSession;
  const SessionDialog({super.key, this.existingSession});
  @override
  State<SessionDialog> createState() => _SessionDialogState();
}

class _SessionDialogState extends State<SessionDialog> {
  late TextEditingController _titleController;
  late Day _selectedDay;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existingSession?.title ?? "",
    );
    _selectedDay = widget.existingSession?.day ?? Day.monday;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEditing = widget.existingSession != null;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.surfaceContainerHighest, width: 1),
      ),
      title: Text(
        isEditing ? "EDIT WORKOUT" : "NEW WORKOUT",
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
              labelText: "Title (e.g. Pull A)",
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
              labelText: "Weekday",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
            ),
            items: Day.values.map((day) {
              return DropdownMenuItem(
                value: day,
                child: Text(
                  day.dayOut.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            }).toList(),
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
                    final provider = context.read<SessionProvider>();
                    if (isEditing) {
                      final updatedSession = Session(
                        id: widget.existingSession!.id,
                        title: _titleController.text.trim(),
                        day: _selectedDay,
                        exercices: widget.existingSession!.exercices,
                      );
                      provider.updateSession(updatedSession);
                    } else {
                      provider.addSession(
                        Session(
                          title: _titleController.text.trim(),
                          day: _selectedDay,
                        ),
                      );
                    }
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
                child: Text(isEditing ? "SAVE" : "CREATE"),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
