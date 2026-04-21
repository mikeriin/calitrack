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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Header : Coins
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.monetization_on_rounded,
                        color: Colors.amber,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "${leveling.coins}",
                        style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),

            // Badge de Niveau et Cercle d'XP
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 240,
                  height: 240,
                  child: CircularProgressIndicator(
                    value: leveling.progressRatio,
                    strokeWidth: 12,
                    strokeCap: StrokeCap.round,
                    color: colorScheme.primary,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "LEVEL",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.secondary,
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      "${leveling.level}",
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 80,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.primary,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              "${leveling.currentXp.toInt()} / ${leveling.xpForNextLevel.toInt()} XP",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 60),

            // Section : Paliers
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "MILESTONES",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildMilestoneCard(context, 5, "SPARTAN AWAKENING", 200, leveling),
            _buildMilestoneCard(context, 10, "TITAN STRENGTH", 500, leveling),
            _buildMilestoneCard(
              context,
              20,
              "OLYMPIAN CONDITIONING",
              1000,
              leveling,
            ),
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
    final isUnlocked = leveling.level >= targetLevel;
    final isClaimed = leveling.claimedMilestones.contains(targetLevel);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isUnlocked
            ? colorScheme.primary.withValues(alpha: 0.1)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          width: isUnlocked ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUnlocked
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
              color: isUnlocked
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "LEVEL $targetLevel",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: isUnlocked
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sessionName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    decoration: (isUnlocked && !isClaimed) ? null : null,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.monetization_on_rounded,
                      size: 14,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "+$coinReward Coins",
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
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
              size: 32,
            ),
        ],
      ),
    );
  }
}
