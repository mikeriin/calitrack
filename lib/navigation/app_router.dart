// lib/navigation/app_router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/sessions_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/session_details_screen.dart';
import '../screens/session_of_the_day_screen.dart';
import '../screens/tracker_screen.dart';
import '../screens/assets_screen.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

// ==========================================
// LE LAYOUT PRINCIPAL (App Bar + Drawer)
// ==========================================
class MainLayout extends StatelessWidget {
  final Widget child;
  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final String currentRoute = GoRouterState.of(context).uri.toString();

    String getTitle() {
      if (currentRoute == '/session_of_the_day') return "TODAY'S WORKOUT";
      if (currentRoute == '/sessions') return "WORKOUTS";
      if (currentRoute == '/tracker') return "TRACKER";
      if (currentRoute == '/assets') return "ASSETS";
      if (currentRoute == '/settings') return "SETTINGS";
      // Correction de l'URL ici
      if (currentRoute.startsWith('/sessions/details')) {
        return "WORKOUT DETAILS";
      }
      return "CALI TRACK";
    }

    // Correction de l'URL ici pour bien détecter l'écran des détails
    final isDetailsScreen = currentRoute.startsWith('/sessions/details');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          getTitle(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: isDetailsScreen
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 28),
                // Retour explicite à l'écran des sessions
                onPressed: () => context.go('/sessions'),
              )
            : Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu_rounded, size: 28),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
      ),
      drawer: isDetailsScreen ? null : AppDrawer(currentRoute: currentRoute),
      body: child,
    );
  }
}

// ==========================================
// LE MENU LATÉRAL (Drawer)
// ==========================================
class AppDrawer extends StatelessWidget {
  final String currentRoute;
  const AppDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget buildMenuItem(String title, String path, IconData icon) {
      final isSelected = currentRoute == path;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          selected: isSelected,
          selectedTileColor: colorScheme.primary.withValues(alpha: 0.1),
          leading: Icon(
            icon,
            color: isSelected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
          title: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
              letterSpacing: 1.0,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          onTap: () {
            context.go(path);
            Navigator.pop(context);
          },
        ),
      );
    }

    return Drawer(
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(32)),
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 32.0, top: 80.0, bottom: 32.0),
            child: Text(
              "CALI TRACK",
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 2.5,
                color: colorScheme.primary,
              ),
            ),
          ),
          buildMenuItem(
            "TODAY'S WORKOUT",
            '/session_of_the_day',
            Icons.play_circle_fill_rounded,
          ),
          buildMenuItem("WORKOUTS", '/sessions', Icons.list_alt_rounded),
          buildMenuItem("TRACKER", '/tracker', Icons.insights_rounded),
          buildMenuItem("ASSETS", '/assets', Icons.category_rounded),
          buildMenuItem("SETTINGS", '/settings', Icons.settings_rounded),
        ],
      ),
    );
  }
}

// ==========================================
// CONFIGURATION DES ROUTES
// ==========================================
final GoRouter appRouter = GoRouter(
  initialLocation: '/session_of_the_day',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return MainLayout(child: child);
      },
      routes: [
        GoRoute(
          path: '/session_of_the_day',
          builder: (context, state) => const SessionOfTheDayScreen(),
        ),
        GoRoute(
          path: '/sessions',
          builder: (context, state) => const SessionsScreen(),
          routes: [
            GoRoute(
              path: 'details/:sessionId',
              builder: (context, state) {
                final id = state.pathParameters['sessionId']!;
                return SessionDetailsScreen(sessionId: id);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/tracker',
          builder: (context, state) => const TrackerScreen(),
        ),
        GoRoute(
          path: '/assets',
          builder: (context, state) => const AssetsScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);
