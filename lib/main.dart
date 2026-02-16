import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omnicontext/features/dashboard/dashboard_screen.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Window Manager
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(350, 800),
    minimumSize: Size(100, 100),
    center: false,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    alwaysOnTop: true,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    // Position it roughly on the right side of the screen (optional, user can move it)
    await windowManager.setPosition(const Offset(100, 100));
  });

  runApp(const ProviderScope(child: OmniContextApp()));
}

class OmniContextApp extends StatelessWidget {
  const OmniContextApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OmniContext',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}
