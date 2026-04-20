// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import '../main.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "APPEARANCE",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),

              StreamBuilder<bool>(
                stream: progressRepository.isDarkModeFlow,
                initialData: progressRepository.isDarkMode,
                builder: (context, snapshot) {
                  final isDarkMode =
                      snapshot.data ?? progressRepository.isDarkMode;

                  return Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.surfaceContainerHighest,
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "DARK MODE",
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(color: colorScheme.onSurface),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isDarkMode ? "CURRENT: DARK" : "CURRENT: LIGHT",
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                          Switch(
                            value: isDarkMode,
                            onChanged: (newValue) =>
                                progressRepository.setDarkMode(newValue),
                            activeThumbColor: colorScheme.primary,
                            activeTrackColor: colorScheme.primary.withValues(
                              alpha: 0.2,
                            ),
                            inactiveTrackColor:
                                colorScheme.surfaceContainerHighest,
                            inactiveThumbColor: colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
