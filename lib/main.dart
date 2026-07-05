import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  runApp(ProviderScope(
    overrides: [themeModeProvider.overrideWith((ref) => savedTheme)],
    child: const XiaoPApp(),
  ));
}

class XiaoPApp extends ConsumerWidget {
  const XiaoPApp({super.key});

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
