import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:omnicontext/features/dashboard/dashboard_screen.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Acrylic
  await Window.initialize();
  await Window.setEffect(
    effect: WindowEffect.acrylic,
    color: const Color(0xCC222222), // Dark acrylic tint
    dark: true,
  );

  // Initialize Window Manager
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(350, 800),
    minimumSize: Size(100, 100),
    center: false,
    backgroundColor: Colors.transparent, // Crucial for acrylic
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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.transparent, // Allow Acrylic through
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF), // Electric Cyan
          secondary: Color(0xFF2979FF), // Electric Blue
          surface: Color(0xFF1E1E1E), // Deep Dark Gray
          onSurface: Color(0xFFE0E0E0),
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.orbitronTextTheme(ThemeData.dark().textTheme),
      ),
      home: const DashboardScreen(),
    );
  }
}
