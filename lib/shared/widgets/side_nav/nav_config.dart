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
    id: 'billing',
    icon: Icons.receipt_outlined,
    label: (l10n) => l10n.navBilling,
    subItems: [
      NavSubConfig(
        id: 'billing-invoice-new',
        icon: Icons.point_of_sale_outlined,
        label: (l10n) => l10n.navInvoice,
        route: '/invoices/new',
        privilege: 'create_invoice',
      ),
      NavSubConfig(
        id: 'billing-invoice-list',
        icon: Icons.receipt_long_outlined,
        label: (l10n) => l10n.navInvoiceList,
        route: '/invoices',
        privilege: 'view_invoices',
      ),
      NavSubConfig(
        id: 'billing-cierre-caja',
        icon: Icons.account_balance_wallet_outlined,
        label: (l10n) => l10n.navCierreCaja,
        route: '/billing/cierre-caja',
        privilege: 'view_invoices',
      ),
    ],
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
        id: 'reports-restock-list',
        icon: Icons.playlist_add_outlined,
        label: (l10n) => l10n.navRestockList,
        route: '/reports/restock-list',
        privilege: 'generate_restock_list',
      ),
      NavSubConfig(
        id: 'reports-closures',
        icon: Icons.history_outlined,
        label: (l10n) => 'Historial de Cierres',
        route: '/reports/closures',
        privilege: 'inspect_closures',
      ),
    ],
  ),
  NavItemConfig(
    id: 'cierres',
    icon: Icons.account_balance_outlined,
    label: (l10n) => l10n.navCierres,
    subItems: [
      NavSubConfig(
        id: 'cierres-sitsa',
        icon: Icons.store_outlined,
        label: (l10n) => 'Sitsa',
        route: '/reports/cierre-sitsa',
        privilege: 'generate_closure',
      ),
      NavSubConfig(
        id: 'cierres-parallel',
        icon: Icons.compare_arrows_outlined,
        label: (l10n) => 'Parallel',
        route: '/reports/cierre-parallel',
        privilege: 'generate_closure',
      ),
      NavSubConfig(
        id: 'cierres-mikail',
        icon: Icons.storefront_outlined,
        label: (l10n) => 'Mikail',
        route: '/reports/cierre-mikail',
        privilege: 'generate_closure',
      ),
      NavSubConfig(
        id: 'cierres-personales',
        icon: Icons.person_outline,
        label: (l10n) => 'Personales',
        route: '/reports/cierres-personales',
        privilege: 'inspect_own_cierre_personal',
      ),
    ],
  ),
  NavItemConfig(
    id: 'stocking',
    icon: Icons.local_shipping_outlined,
    label: (l10n) => 'Stocking',
    subItems: [
      NavSubConfig(
        id: 'stocking-manual-pl',
        icon: Icons.list_alt_outlined,
        label: (l10n) => 'Manual PL',
        route: '/stocking/manual-pl',
        privilege: 'purchasing_user',
      ),
      NavSubConfig(
        id: 'stocking-automatic-pl',
        icon: Icons.auto_awesome_outlined,
        label: (l10n) => 'Automatic PL',
        route: '/stocking/automatic-pl',
        privilege: 'purchasing_user',
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
