// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
// import 'package:flutter_blue_plus/flutter_blue_plus.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:provider/provider.dart';
import '../main.dart';
// import '../viewmodels/session_provider.dart';
// import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // bool _isScanningGarmin = false;

  Future<void> _selectFolder() async {
    final String? directoryPath = await getDirectoryPath();
    if (directoryPath != null) {
      await progressRepository.setDataFolder(directoryPath);
    }
  }

  // Logic to scan and find a Garmin watch
  /*Future<void> _toggleGarminConnection(bool val) async {
    if (!val) {
      await progressRepository.setGarminLinked(false);
      return;
    }

    // Request Bluetooth permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location, // Often required for BLE on Android
    ].request();

    if (!mounted) return; // <-- Good practice after an await

    if (statuses[Permission.bluetoothScan]!.isDenied ||
        statuses[Permission.bluetoothConnect]!.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bluetooth permissions required.")),
      );
      return;
    }

    setState(() => _isScanningGarmin = true);

    bool found = false;

    // Scan for 5 seconds
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    var subscription = FlutterBluePlus.onScanResults.listen((results) async {
      for (ScanResult r in results) {
        if (r.device.platformName.toLowerCase().contains("garmin")) {
          found = true;
          FlutterBluePlus.stopScan();
          await progressRepository.setGarminLinked(
            true,
            deviceName: r.device.platformName,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Connected to: ${r.device.platformName}")),
            );
          }
          break;
        }
      }
    });

    await Future.delayed(const Duration(seconds: 5));
    FlutterBluePlus.stopScan();
    subscription.cancel();

    if (!mounted) return; // <-- Good practice after an await

    if (!found) {
      await progressRepository.setGarminLinked(false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No Garmin device detected nearby."),
        ),
      );
    }

    setState(() => _isScanningGarmin = false);
  }*/

  // Logic for notifications (FIXED)
  // Future<void> _toggleNotifications(bool val) async {
  //   await progressRepository.setDailyNotifications(val);

  //   if (val) {
  //     // Request notification permission (iOS/Android 13+)
  //     await Permission.notification.request();

  //     if (mounted && Theme.of(context).platform == TargetPlatform.android) {
  //       await Permission.scheduleExactAlarm.request();
  //     }

  //     // Ensure the widget is still mounted after the await
  //     if (!mounted) return;

  //     // Fetch all sessions to schedule them
  //     final sessions = Provider.of<SessionProvider>(
  //       context,
  //       listen: false,
  //     ).allSessions;

  //     await notificationService.scheduleWorkoutNotifications(sessions);

  //     // Verify once more before updating the UI
  //     if (!mounted) return;

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text("Notifications enabled for 06:00 AM on workout days!"),
  //       ),
  //     );
  //   } else {
  //     await notificationService.cancelAllNotifications();
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("SETTINGS", style: TextStyle(color: colorScheme.onSurface)),
      ),
      body: SafeArea(
        child: StreamBuilder<void>(
          stream: progressRepository.settingsFlow,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 12.0,
              ),
              children: [
                _buildSectionTitle(context, "APPEARANCE"),
                _buildSettingsCard(
                  context: context,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "DARK MODE",
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            progressRepository.isDarkMode
                                ? "CURRENT: DARK"
                                : "CURRENT: LIGHT",
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                      Switch(
                        value: progressRepository.isDarkMode,
                        onChanged: (val) => progressRepository.setDarkMode(val),
                        activeThumbColor: colorScheme.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                _buildSectionTitle(context, "STORAGE & DATA"),
                _buildSettingsCard(
                  context: context,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "REFERENCE DATA FOLDER",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        progressRepository.dataFolder ?? "Default (Downloads)",
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed:
                            _selectFolder, // Fixed: no longer need to pass context
                        icon: const Icon(Icons.folder_open_rounded, size: 20),
                        label: const Text("SELECT FOLDER"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.primary,
                          side: BorderSide(color: colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // SECTION: INTEGRATIONS (Modified for Garmin)
                /*_buildSectionTitle(context, "INTEGRATIONS"),
                _buildSettingsCard(
                  context: context,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "GARMIN CONNECT",
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              progressRepository.isGarminLinked
                                  ? (progressRepository.garminDeviceName ??
                                        "LINKED")
                                  : "UNLINKED",
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: progressRepository.isGarminLinked
                                        ? const Color(0xFF10B981)
                                        : colorScheme.error,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (_isScanningGarmin)
                        const Padding(
                          padding: EdgeInsets.only(right: 12.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else
                        Switch(
                          value: progressRepository.isGarminLinked,
                          onChanged: _isScanningGarmin
                              ? null
                              : _toggleGarminConnection,
                          activeThumbColor: const Color(0xFF10B981),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),*/
                _buildSectionTitle(context, "WORKOUT PREFERENCES"),
                _buildSettingsCard(
                  context: context,
                  child: Column(
                    children: [
                      // Row(
                      //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      //   children: [
                      //     Expanded(
                      //       child: Text(
                      //         "DAILY NOTIFICATIONS (06:00 AM)",
                      //         style: Theme.of(context).textTheme.titleMedium,
                      //       ),
                      //     ),
                      //     Switch(
                      //       value: progressRepository.dailyNotifications,
                      //       onChanged: _toggleNotifications, // Fixed here
                      //       activeThumbColor: colorScheme.primary,
                      //     ),
                      //   ],
                      // ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "KEEP SCREEN AWAKE",
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "App-wide display persistence",
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: progressRepository.keepAwake,
                            onChanged: (val) =>
                                progressRepository.setKeepAwake(val),
                            activeThumbColor: colorScheme.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required BuildContext context,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.surfaceContainerHighest,
          width: 1,
        ),
      ),
      child: child,
    );
  }
}
