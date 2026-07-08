import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiao_p/core/theme.dart';
import 'package:xiao_p/routes/app_router.dart';
import 'package:xiao_p/services/tools/tool_registry.dart';

final themeModeProvider = StateProvider<AppThemeMode>((ref) => AppThemeMode.dark);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  final savedTheme = await ThemeService.getThemeMode();
  await ThemeService.loadAccentColor();
  final prefs = await SharedPreferences.getInstance();
  final hasOnboarded = prefs.getBool('onboarded') ?? false;

  // 注册内置工具插件
  ToolRegistry().registerBuiltin();

  if (!hasOnboarded) {
    await prefs.setBool('onboarded', true);
  }

  runApp(ProviderScope(
    overrides: [themeModeProvider.overrideWith((ref) => savedTheme)],
    child: XiaoPApp(startOnHome: hasOnboarded),
  ));
}

class XiaoPApp extends ConsumerStatefulWidget {
  final bool startOnHome;
  const XiaoPApp({super.key, required this.startOnHome});

  @override
  ConsumerState<XiaoPApp> createState() => _XiaoPAppState();
}

class _XiaoPAppState extends ConsumerState<XiaoPApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    // 系统深浅色变化时，跟随系统模式需触发重建以应用新亮度
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: '小P',
      debugShowCheckedModeBanner: false,
      theme: ThemeService.getTheme(themeMode),
      routerConfig: appRouter,
    );
  }
}
