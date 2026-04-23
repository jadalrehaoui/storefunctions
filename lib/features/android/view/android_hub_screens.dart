import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Tablet-friendly hub screens used only on Android. Each shows a set of
/// large tap-target cards that navigate deeper into the app.

class AndroidHomeScreen extends StatelessWidget {
  const AndroidHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _HubGrid(
      items: [
        _HubItem(
          icon: Icons.warehouse_outlined,
          label: 'Bodega',
          onTap: () => context.push('/android/bodega'),
        ),
        _HubItem(
          icon: Icons.inventory_2_outlined,
          label: 'Inventario',
          onTap: () => context.push('/android/inventory'),
        ),
        _HubItem(
          icon: Icons.settings_outlined,
          label: 'Configuración',
          onTap: () => context.push('/settings'),
        ),
      ],
    );
  }
}

class AndroidBodegaScreen extends StatelessWidget {
  const AndroidBodegaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _HubGrid(
      items: [
        _HubItem(
          icon: Icons.list_alt_outlined,
          label: 'Listas',
          onTap: () => context.push('/bodega/listas'),
        ),
        _HubItem(
          icon: Icons.local_shipping_outlined,
          label: 'Dispatcho',
          onTap: () => context.push('/bodega/dispatcho'),
        ),
      ],
    );
  }
}

class AndroidInventoryScreen extends StatelessWidget {
  const AndroidInventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _HubGrid(
      items: [
        _HubItem(
          icon: Icons.search,
          label: 'Buscar items',
          onTap: () => context.push('/inventory/search'),
        ),
        _HubItem(
          icon: Icons.label_outline,
          label: 'Imprimir etiquetas',
          onTap: () => context.push('/inventory/print-labels'),
        ),
      ],
    );
  }
}

class _HubItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _HubItem(
      {required this.icon, required this.label, required this.onTap});
}

class _HubGrid extends StatelessWidget {
  final List<_HubItem> items;
  const _HubGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth > 900 ? 3 : 2;
          return GridView.count(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.3,
            children: items.map((i) => _HubCard(item: i)).toList(),
          );
        },
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  final _HubItem item;
  const _HubCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: 64, color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                item.label,
                textAlign: TextAlign.center,
                style: textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
