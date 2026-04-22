// lib/screens/leveling_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/leveling_provider.dart';

class LevelingScreen extends StatelessWidget {
  const LevelingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final leveling = context.watch<LevelingProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Header : Coins
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.amber, width: 2),
                    boxShadow: isLight
                        ? [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.monetization_on_rounded,
                        color: Colors.amber,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "${leveling.coins}",
                        style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 64),

            // Badge de Niveau et Cercle d'XP
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.surface,
                    boxShadow: isLight
                        ? [
                            BoxShadow(
                              color: colorScheme.primary.withValues(
                                alpha: 0.15,
                              ),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                ),
                SizedBox(
                  width: 280,
                  height: 280,
                  child: CircularProgressIndicator(
                    value: leveling.progressRatio,
                    strokeWidth: 16,
                    strokeCap: StrokeCap.round,
                    color: colorScheme.primary,
                    backgroundColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "LEVEL",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colorScheme.secondary,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      "${leveling.level}",
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 100,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.primary,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "${leveling.currentXp.toInt()} / ${leveling.xpForNextLevel.toInt()} XP",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: colorScheme.primary,
                  fontSize: 16,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 80),

            // Section : Paliers
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "MILESTONES",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildMilestoneCard(context, 10, "BEGINNER", 500, leveling),
          ],
        ),
      ),
    );
  }

  Widget _buildMilestoneCard(
    BuildContext context,
    int targetLevel,
    String sessionName,
    int coinReward,
    LevelingProvider leveling,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final isUnlocked = leveling.level >= targetLevel;
    final isClaimed = leveling.claimedMilestones.contains(targetLevel);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isUnlocked
            ? colorScheme.primary.withValues(alpha: 0.1)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isLight && isUnlocked
            ? [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ]
            : (isLight
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null),
        border: Border.all(
          color: isUnlocked
              ? colorScheme.primary
              : (isLight
                    ? Colors.transparent
                    : colorScheme.surfaceContainerHighest),
          width: isUnlocked ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isUnlocked
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
              color: isUnlocked
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "LEVEL $targetLevel",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: isUnlocked
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  sessionName,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.monetization_on_rounded,
                      size: 18,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "+$coinReward Coins",
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isClaimed)
            Icon(
              Icons.check_circle_rounded,
              color: colorScheme.primary,
              size: 40,
            ),
        ],
      ),
    );
  }
}
