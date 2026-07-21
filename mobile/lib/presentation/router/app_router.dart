import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/auth_controller.dart';
import '../screens/attempt_screen.dart';
import '../screens/catalog_screen.dart';
import '../screens/course_detail_screen.dart';
import '../screens/energy_screen.dart';
import '../screens/sign_in_screen.dart';
import '../screens/splash_screen.dart';
import '../widgets/localization.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _catalogNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'catalog');
final _energyNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'energy');

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (previous, next) {
    refresh.value += 1;
  });
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final path = state.uri.path;
      if (auth.isLoading) {
        return path == '/splash' ? null : '/splash';
      }
      final authenticated = auth.hasValue && auth.requireValue != null;
      if (!authenticated) {
        return path == '/sign-in' ? null : '/sign-in';
      }
      if (path == '/splash' || path == '/sign-in') {
        return '/catalog';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/sign-in',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SignInScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _catalogNavigatorKey,
            routes: [
              GoRoute(
                path: '/catalog',
                builder: (context, state) => const CatalogScreen(),
                routes: [
                  GoRoute(
                    path: 'course/:courseId',
                    builder: (context, state) => CourseDetailScreen(
                      courseId: state.pathParameters['courseId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _energyNavigatorKey,
            routes: [
              GoRoute(
                path: '/energy',
                builder: (context, state) => const EnergyScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/attempt/:testId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            AttemptScreen(testId: state.pathParameters['testId']!),
      ),
    ],
  );
});

final class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book),
            label: context.l10n.catalog,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bolt_outlined),
            selectedIcon: const Icon(Icons.bolt),
            label: context.l10n.energy,
          ),
        ],
      ),
    );
  }
}
