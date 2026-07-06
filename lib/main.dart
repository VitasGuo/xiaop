import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiao_p/core/theme.dart';
import 'package:xiao_p/routes/app_router.dart';

final themeModeProvider = StateProvider<AppThemeMode>((ref) => AppThemeMode.dark);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  final savedTheme = await ThemeService.getThemeMode();
  final prefs = await SharedPreferences.getInstance();
  final hasOnboarded = prefs.getBool('onboarded') ?? false;

  if (!hasOnboarded) {
    await prefs.setBool('onboarded', true);
  }

  runApp(ProviderScope(
    overrides: [themeModeProvider.overrideWith((ref) => savedTheme)],
    child: XiaoPApp(startOnHome: hasOnboarded),
  ));
}

class XiaoPApp extends ConsumerWidget {
  final bool startOnHome;
  const XiaoPApp({super.key, required this.startOnHome});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: '小P',
      debugShowCheckedModeBanner: false,
      theme: ThemeService.getTheme(themeMode),
      routerConfig: appRouter,
    );
  }
}
