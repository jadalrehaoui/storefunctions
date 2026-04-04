import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';

class NavSubConfig {
  final String id;
  final IconData icon;
  final String Function(AppLocalizations) label;
  final String route;
  final String? privilege;

  const NavSubConfig({
    required this.id,
    required this.icon,
    required this.label,
    required this.route,
    this.privilege,
  });
}

class NavItemConfig {
  final String id;
  final IconData icon;
  final String Function(AppLocalizations) label;
  final String? route;
  final List<NavSubConfig> subItems;
  final String? privilege;

  const NavItemConfig({
    required this.id,
    required this.icon,
    required this.label,
    this.route,
    this.subItems = const [],
    this.privilege,
  });
}

final navItems = <NavItemConfig>[
  NavItemConfig(
    id: 'dashboard',
    icon: Icons.dashboard_outlined,
    label: (l10n) => l10n.navDashboard,
    route: '/dashboard',
    privilege: 'see_dashboard',
  ),
  NavItemConfig(
    id: 'inventory',
    icon: Icons.inventory_2_outlined,
    label: (l10n) => l10n.navInventory,
    subItems: [
      NavSubConfig(
        id: 'inventory-search',
        icon: Icons.search,
        label: (l10n) => l10n.navSearch,
        route: '/inventory/search',
        privilege: 'inspect_inventory',
      ),
      NavSubConfig(
        id: 'inventory-print-labels',
        icon: Icons.label_outline,
        label: (l10n) => l10n.navPrintLabels,
        route: '/inventory/print-labels',
        privilege: 'print_labels',
      ),
      NavSubConfig(
        id: 'inventory-export',
        icon: Icons.download_outlined,
        label: (l10n) => l10n.navExportInventory,
        route: '/inventory/export',
        privilege: 'generate_inventory',
      ),
    ],
  ),
  NavItemConfig(
    id: 'reports',
    icon: Icons.bar_chart_outlined,
    label: (l10n) => l10n.navReports,
    subItems: [
      NavSubConfig(
        id: 'reports-sales',
        icon: Icons.receipt_long_outlined,
        label: (l10n) => l10n.navSalesReports,
        route: '/reports/sales',
        privilege: 'generate_sales_report',
      ),
      NavSubConfig(
        id: 'reports-cierre-sitsa',
        icon: Icons.store_outlined,
        label: (l10n) => l10n.navCierreSitsa,
        route: '/reports/cierre-sitsa',
        privilege: 'generate_closure',
      ),
      NavSubConfig(
        id: 'reports-cierre-mikail',
        icon: Icons.storefront_outlined,
        label: (l10n) => l10n.navCierreMikail,
        route: '/reports/cierre-mikail',
        privilege: 'generate_closure',
      ),
      NavSubConfig(
        id: 'reports-restock-list',
        icon: Icons.playlist_add_outlined,
        label: (l10n) => l10n.navRestockList,
        route: '/reports/restock-list',
        privilege: 'generate_restock_list',
      ),
      NavSubConfig(
        id: 'reports-closures',
        icon: Icons.history_outlined,
        label: (l10n) => l10n.navCierres,
        route: '/reports/closures',
        privilege: 'inspect_closures',
      ),
    ],
  ),
  NavItemConfig(
    id: 'users',
    icon: Icons.people_outline,
    label: (l10n) => l10n.navUsers,
    route: '/users',
    privilege: 'create_users',
  ),
];
