import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';

class NavSubConfig {
  final String id;
  final IconData icon;
  final String Function(AppLocalizations) label;
  final String route;

  const NavSubConfig({
    required this.id,
    required this.icon,
    required this.label,
    required this.route,
  });
}

class NavItemConfig {
  final String id;
  final IconData icon;
  final String Function(AppLocalizations) label;
  final String? route;
  final List<NavSubConfig> subItems;

  const NavItemConfig({
    required this.id,
    required this.icon,
    required this.label,
    this.route,
    this.subItems = const [],
  });
}

final navItems = <NavItemConfig>[
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
      ),
      NavSubConfig(
        id: 'inventory-print-labels',
        icon: Icons.label_outline,
        label: (l10n) => l10n.navPrintLabels,
        route: '/inventory/print-labels',
      ),
      NavSubConfig(
        id: 'inventory-export',
        icon: Icons.download_outlined,
        label: (l10n) => l10n.navExportInventory,
        route: '/inventory/export',
      ),
    ],
  ),
];
