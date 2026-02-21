import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:omnicontext/features/dashboard/dashboard_screen.dart';
import 'package:omnicontext/features/onboarding/onboarding_screen.dart';
import 'package:tray_manager/tray_manager.dart';
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
    // Prevent default close so we can hide to tray instead
    await windowManager.setPreventClose(true);
  });

  // Always show onboarding to allow project selection on startup
  runApp(const ProviderScope(child: OmniContextApp(showOnboarding: true)));
}

class OmniContextApp extends StatefulWidget {
  final bool showOnboarding;
  const OmniContextApp({super.key, required this.showOnboarding});

  @override
  State<OmniContextApp> createState() => _OmniContextAppState();
}

class _OmniContextAppState extends State<OmniContextApp>
    with WindowListener, TrayListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);
    _initSystemTray();
  }

  Future<void> _initSystemTray() async {
    // Only set icon on desktop platforms, tray_manager handles windows nicely with .ico
    await trayManager.setIcon('assets/app_icon.ico');
    await trayManager.setToolTip('OmniContext');
    Menu menu = Menu(
      items: [
        MenuItem(key: 'show_window', label: 'Show HUD'),
        MenuItem.separator(),
        MenuItem(key: 'exit_app', label: 'Quit OmniContext'),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      windowManager.hide();
    }
  }

  @override
  void onTrayIconMouseDown() {
    // Left click shows the window
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    // Right click shows the context menu
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_window') {
      windowManager.show();
      windowManager.focus();
    } else if (menuItem.key == 'exit_app') {
      windowManager.destroy(); // bypass prevent close to actually exit
    }
  }

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
      routes: {
        '/dashboard': (_) => DashboardScreen(),
        '/onboarding': (_) => OnboardingScreen(),
      },
      home: widget.showOnboarding ? OnboardingScreen() : DashboardScreen(),
    );
  }
}
