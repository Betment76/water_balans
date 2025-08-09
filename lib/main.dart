import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:water_balance/l10n/app_localizations.dart';
import 'package:water_balance/l10n/l10n.dart';
import 'constants/app_colors.dart';
import 'constants/app_strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/onboarding_screen.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  final String timeZoneName = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(timeZoneName));
  await NotificationService.initialize();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const ProviderScope(child: WaterBalanceApp()));
}

class WaterBalanceApp extends StatelessWidget {
  const WaterBalanceApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      theme: ThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.primary,
        ),
      ),
      home: const AppInitializer(),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L10n.supportedLocales,
      locale: const Locale('ru'),
      localeResolutionCallback: L10n.localeResolutionCallback,
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({Key? key}) : super(key: key);

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isLoading = true;
  bool _isFirstLaunch = true;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    try {
      final isFirstLaunch = await StorageService.isFirstLaunch();
      setState(() {
        _isFirstLaunch = isFirstLaunch;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isFirstLaunch = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return _isFirstLaunch 
        ? const OnboardingScreen()
        : const MainNavigationScreen();
  }
}
