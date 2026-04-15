import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../di/service_locator.dart';
import '../../../l10n/l10n.dart';
import '../../../models/combined_item.dart';
import '../../../shared/utils/label_printer.dart';
import '../../../shared/utils/privilege_helpers.dart';
import '../cubit/inventory_search_cubit.dart';
import '../utils/inventory_search_pdf.dart';

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
    return BlocListener<InventorySearchCubit, InventorySearchState>(
      listenWhen: (prev, curr) =>
          curr is InventorySearchDescriptionResults &&
          prev is! InventorySearchDescriptionResults,
      listener: (context, state) {
        if (state is InventorySearchDescriptionResults) {
          _controller.text = state.query;
        }
      },
      child: Padding(
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
                  decoration: InputDecoration(
                    labelText: context.l10n.searchFieldLabel,
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
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
                label: Text(context.l10n.btnSearch),
              ),
              const SizedBox(width: 12),
              BlocBuilder<InventorySearchCubit, InventorySearchState>(
                buildWhen: (_, __) => true,
                builder: (context, _) {
                  final cubit = context.read<InventorySearchCubit>();
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Incluir 0s'),
                      Switch(
                        value: cubit.includeZero,
                        onChanged: (v) => cubit.setIncludeZero(v),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(child: _ResultView(onCodeSelected: _selectCode)),
        ],
      ),
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
    final cubit = context.read<InventorySearchCubit>();
    final sitsa = item.sitsa;
    final canPrint = sitsa != null &&
        (sitsa.codigoBarras ?? '').isNotEmpty &&
        canPrintLabels(context);
    final hasBack = cubit.hasPreviousResults;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasBack || canPrint)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  if (hasBack)
                    TextButton.icon(
                      onPressed: cubit.backToResults,
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: Text('Volver a "${cubit.previousQuery ?? ''}"'),
                    ),
                  const Spacer(),
                  if (canPrint)
                    FilledButton.tonalIcon(
                      onPressed: () => _promptAndPrintLabels(context, item),
                      icon: const Icon(Icons.label_outline, size: 18),
                      label: const Text('Imprimir etiquetas'),
                    ),
                ],
              ),
            ),
          if (item.sitsa != null) _SitsaCard(item: item),
          if (item.sitsa != null) const SizedBox(height: 8),
          if (item.sitsa != null)
            _ModeloSection(state: state, onCodeSelected: onCodeSelected),
        ],
      ),
    );
  }
}

Future<void> _promptAndPrintLabels(
    BuildContext context, CombinedItem item) async {
  final disp = item.sitsa?.disponible?.toInt() ??
      item.mikail?.existencia.toInt() ??
      0;
  final defaultRows = (disp / 2).ceil().clamp(1, 9999);
  final controller = TextEditingController(text: '$defaultRows');
  final messenger = ScaffoldMessenger.of(context);

  final count = await showDialog<int>(
    context: context,
    builder: (ctx) {
      void submit() {
        final v = int.tryParse(controller.text.trim());
        if (v != null && v > 0) Navigator.of(ctx).pop(v);
      }

      return AlertDialog(
        title: const Text('Imprimir etiquetas'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Cantidad de filas (2 etiquetas por fila)',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => submit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: submit,
            child: const Text('Imprimir'),
          ),
        ],
      );
    },
  );

  controller.dispose();
  if (count == null) return;

  try {
    await printCombinedLabel(item, count);
    messenger.showSnackBar(
      SnackBar(content: Text('Enviado: $count fila(s) de etiquetas')),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Error al imprimir: $e')),
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
          label: Text(context.l10n.msgVerMasModelo(modelo)),
        ),
      );
    }

    final items = state.modeloItems!;
    final fobFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    final l10n = context.l10n;
    final columns = [l10n.labelCodigo, 'Barras', l10n.colDescripcion, l10n.labelFob, l10n.colDisp, 'Res.'];
    final colWidths = [100.0, 130.0, null, 90.0, 60.0, 60.0]; // null = flex

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(context.l10n.msgModeloHeader(modelo),
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
                              canSeeProfitMargins(context) ? fobFmt.format(m['FOB'] ?? 0) : redacted,
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

class _DescriptionResultsList extends StatefulWidget {
  final InventorySearchDescriptionResults state;
  final void Function(String) onCodeSelected;
  const _DescriptionResultsList(
      {required this.state, required this.onCodeSelected});

  @override
  State<_DescriptionResultsList> createState() =>
      _DescriptionResultsListState();
}

class _DescriptionResultsListState extends State<_DescriptionResultsList> {
  static const _headers = [
    'Código', 'Barras', 'Descripción', 'Modelo', 'FOB', 'Costo', 'G%', 'Precio', 'Disp.', 'Res.'
  ];
  static const _widths = [100.0, 130.0, null, 120.0, 85.0, 105.0, 50.0, 105.0, 55.0, 45.0];

  // sortable column indices → data keys
  static const _sortKeys = {
    0: 'PK_FK_Articulo',
    2: 'Articulo_Descripcion',
    3: 'MODELO',
    5: 'Costo',
    8: 'Cantidad_Disponible',
  };

  int? _sortCol;
  bool _sortAsc = true;

  List<dynamic> _sorted(List<dynamic> items) {
    if (_sortCol == null) return items;
    final key = _sortKeys[_sortCol!]!;
    final copy = List<dynamic>.from(items);
    copy.sort((a, b) {
      final av = (a as Map<String, dynamic>)[key];
      final bv = (b as Map<String, dynamic>)[key];
      int cmp;
      if (av is num && bv is num) {
        cmp = av.compareTo(bv);
      } else {
        cmp = '${av ?? ''}'.compareTo('${bv ?? ''}');
      }
      return _sortAsc ? cmp : -cmp;
    });
    return copy;
  }

  void _onHeaderTap(int index) {
    if (!_sortKeys.containsKey(index)) return;
    setState(() {
      if (_sortCol == index) {
        _sortAsc = !_sortAsc;
      } else {
        _sortCol = index;
        _sortAsc = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final items = _sorted(widget.state.items);
    final fobFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final costFmt = NumberFormat.currency(symbol: '₡', decimalDigits: 2);

    if (items.isEmpty) {
      return Center(
        child: Text(context.l10n.msgSinResultados(widget.state.query),
            style: textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(context.l10n.msgResultadosPara(widget.state.query),
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
            const Spacer(),
            TextButton.icon(
              onPressed: items.isEmpty
                  ? null
                  : () => generateAndOpenInventorySearch(
                        query: widget.state.query,
                        items: items,
                        showProfit: canSeeProfitMargins(context),
                      ),
              icon: const Icon(Icons.print_outlined, size: 16),
              label: const Text('Imprimir'),
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
                    child: _SortableHeaderRow(
                      headers: _headers,
                      widths: _widths,
                      sortableIndices: _sortKeys.keys.toSet(),
                      sortCol: _sortCol,
                      sortAsc: _sortAsc,
                      onTap: _onHeaderTap,
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
                          onTap: () => widget.onCodeSelected(code),
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
                                canSeeProfitMargins(context) ? fobFmt.format(m['FOB'] ?? 0) : redacted,
                                canSeeProfitMargins(context) ? costFmt.format(m['Costo'] ?? 0) : redacted,
                                canSeeProfitMargins(context) ? '${(m['Ganancia'] as num?)?.toStringAsFixed(0) ?? '0'}%' : redacted,
                                canSeeProfitMargins(context) ? () {
                                  final costo = (m['Costo'] as num?)?.toDouble() ?? 0;
                                  final ganancia = (m['Ganancia'] as num?)?.toDouble() ?? 0;
                                  return costFmt.format(costo + costo * ganancia / 100);
                                }() : redacted,
                                '${m['Cantidad_Disponible'] ?? 0}',
                                '${m['Cantidad_Reservada'] ?? 0}',
                              ],
                              widths: _widths,
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

class _SortableHeaderRow extends StatelessWidget {
  final List<String> headers;
  final List<double?> widths;
  final Set<int> sortableIndices;
  final int? sortCol;
  final bool sortAsc;
  final void Function(int) onTap;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  const _SortableHeaderRow({
    required this.headers,
    required this.widths,
    required this.sortableIndices,
    required this.sortCol,
    required this.sortAsc,
    required this.onTap,
    required this.textTheme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(headers.length, (i) {
        final isSortable = sortableIndices.contains(i);
        final isActive = sortCol == i;
        final cell = GestureDetector(
          onTap: isSortable ? () => onTap(i) : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                headers[i],
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  color: isActive
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isSortable) ...[
                const SizedBox(width: 2),
                Icon(
                  isActive
                      ? (sortAsc ? Icons.arrow_upward : Icons.arrow_downward)
                      : Icons.unfold_more,
                  size: 12,
                  color: isActive
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                ),
              ],
            ],
          ),
        );
        final w = widths[i];
        return w == null ? Expanded(child: cell) : SizedBox(width: w, child: cell);
      }),
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
                    Row(
                      children: [
                        Text(sitsa.classification,
                            style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant)),
                        if (sitsa.invoiceError != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: sitsa.invoiceError!
                                  ? const Color(0xFFFFDEDE)
                                  : const Color(0xFFDEF5E4),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Invoice ${sitsa.invoiceError! ? 'Error' : 'OK'}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: sitsa.invoiceError!
                                    ? const Color(0xFFB00020)
                                    : const Color(0xFF1B5E2A),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                const SizedBox(width: 16),
                // Badges
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (sitsa.vendido != null ||
                          mikail?.vendido != null ||
                          (item.workdbVendido ?? 0) > 0)
                        IntrinsicWidth(
                          child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (sitsa.vendido != null)
                              _Badge(
                                label: context.l10n.labelVendidoSitsa,
                                value: num_.format(sitsa.vendido),
                                color: const Color(0xFFD0E4FF),
                                onColor: const Color(0xFF003366),
                              ),
                            if (sitsa.vendido != null && mikail?.vendido != null)
                              const SizedBox(height: 4),
                            if (mikail?.vendido != null)
                              _Badge(
                                label: context.l10n.labelVendidoMikail,
                                value: num_.format(mikail!.vendido),
                                color: const Color(0xFFD4F0DC),
                                onColor: const Color(0xFF1B5E2A),
                              ),
                            if ((item.workdbVendido ?? 0) > 0 &&
                                (sitsa.vendido != null ||
                                    mikail?.vendido != null))
                              const SizedBox(height: 4),
                            if ((item.workdbVendido ?? 0) > 0)
                              _Badge(
                                label: context.l10n.labelVendidoWorkdb,
                                value: num_.format(item.workdbVendido),
                                color: const Color(0xFFFFE0B2),
                                onColor: const Color(0xFF6B3A00),
                              ),
                          ],
                        ),
                        ),
                      if ((sitsa.vendido != null ||
                              mikail?.vendido != null ||
                              item.workdbVendido != null) &&
                          item.totalVentas != null)
                        const SizedBox(width: 8),
                      if (item.totalVentas != null)
                        _StretchBadge(
                          label: context.l10n.labelVenta,
                          value: num_.format(item.totalVentas),
                          color: const Color(0xFFFFF0CC),
                          onColor: const Color(0xFF5C3D00),
                        ),
                      if (mikail != null) const SizedBox(width: 8),
                      if (mikail != null)
                        _StretchBadge(
                          label: context.l10n.labelIngreso,
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
                      label: context.l10n.labelCosto,
                      value: canSeeProfitMargins(context) ? colones.format(sitsa.costo) : redacted,
                      valueStyle: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                    ),
                    _InfoTile(
                      label: context.l10n.labelGanancia,
                      value: canSeeProfitMargins(context) ? '${sitsa.ganancia.toStringAsFixed(0)}%' : redacted,
                    ),
                    _InfoTile(
                      label: context.l10n.labelPrecio,
                      value: colones.format(
                          sitsa.costo + sitsa.costo * sitsa.ganancia / 100),
                    ),
                    _InfoTile(
                      label: context.l10n.labelFob,
                      value: canSeeProfitMargins(context) ? currency.format(sitsa.fob) : redacted,
                    ),
                    if (sitsa.salida != null)
                      _InfoTile(
                        label: context.l10n.labelSalida,
                        value: num_.format(sitsa.salida),
                      ),
                  ],
                ),
                const Spacer(),
                if (sitsa.disponible != null)
                  _Badge(
                    label: context.l10n.labelDisponible,
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

