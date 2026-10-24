import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';
import 'features/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  final showSplash = await SplashScreen.shouldShowSplash();

  runApp(HardcorezForgeApp(showSplash: showSplash));
}

class HardcorezForgeApp extends StatelessWidget {
  final bool showSplash;
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

  const HardcorezForgeApp({super.key, this.showSplash = true});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'HardcorezForge',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          home: showSplash ? const SplashScreen() : const HomeScreen(),
        );
      },
    );
  }
}

