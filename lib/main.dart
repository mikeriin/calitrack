import 'package:flutter/material.dart';
import 'services/progress_repository.dart';
import 'services/database_service.dart';
import 'theme/app_theme.dart';
import 'navigation/app_router.dart';
import 'package:provider/provider.dart';
import 'viewmodels/session_provider.dart';
import 'viewmodels/tracker_provider.dart';
import 'viewmodels/asset_provider.dart'; 

final progressRepository = ProgressRepository();
final databaseService = DatabaseService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await databaseService.database;
  await progressRepository.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SessionProvider(progressRepository),
        ),
        ChangeNotifierProvider(create: (_) => TrackerProvider()),
        // Injection de l'AssetProvider ici
        ChangeNotifierProvider(create: (_) => AssetProvider()),
      ],
      child: const CaliTrackApp(),
    ),
  );
}

class CaliTrackApp extends StatelessWidget {
  const CaliTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: progressRepository.isDarkModeFlow,
      initialData: true,
      builder: (context, snapshot) {
        final isDarkMode = snapshot.data ?? true;

        return MaterialApp.router(
          title: 'CaliTrack',
          debugShowCheckedModeBanner: false,

          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,

          routerConfig: appRouter,
        );
      },
    );
  }
}
