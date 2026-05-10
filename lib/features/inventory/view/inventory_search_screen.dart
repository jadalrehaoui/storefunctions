import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../di/service_locator.dart';
import '../../../l10n/l10n.dart';
import '../../../models/combined_item.dart';
import '../../../services/item_lists_service.dart';
import '../../../shared/utils/label_printer.dart';
import '../../../shared/utils/privilege_helpers.dart';
import '../cubit/inventory_search_cubit.dart';
import '../utils/inventory_search_excel.dart';

class InventorySearchScreen extends StatelessWidget {
  final String? initialQuery;
  const InventorySearchScreen({super.key, this.initialQuery});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = InventorySearchCubit(sl());
        if (initialQuery != null && initialQuery!.isNotEmpty) {
          cubit.search(initialQuery!);
        }
        return cubit;
      },
      child: _InventorySearchView(initialQuery: initialQuery),
    );
  }
}

class _InventorySearchView extends StatefulWidget {
  final String? initialQuery;
  const _InventorySearchView({this.initialQuery});

  @override
  State<_InventorySearchView> createState() => _InventorySearchViewState();
}

class _InventorySearchViewState extends State<_InventorySearchView> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _controller.text = widget.initialQuery!;
    }
  }

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
          if (hasBack || canPrint || sitsa != null)
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
                  if (sitsa != null)
                    FilledButton.tonalIcon(
                      onPressed: () => _promptAndAddToList(context, item),
                      icon: const Icon(Icons.playlist_add, size: 18),
                      label: const Text('Agregar a lista'),
                    ),
                  if (sitsa != null && canPrint) const SizedBox(width: 8),
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

Future<void> _promptAndAddToList(
    BuildContext context, CombinedItem item) async {
  final messenger = ScaffoldMessenger.of(context);
  final code = item.code;
  if (code.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No hay código para agregar.')),
    );
    return;
  }

  final result = await showDialog<({String type, int qty})>(
    context: context,
    builder: (_) => _AddToListDialog(itemDescription: item.sitsa?.description),
  );
  if (result == null) return;
  final type = result.type;
  final addQty = result.qty;
  if (type.isEmpty || addQty < 1) return;

  final service = sl<ItemListsService>();
  try {
    final addData = await service.addItem(type: type, code: code);
    final responseQty = (addData is Map && addData['qty'] is num)
        ? (addData['qty'] as num).toInt()
        : 1;
    final id = (addData is Map && addData['id'] is num)
        ? (addData['id'] as num).toInt()
        : null;

    var finalQty = responseQty;
    if (addQty > 1 && id != null) {
      final desired = responseQty + (addQty - 1);
      final putData =
          await service.updateItem(id, qty: desired);
      if (putData is Map && putData['qty'] is num) {
        finalQty = (putData['qty'] as num).toInt();
      } else {
        finalQty = desired;
      }
    }

    final wasNew = responseQty == addQty || responseQty == 1;
    final msg = wasNew
        ? 'Agregado a "$type" (qty: $finalQty)'
        : 'Cantidad actualizada en "$type" (qty: $finalQty)';
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  } on DioException catch (e) {
    final detail = e.response?.data is Map
        ? (e.response!.data as Map)['error']?.toString()
        : null;
    messenger.showSnackBar(
      SnackBar(content: Text(detail ?? e.message ?? 'Error de conexión')),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
  }
}

class _AddToListDialog extends StatefulWidget {
  final String? itemDescription;
  const _AddToListDialog({this.itemDescription});

  @override
  State<_AddToListDialog> createState() => _AddToListDialogState();
}

class _AddToListDialogState extends State<_AddToListDialog> {
  final _newTypeController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  List<Map<String, dynamic>>? _types;
  String? _error;
  String? _selectedType;
  bool _creatingNew = false;

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  @override
  void dispose() {
    _newTypeController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  int get _qty => int.tryParse(_qtyController.text.trim()) ?? 0;

  Future<void> _loadTypes() async {
    try {
      final data = await sl<ItemListsService>().getTypes();
      final list = (data is Map && data['types'] is List)
          ? (data['types'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _types = list;
        _creatingNew = list.isEmpty;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudieron cargar las listas: $e');
    }
  }

  void _submit() {
    final type = _creatingNew
        ? _newTypeController.text.trim()
        : (_selectedType ?? '');
    if (type.isEmpty) return;
    final qty = _qty;
    if (qty < 1) return;
    Navigator.of(context).pop((type: type, qty: qty));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Agregar a lista'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.itemDescription != null) ...[
              Text(
                widget.itemDescription!,
                style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
            ],
            if (_error != null)
              Text(_error!, style: TextStyle(color: colorScheme.error))
            else if (_types == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else ...[
              if (_types!.isNotEmpty) ...[
                Text('Listas existentes',
                    style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in _types!)
                      ChoiceChip(
                        label: Text(
                          '${t['type']} (${t['count']})',
                        ),
                        selected: !_creatingNew &&
                            _selectedType == t['type']?.toString(),
                        onSelected: (sel) => setState(() {
                          _creatingNew = false;
                          _selectedType = sel ? t['type']?.toString() : null;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Checkbox(
                    value: _creatingNew,
                    onChanged: (v) => setState(() {
                      _creatingNew = v ?? false;
                      if (_creatingNew) _selectedType = null;
                    }),
                  ),
                  const Text('Nueva lista'),
                ],
              ),
              if (_creatingNew)
                TextField(
                  controller: _newTypeController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la lista',
                    hintText: 'p.ej. destruccion, watchlist',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _submit(),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cantidad',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: ((_creatingNew &&
                          _newTypeController.text.trim().isNotEmpty) ||
                      (!_creatingNew && _selectedType != null)) &&
                  _qty >= 1
              ? _submit
              : null,
          child: const Text('Agregar'),
        ),
      ],
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
  // Android shows only a subset of columns: Código, Descripción, Modelo, Disp.
  List<String> get _headers => Platform.isAndroid
      ? const ['Código', 'Descripción', 'Modelo', 'Disp.']
      : const [
          'Código', 'Barras', 'Descripción', 'Modelo', 'FOB',
          'Costo', 'G%', 'Precio', 'Disp.', 'Res.', 'Ingr.'
        ];

  late final List<double?> _widths = Platform.isAndroid
      ? <double?>[100.0, 220.0, 120.0, 55.0]
      : <double?>[100.0, 130.0, 220.0, 120.0, 85.0, 105.0, 50.0, 105.0, 55.0, 45.0, 45.0];

  static const double _minColumnWidth = 40.0;

  void _resizeColumn(int index, double delta) {
    final current = _widths[index];
    if (current == null) return;
    final next = (current + delta).clamp(_minColumnWidth, 800.0);
    if (next == current) return;
    setState(() => _widths[index] = next);
  }

  // Column positions (within the active `_headers`) that are sortable, mapped
  // to the data key they sort by.
  Map<int, String> get _sortKeys => Platform.isAndroid
      ? const {
          0: 'PK_FK_Articulo',
          1: 'Articulo_Descripcion',
          2: 'MODELO',
          3: 'Cantidad_Disponible',
        }
      : const {
          0: 'PK_FK_Articulo',
          2: 'Articulo_Descripcion',
          3: 'MODELO',
          5: 'Costo',
          8: 'Cantidad_Disponible',
        };

  final ScrollController _hScroll = ScrollController();

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

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
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final path = await exportInventorySearchToExcel(
                          query: widget.state.query,
                          items: items,
                          showProfit: canSeeProfitMargins(context),
                        );
                        messenger.showSnackBar(
                          SnackBar(content: Text('Exportado: $path')),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Error al exportar: $e')),
                        );
                      }
                    },
              icon: const Icon(Icons.file_download_outlined, size: 16),
              label: const Text('Exportar'),
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
              child: LayoutBuilder(builder: (context, constraints) {
                final contentWidth = _widths
                        .whereType<double>()
                        .fold<double>(0, (a, b) => a + b) +
                    24;
                final needsScroll = contentWidth > constraints.maxWidth;
                return Scrollbar(
                  controller: _hScroll,
                  thumbVisibility: needsScroll,
                  child: SingleChildScrollView(
                    controller: _hScroll,
                    scrollDirection: Axis.horizontal,
                    physics: needsScroll
                        ? const AlwaysScrollableScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    child: SizedBox(
                      width:
                          needsScroll ? contentWidth : constraints.maxWidth,
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
                      onResize: _resizeColumn,
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
                              columns: Platform.isAndroid
                                  ? [
                                      code,
                                      m['Articulo_Descripcion'] as String? ??
                                          '',
                                      m['MODELO'] as String? ?? '',
                                      '${m['Cantidad_Disponible'] ?? 0}',
                                    ]
                                  : [
                                      code,
                                      m['Codigo_Barras'] as String? ?? '',
                                      m['Articulo_Descripcion'] as String? ?? '',
                                      m['MODELO'] as String? ?? '',
                                      canSeeProfitMargins(context) ? fobFmt.format(m['FOB'] ?? 0) : redacted,
                                      canSeeProfitMargins(context) ? costFmt.format(m['Costo'] ?? 0) : redacted,
                                      canSeeProfitMargins(context)
                                          ? '${((m['UTILIDAD'] ?? m['Ganancia']) as num?)?.toStringAsFixed(0) ?? '0'}%'
                                          : redacted,
                                      canSeeProfitMargins(context) ? () {
                                        final precio = (m['Precio'] as num?)?.toDouble();
                                        if (precio != null) return costFmt.format(precio);
                                        final costo = (m['Costo'] as num?)?.toDouble() ?? 0;
                                        final util = ((m['UTILIDAD'] ?? m['Ganancia']) as num?)?.toDouble() ?? 0;
                                        return costFmt.format(costo + costo * util / 100);
                                      }() : redacted,
                                      '${m['Cantidad_Disponible'] ?? 0}',
                                      '${m['Cantidad_Reservada'] ?? 0}',
                                      '${m['Ingresado'] ?? 0}',
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
                );
              }),
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
  final void Function(int index, double delta)? onResize;
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
    this.onResize,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(headers.length, (i) {
        final isSortable = sortableIndices.contains(i);
        final isActive = sortCol == i;
        final label = GestureDetector(
          onTap: isSortable ? () => onTap(i) : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  headers[i],
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: isActive
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
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
        final canResize = w != null && onResize != null;
        final cellWithHandle = Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: label,
            ),
            if (canResize)
              Positioned(
                top: -8,
                bottom: -8,
                right: -4,
                width: 12,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: (d) =>
                        onResize!(i, d.delta.dx),
                    child: Center(
                      child: Container(
                        width: 1,
                        color: colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
        return w == null
            ? Expanded(child: cellWithHandle)
            : SizedBox(width: w, child: cellWithHandle);
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
            // Title (selectable so the user can copy the description)
            SelectableText(
              sitsa.description,
              style: textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            if ((sitsa.codigoBarras ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              _CopyableRow(
                label: 'Código de Barras',
                value: sitsa.codigoBarras!,
              ),
            ],
            const SizedBox(height: 6),
            // Subtitle + badges row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(sitsa.model,
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
                      if (sitsa.ingresado != null) const SizedBox(width: 8),
                      if (sitsa.ingresado != null)
                        _StretchBadge(
                          label: context.l10n.labelIngresado,
                          value: num_.format(sitsa.ingresado),
                          color: const Color(0xFFEDD5F5),
                          onColor: const Color(0xFF4A0072),
                        ),
                      if (item.ticaFetched) const SizedBox(width: 8),
                      if (item.ticaFetched)
                        _StretchBadge(
                          label: 'TICA',
                          value: item.tica ?? 'No disponible',
                          color: item.tica == null
                              ? const Color(0xFFEEEEEE)
                              : const Color(0xFFD6EAD6),
                          onColor: item.tica == null
                              ? const Color(0xFF555555)
                              : const Color(0xFF1A3D1A),
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
                      value: canSeeProfitMargins(context) ? '${sitsa.utilidad.toStringAsFixed(0)}%' : redacted,
                    ),
                    _InfoTile(
                      label: context.l10n.labelPrecio,
                      value: colones.format(sitsa.precio),
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
                if (sitsa.reservada != null) const SizedBox(width: 8),
                if (sitsa.reservada != null)
                  _Badge(
                    label: context.l10n.labelReservada,
                    value: num_.format(sitsa.reservada),
                    color: const Color(0xFFFFE0B2),
                    onColor: const Color(0xFF6B3A00),
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

class _CopyableRow extends StatelessWidget {
  final String label;
  final String value;
  const _CopyableRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ',
            style: textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant)),
        SelectableText(
          value,
          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
        ),
        const SizedBox(width: 4),
        InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('$label copiado'),
                  duration: const Duration(seconds: 1)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.copy_outlined,
                size: 14, color: colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

