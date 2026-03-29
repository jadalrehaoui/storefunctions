import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/cubit/auth_cubit.dart';
import '../features/auth/view/login_screen.dart';
import '../features/inventory/view/inventory_export_screen.dart';
import '../features/inventory/view/inventory_screen.dart';
import '../features/inventory/view/inventory_search_screen.dart';
import '../features/inventory/view/inventory_print_labels_screen.dart';
import '../features/reports/view/cierre_mikail_screen.dart';
import '../features/reports/view/restock_list_screen.dart';
import '../features/settings/view/settings_screen.dart';
import '../features/reports/view/cierre_sitsa_screen.dart';
import '../features/reports/view/closure_detail_screen.dart';
import '../features/reports/view/closures_screen.dart';
import '../features/reports/view/sales_reports_screen.dart';
import '../features/users/view/users_screen.dart';
import '../shared/widgets/app_shell.dart';

/// Bridges a BLoC stream to a [Listenable] so GoRouter can react to auth changes.
class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

GoRouter createRouter(AuthCubit authCubit) {
  return GoRouter(
    initialLocation: '/inventory/search',
    refreshListenable: _GoRouterRefreshStream(authCubit.stream),
    redirect: (context, state) {
      final isAuthenticated = authCubit.state is AuthAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isAuthenticated && !isLoggingIn) return '/login';
      if (isAuthenticated && isLoggingIn) return '/inventory/search';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: LoginScreen(),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/inventory',
            name: 'inventory',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: InventoryScreen(),
            ),
            routes: [
              GoRoute(
                path: 'search',
                name: 'inventory-search',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: InventorySearchScreen(),
                ),
              ),
              GoRoute(
                path: 'print-labels',
                name: 'inventory-print-labels',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: InventoryPrintLabelsScreen(),
                ),
              ),
              GoRoute(
                path: 'export',
                name: 'inventory-export',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: InventoryExportScreen(),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/reports/sales',
            name: 'reports-sales',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SalesReportsScreen(),
            ),
          ),
          GoRoute(
            path: '/reports/cierre-sitsa',
            name: 'reports-cierre-sitsa',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CierreSitsaScreen(),
            ),
          ),
          GoRoute(
            path: '/reports/cierre-mikail',
            name: 'reports-cierre-mikail',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CierreMikailScreen(),
            ),
          ),
          GoRoute(
            path: '/reports/restock-list',
            name: 'reports-restock-list',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: RestockListScreen(),
            ),
          ),
          GoRoute(
            path: '/reports/closures',
            name: 'reports-closures',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ClosuresScreen(),
            ),
          ),
          GoRoute(
            path: '/reports/closures/:id',
            name: 'reports-closure-detail',
            pageBuilder: (context, state) => NoTransitionPage(
              child: ClosureDetailScreen(
                closureId: state.pathParameters['id']!,
              ),
            ),
          ),
          GoRoute(
            path: '/users',
            name: 'users',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: UsersScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
        ],
      ),
    ],
  );
}
