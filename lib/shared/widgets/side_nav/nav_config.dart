import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';

/// Sub-item ids exposed in the Android build. Anything else is hidden from
/// nav and blocked in the router.
const androidAllowedSubIds = <String>{
  'inventory-search',
  'inventory-print-labels',
  'bodega-listas',
};

const androidAllowedRoutes = <String>{
  '/android/home',
  '/android/bodega',
  '/android/inventory',
  '/android/abrir-sesion',
  '/inventory/search',
  '/inventory/print-labels',
  '/bodega/listas',
  '/settings',
};

/// Default landing route on Android when the user has nowhere else to go
/// (e.g. tried to open /dashboard).
const androidFallbackRoute = '/android/home';

/// Returns the nav items to show, filtered for the current platform.
/// Privilege filtering is applied separately at render time.
List<NavItemConfig> navItemsForPlatform() {
  // Windows-only sub-items show on Windows and in debug builds (so they're
  // visible while developing on macOS); hidden in release on macOS/web. On
  // Android the second pass strips anything not in androidAllowedSubIds anyway.
  final platformItems = (Platform.isWindows || kDebugMode)
      ? navItems
      : navItems
            .map((item) {
              final subs = item.subItems
                  .where((s) => !s.windowsOnly)
                  .toList();
              return NavItemConfig(
                id: item.id,
                icon: item.icon,
                label: item.label,
                route: item.route,
                subItems: subs,
                privilege: item.privilege,
              );
            })
            .toList();

  if (!Platform.isAndroid) return platformItems;
  return platformItems
      .map((item) {
        final subs = item.subItems
            .where((s) => androidAllowedSubIds.contains(s.id))
            .toList();
        if (subs.isEmpty) return null;
        return NavItemConfig(
          id: item.id,
          icon: item.icon,
          label: item.label,
          route: item.route,
          subItems: subs,
          privilege: item.privilege,
        );
      })
      .whereType<NavItemConfig>()
      .toList();
}

class NavSubConfig {
  final String id;
  final IconData icon;
  final String Function(AppLocalizations) label;
  final String route;
  final String? privilege;
  final bool windowsOnly;

  const NavSubConfig({
    required this.id,
    required this.icon,
    required this.label,
    required this.route,
    this.privilege,
    this.windowsOnly = false,
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
    id: 'bodega',
    icon: Icons.warehouse_outlined,
    label: (l10n) => 'Bodega',
    privilege: 'bodega_user',
    subItems: [
      NavSubConfig(
        id: 'bodega-listas',
        icon: Icons.list_alt_outlined,
        label: (l10n) => 'Listas',
        route: '/bodega/listas',
        privilege: 'bodega_user',
      ),
      NavSubConfig(
        id: 'bodega-despacho',
        icon: Icons.local_shipping_outlined,
        label: (l10n) => 'Despacho Bod',
        route: '/bodega/despacho',
        privilege: 'bodega_user',
      ),
      NavSubConfig(
        id: 'bodega-despacho-tec',
        icon: Icons.devices_other,
        label: (l10n) => 'Despacho Tec',
        route: '/bodega/despacho-tec',
        privilege: 'bodega_user',
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
        id: 'inventory-codes',
        icon: Icons.qr_code_2,
        label: (l10n) => 'Códigos e inventario',
        route: '/inventory/codes',
        privilege: 'inspect_inventory',
      ),
      NavSubConfig(
        id: 'inventory-lists',
        icon: Icons.checklist_outlined,
        label: (l10n) => 'Listas',
        route: '/inventory/lists',
        privilege: 'inspect_inventory',
      ),
    ],
  ),
  NavItemConfig(
    id: 'ventas',
    icon: Icons.point_of_sale_outlined,
    label: (l10n) => 'Ventas',
    subItems: [
      NavSubConfig(
        id: 'ventas-exportar',
        icon: Icons.download_outlined,
        label: (l10n) => 'Exportar ventas',
        route: '/ventas/exportar',
        // Left null: the two modes are gated inside the screen by their own
        // privileges, so anyone with EITHER privilege can open it.
        privilege: null,
      ),
      NavSubConfig(
        id: 'ventas-manual-pl',
        icon: Icons.list_alt_outlined,
        label: (l10n) => 'Manual PL',
        route: '/ventas/manual-pl',
        privilege: 'purchasing_user',
      ),
      NavSubConfig(
        id: 'ventas-movimiento-articulo',
        icon: Icons.trending_down_outlined,
        label: (l10n) => 'Movimiento de Artículo',
        route: '/ventas/movimiento-articulo',
        privilege: 'inspect_inventory',
      ),
    ],
  ),
  NavItemConfig(
    id: 'reports',
    icon: Icons.bar_chart_outlined,
    label: (l10n) => l10n.navReports,
    subItems: [
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
      NavSubConfig(
        id: 'reports-graphs',
        icon: Icons.show_chart_outlined,
        label: (l10n) => 'Gráficos',
        route: '/reports/graphs',
        privilege: 'see_graphs',
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
    id: 'users',
    icon: Icons.people_outline,
    label: (l10n) => l10n.navUsers,
    route: '/users',
    privilege: 'create_users',
  ),
];
