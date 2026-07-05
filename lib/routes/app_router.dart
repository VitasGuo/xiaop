import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:xiao_p/core/theme.dart';
import 'package:xiao_p/presentation/home/home_screen.dart';
import 'package:xiao_p/presentation/chat/chat_screen.dart';
import 'package:xiao_p/presentation/chat/conversation_list_screen.dart';
import 'package:xiao_p/presentation/personality/personality_screen.dart';
import 'package:xiao_p/presentation/personality/personality_edit_screen.dart';
import 'package:xiao_p/presentation/memory/memory_screen.dart';
import 'package:xiao_p/presentation/settings/settings_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainScaffold(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/conversations',
            builder: (context, state) => const ConversationListScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ]),
      ],
    ),
    GoRoute(
      path: '/chat/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => ChatScreen(
        conversationId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/personality',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const PersonalityScreen(),
    ),
    GoRoute(
      path: '/personality/edit',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const PersonalityEditScreen(),
    ),
    GoRoute(
      path: '/memory',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const MemoryScreen(),
    ),
  ],
);

class MainScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(index,
            initialLocation: index == navigationShell.currentIndex),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.accentColor,
        unselectedItemColor: AppTheme.textSecondary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: '主页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: '对话',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
