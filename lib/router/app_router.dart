import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/inventory/view/inventory_export_screen.dart';
import '../features/inventory/view/inventory_screen.dart';
import '../features/inventory/view/inventory_search_screen.dart';
import '../features/inventory/view/inventory_print_labels_screen.dart';
import '../shared/widgets/app_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/inventory/search',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/inventory',
          name: 'inventory',
          builder: (context, state) => const InventoryScreen(),
          routes: [
            GoRoute(
              path: 'search',
              name: 'inventory-search',
              builder: (context, state) => const InventorySearchScreen(),
            ),
            GoRoute(
              path: 'print-labels',
              name: 'inventory-print-labels',
              builder: (context, state) => const InventoryPrintLabelsScreen(),
            ),
            GoRoute(
              path: 'export',
              name: 'inventory-export',
              builder: (context, state) => const InventoryExportScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
