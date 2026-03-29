import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../di/service_locator.dart';
import '../../../l10n/l10n.dart';
import '../cubit/restock_list_cubit.dart';
import '../utils/restock_pdf.dart' as restock_pdf;

class RestockListScreen extends StatelessWidget {
  const RestockListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RestockListCubit(sl()),
      child: const _RestockListView(),
    );
  }
}

class _RestockListView extends StatefulWidget {
  const _RestockListView();

  @override
  State<_RestockListView> createState() => _RestockListViewState();
}

class _RestockListViewState extends State<_RestockListView> {
  DateTime _date = DateTime.now();
  static final _displayFmt = DateFormat('MMM d, yyyy');
  final _search = TextEditingController();
  String _sortKey = 'Disponible';
  bool _sortAsc = true;

  Future<void> _print(List<Map<String, dynamic>> items) async {
    try {
      final path = await restock_pdf.generateAndOpenRestock(items, _date);
      if (mounted && path != 'printed') {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.msgSavedAt(path))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.msgErrorDetail(e.toString()))));
      }
    }
  }

  Future<void> _export(List<Map<String, dynamic>> items) async {
    try {
      final path = await restock_pdf.exportRestockCsv(items, _date);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.msgSavedAt(path))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.msgErrorDetail(e.toString()))));
      }
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> items) {
    final q = _search.text.toLowerCase().trim();
    var result = q.isEmpty
        ? items
        : items.where((item) {
            return '${item['DETALLE']}'.toLowerCase().contains(q) ||
                '${item['MODELO']}'.toLowerCase().contains(q) ||
                '${item['Clasificacion_Descripcion']}'.toLowerCase().contains(q) ||
                '${item['PK_Articulo']}'.contains(q);
          }).toList();

    result.sort((a, b) {
      final av = a[_sortKey];
      final bv = b[_sortKey];
      int cmp;
      if (av is num && bv is num) {
        cmp = av.compareTo(bv);
      } else {
        cmp = '$av'.compareTo('$bv');
      }
      return _sortAsc ? cmp : -cmp;
    });
    return result;
  }

  void _setSort(String key) {
    setState(() {
      if (_sortKey == key) {
        _sortAsc = !_sortAsc;
      } else {
        _sortKey = key;
        _sortAsc = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.restockListTitle,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          Row(
            children: [
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${context.l10n.labelDate}  ',
                          style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant)),
                      Text(_displayFmt.format(_date),
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 8),
                      Icon(Icons.calendar_today_outlined,
                          size: 14,
                          color: colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () =>
                    context.read<RestockListCubit>().load(_date),
                icon: const Icon(Icons.play_arrow_outlined, size: 18),
                label: Text(context.l10n.btnGenerate),
              ),
              const SizedBox(width: 12),
              BlocBuilder<RestockListCubit, RestockListState>(
                builder: (context, state) => state is RestockListLoaded
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 240,
                            child: TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: context.l10n.labelSearchHint,
                            prefixIcon: const Icon(Icons.search, size: 18),
                            border: const OutlineInputBorder(),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            suffixIcon: _search.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _search.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            onPressed: () => _print(state.items),
                            icon: const Icon(Icons.print_outlined, size: 18),
                            tooltip: context.l10n.tooltipPrintPdf,
                          ),
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            onPressed: () => _export(state.items),
                            icon: const Icon(Icons.download_outlined, size: 18),
                            tooltip: context.l10n.tooltipExportCsv,
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: BlocBuilder<RestockListCubit, RestockListState>(
              builder: (context, state) => switch (state) {
                RestockListInitial() => Center(
                    child: Text(context.l10n.msgSelectDateGenerate)),
                RestockListLoading() =>
                  const Center(child: CircularProgressIndicator()),
                RestockListFailure(:final error) => Center(
                    child: Text(error,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))),
                RestockListLoaded(:final items) =>
                  _RestockTable(
                    items: _filter(items),
                    sortKey: _sortKey,
                    sortAsc: _sortAsc,
                    onSort: _setSort,
                  ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RestockTable extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String sortKey;
  final bool sortAsc;
  final void Function(String) onSort;

  const _RestockTable({
    required this.items,
    required this.sortKey,
    required this.sortAsc,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (items.isEmpty) {
      return Center(
        child: Text(context.l10n.msgNoItems,
            style: TextStyle(color: colorScheme.onSurfaceVariant)),
      );
    }

    Widget sortHeader(String label, String key,
        {int flex = 1, TextAlign align = TextAlign.start}) {
      final active = sortKey == key;
      return Expanded(
        flex: flex,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSort(key),
          child: Row(
            mainAxisAlignment: align == TextAlign.end
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              Text(label,
                  style: textTheme.labelSmall?.copyWith(
                      color: active
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600)),
              if (active) ...[
                const SizedBox(width: 2),
                Icon(
                  sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 12,
                  color: colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(
          children: [
            Container(
              color: colorScheme.surfaceContainerLow,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  sortHeader(context.l10n.colCodigo, 'PK_Articulo', flex: 2),
                  sortHeader(context.l10n.colModelo, 'MODELO', flex: 2),
                  sortHeader(context.l10n.colClasificacion, 'Clasificacion_Descripcion', flex: 2),
                  sortHeader(context.l10n.colDescripcion, 'DETALLE', flex: 5),
                  sortHeader(context.l10n.colDisp, 'Disponible', flex: 1, align: TextAlign.end),
                  sortHeader(context.l10n.colReserv, 'Reservado', flex: 1, align: TextAlign.end),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: colorScheme.outlineVariant),
                itemBuilder: (context, i) {
                  final item = items[i];
                  return Container(
                    color: i.isOdd
                        ? colorScheme.surfaceContainerLowest
                        : null,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text('${item['PK_Articulo'] ?? '—'}',
                              style: textTheme.bodySmall),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                              (item['MODELO'] as String? ?? '').trim().isEmpty
                                  ? '—'
                                  : (item['MODELO'] as String).trim(),
                              style: textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                              '${item['Clasificacion_Descripcion'] ?? '—'}',
                              style: textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Expanded(
                          flex: 5,
                          child: Text('${item['DETALLE'] ?? '—'}',
                              style: textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            '${item['Disponible'] ?? 0}',
                            style: textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: (item['Disponible'] as num? ?? 0) <= 5
                                  ? colorScheme.error
                                  : null,
                            ),
                            textAlign: TextAlign.end,
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            '${item['Reservado'] ?? 0}',
                            style: textTheme.bodySmall,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
