import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../di/service_locator.dart';
import '../../../l10n/l10n.dart';
import '../../../models/combined_item.dart';
import '../cubit/inventory_search_cubit.dart';

class InventorySearchScreen extends StatelessWidget {
  const InventorySearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InventorySearchCubit(sl()),
      child: const _InventorySearchView(),
    );
  }
}

class _InventorySearchView extends StatefulWidget {
  const _InventorySearchView();

  @override
  State<_InventorySearchView> createState() => _InventorySearchViewState();
}

class _InventorySearchViewState extends State<_InventorySearchView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() =>
      context.read<InventorySearchCubit>().search(_controller.text);

  void _selectCode(String code) {
    _controller.text = code;
    context.read<InventorySearchCubit>().search(code);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.inventorySearchTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    labelText: 'Código',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _submit(),
                  autofocus: true,
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Buscar'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(child: _ResultView(onCodeSelected: _selectCode)),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final void Function(String) onCodeSelected;
  const _ResultView({required this.onCodeSelected});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InventorySearchCubit, InventorySearchState>(
      builder: (context, state) => switch (state) {
        InventorySearchInitial() => const SizedBox.shrink(),
        InventorySearchLoading() =>
          const Center(child: CircularProgressIndicator()),
        InventorySearchFailure(:final error) => Center(
            child: Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        InventorySearchSuccess() => _ItemLayout(
            state: state as InventorySearchSuccess,
            onCodeSelected: onCodeSelected,
          ),
        InventorySearchDescriptionResults() => _DescriptionResultsList(
            state: state as InventorySearchDescriptionResults,
            onCodeSelected: onCodeSelected,
          ),
      },
    );
  }
}

class _ItemLayout extends StatelessWidget {
  final InventorySearchSuccess state;
  final void Function(String) onCodeSelected;
  const _ItemLayout({required this.state, required this.onCodeSelected});

  @override
  Widget build(BuildContext context) {
    final item = state.item;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.sitsa != null) _SitsaCard(item: item),
          if (item.sitsa != null) const SizedBox(height: 8),
          if (item.sitsa != null)
            _ModeloSection(state: state, onCodeSelected: onCodeSelected),
        ],
      ),
    );
  }
}

class _ModeloSection extends StatelessWidget {
  final InventorySearchSuccess state;
  final void Function(String) onCodeSelected;
  const _ModeloSection({required this.state, required this.onCodeSelected});

  @override
  Widget build(BuildContext context) {
    final modelo = state.item.sitsa!.model;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (state.modeloLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.modeloItems == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () =>
              context.read<InventorySearchCubit>().loadModeloItems(modelo),
          icon: const Icon(Icons.inventory_2_outlined, size: 16),
          label: Text('Ver más con modelo $modelo'),
        ),
      );
    }

    final items = state.modeloItems!;
    final fobFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    final columns = ['Código', 'Barras', 'Descripción', 'FOB', 'Disp.', 'Res.'];
    final colWidths = [100.0, 130.0, null, 90.0, 60.0, 60.0]; // null = flex

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Modelo $modelo',
                style: textTheme.labelLarge
                    ?.copyWith(color: colorScheme.onSurfaceVariant)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${items.length}',
                  style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSecondaryContainer)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Column(
              children: [
                // Header
                Container(
                  color: colorScheme.surfaceContainerLow,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: _ModeloRow(
                    columns: columns,
                    widths: colWidths,
                    isHeader: true,
                    textTheme: textTheme,
                    colorScheme: colorScheme,
                  ),
                ),
                const Divider(height: 1),
                // Rows
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: colorScheme.outlineVariant),
                    itemBuilder: (context, i) {
                      final m = items[i] as Map<String, dynamic>;
                      final code = m['PK_FK_Articulo'] as String? ?? '';
                      final disp = m['Cantidad_Disponible'];
                      final res = m['Cantidad_Reservada'];
                      return InkWell(
                        onTap: () => onCodeSelected(code),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          color: i.isOdd
                              ? colorScheme.surfaceContainerLowest
                              : null,
                          child: _ModeloRow(
                            columns: [
                              code,
                              m['Codigo_Barras'] as String? ?? '',
                              m['Articulo_Descripcion'] as String? ?? '',
                              fobFmt.format(m['FOB'] ?? 0),
                              '$disp',
                              '$res',
                            ],
                            widths: colWidths,
                            isHeader: false,
                            textTheme: textTheme,
                            colorScheme: colorScheme,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DescriptionResultsList extends StatelessWidget {
  final InventorySearchDescriptionResults state;
  final void Function(String) onCodeSelected;
  const _DescriptionResultsList(
      {required this.state, required this.onCodeSelected});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final items = state.items;
    final fobFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final costFmt = NumberFormat.currency(symbol: '₡', decimalDigits: 2);

    if (items.isEmpty) {
      return Center(
        child: Text('Sin resultados para "${state.query}"',
            style: textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant)),
      );
    }

    const headers = ['Código', 'Barras', 'Descripción', 'Modelo', 'FOB', 'Costo', 'G%', 'Disp.', 'Res.'];
    const widths = [100.0, 130.0, null, 120.0, 85.0, 105.0, 50.0, 55.0, 45.0];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Resultados para "${state.query}"',
                style: textTheme.labelLarge
                    ?.copyWith(color: colorScheme.onSurfaceVariant)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${items.length}',
                  style: textTheme.labelSmall
                      ?.copyWith(color: colorScheme.onSecondaryContainer)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Column(
                children: [
                  // Header
                  Container(
                    color: colorScheme.surfaceContainerLow,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: _ModeloRow(
                      columns: headers,
                      widths: widths,
                      isHeader: true,
                      textTheme: textTheme,
                      colorScheme: colorScheme,
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: colorScheme.outlineVariant),
                      itemBuilder: (context, i) {
                        final m = items[i] as Map<String, dynamic>;
                        final code = m['PK_FK_Articulo'] as String? ?? '';
                        return InkWell(
                          onTap: () => onCodeSelected(code),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            color: i.isOdd
                                ? colorScheme.surfaceContainerLowest
                                : null,
                            child: _ModeloRow(
                              columns: [
                                code,
                                m['Codigo_Barras'] as String? ?? '',
                                m['Articulo_Descripcion'] as String? ?? '',
                                m['MODELO'] as String? ?? '',
                                fobFmt.format(m['FOB'] ?? 0),
                                costFmt.format(m['Costo'] ?? 0),
                                '${(m['Ganancia'] as num?)?.toStringAsFixed(0) ?? '0'}%',
                                '${m['Cantidad_Disponible'] ?? 0}',
                                '${m['Cantidad_Reservada'] ?? 0}',
                              ],
                              widths: widths,
                              isHeader: false,
                              textTheme: textTheme,
                              colorScheme: colorScheme,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ModeloRow extends StatelessWidget {
  final List<String> columns;
  final List<double?> widths;
  final bool isHeader;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  const _ModeloRow({
    required this.columns,
    required this.widths,
    required this.isHeader,
    required this.textTheme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(columns.length, (i) {
        final cell = Text(
          columns[i],
          overflow: TextOverflow.ellipsis,
          style: isHeader
              ? textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600)
              : textTheme.bodySmall,
        );
        final w = widths[i];
        return w == null
            ? Expanded(child: cell)
            : SizedBox(width: w, child: cell);
      }),
    );
  }
}

class _SitsaCard extends StatelessWidget {
  final CombinedItem item;
  const _SitsaCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final sitsa = item.sitsa!;
    final mikail = item.mikail;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final colones = NumberFormat.currency(symbol: '₡', decimalDigits: 2);
    final num_ = NumberFormat.decimalPattern();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              sitsa.description,
              style: textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            // Subtitle + badges row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sitsa.model,
                        style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(sitsa.classification,
                        style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant)),
                  ],
                ),
                const Spacer(),
                const SizedBox(width: 16),
                // Badges
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (sitsa.vendido != null || mikail?.vendido != null)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (sitsa.vendido != null)
                              _Badge(
                                label: 'Vendido Sitsa',
                                value: num_.format(sitsa.vendido),
                                color: const Color(0xFFD0E4FF),
                                onColor: const Color(0xFF003366),
                              ),
                            if (sitsa.vendido != null && mikail?.vendido != null)
                              const SizedBox(height: 4),
                            if (mikail?.vendido != null)
                              _Badge(
                                label: 'Vendido Mikail',
                                value: num_.format(mikail!.vendido),
                                color: const Color(0xFFD4F0DC),
                                onColor: const Color(0xFF1B5E2A),
                              ),
                          ],
                        ),
                      if ((sitsa.vendido != null || mikail?.vendido != null) &&
                          item.totalVentas != null)
                        const SizedBox(width: 8),
                      if (item.totalVentas != null)
                        _StretchBadge(
                          label: 'Venta',
                          value: num_.format(item.totalVentas),
                          color: const Color(0xFFFFF0CC),
                          onColor: const Color(0xFF5C3D00),
                        ),
                      if (mikail != null) const SizedBox(width: 8),
                      if (mikail != null)
                        _StretchBadge(
                          label: 'Ingreso',
                          value: num_.format(mikail.ingreso),
                          color: const Color(0xFFEDD5F5),
                          onColor: const Color(0xFF4A0072),
                        ),
                      if (item.tica != null) const SizedBox(width: 8),
                      if (item.tica != null)
                        _StretchBadge(
                          label: 'TICA',
                          value: item.tica!,
                          color: const Color(0xFFD6EAD6),
                          onColor: const Color(0xFF1A3D1A),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Wrap(
                  spacing: 32,
                  runSpacing: 12,
                  children: [
                    _InfoTile(
                      label: 'Costo',
                      value: colones.format(sitsa.costo),
                      valueStyle: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                    ),
                    _InfoTile(
                      label: 'Ganancia',
                      value: '${sitsa.ganancia.toStringAsFixed(0)}%',
                    ),
                    _InfoTile(
                      label: 'Precio',
                      value: colones.format(
                          sitsa.costo + sitsa.costo * sitsa.ganancia / 100),
                    ),
                    _InfoTile(
                      label: 'FOB',
                      value: currency.format(sitsa.fob),
                    ),
                  ],
                ),
                const Spacer(),
                if (sitsa.disponible != null)
                  _Badge(
                    label: 'Disponible',
                    value: num_.format(sitsa.disponible),
                    color: colorScheme.primaryContainer,
                    onColor: colorScheme.onPrimaryContainer,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final String? value;
  final Color color;
  final Color onColor;

  const _Badge({
    required this.label,
    required this.value,
    required this.color,
    required this.onColor,
  });

  @override
  Widget build(BuildContext context) {
    if (value == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: onColor)),
          const SizedBox(height: 2),
          Text(
            value!,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: onColor),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _InfoTile({required this.label, required this.value, this.valueStyle});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value,
            style: valueStyle ??
                textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _StretchBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color onColor;

  const _StretchBadge({
    required this.label,
    required this.value,
    required this.color,
    required this.onColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: onColor)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: onColor),
          ),
        ],
      ),
    );
  }
}

