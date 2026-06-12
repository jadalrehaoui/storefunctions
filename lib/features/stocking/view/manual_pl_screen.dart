import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../di/service_locator.dart';
import '../../inventory/view/inventory_search_screen.dart';
import '../cubit/manual_pl_cubit.dart';

class ManualPlScreen extends StatelessWidget {
  const ManualPlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ManualPlCubit(sl(), sl())
        ..loadClasificaciones()
        ..loadProveedores(),
      child: const _ManualPlView(),
    );
  }
}

class _ManualPlView extends StatefulWidget {
  const _ManualPlView();

  @override
  State<_ManualPlView> createState() => _ManualPlViewState();
}

class _ManualPlViewState extends State<_ManualPlView> {
  DateTime _startDate = DateTime.now().copyWith(day: 1);
  DateTime _endDate = DateTime.now();
  String? _selectedClasificacion;
  String? _selectedProveedor;
  String _mode = 'sold';
  String _matchMode = 'exact';
  bool _soloConModelo = true;
  bool _allTime = false;
  bool _filtersVisible = true;

  static final _displayFmt = DateFormat('MMM d, yyyy');

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange:
          DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  String get _rangeLabel {
    if (_startDate.year == _endDate.year &&
        _startDate.month == _endDate.month &&
        _startDate.day == _endDate.day) {
      return _displayFmt.format(_startDate);
    }
    return '${_displayFmt.format(_startDate)} – ${_displayFmt.format(_endDate)}';
  }

  void _generate() {
    context.read<ManualPlCubit>().generate(
          startDate: _allTime ? null : _startDate,
          endDate: _allTime ? null : _endDate,
          clasificacion: _selectedClasificacion,
          proveedor: _selectedProveedor,
          mode: _mode,
          matchMode: _matchMode,
        );
  }

  /// Collapses rows sharing the same MODELO into a single aggregated row.
  ///
  /// Grouping key is the normalized MODELO (trimmed + uppercased) but the
  /// original MODELO string is kept for display. Quantity columns are summed
  /// across the group; descriptive / per-unit columns are taken from the first
  /// row in the group (they must NOT be summed). `PK_Articulo` is replaced by
  /// the count of articles rolled up into the group. Output is sorted by summed
  /// Vendido descending (stable, deterministic).
  List<Map<String, dynamic>> _groupByModelo(List<dynamic> rows) {
    // Keys whose values are summed across the group.
    const sumKeys = [
      'Vendido',
      'Ingresado',
      'Disponible',
      'Reservado',
      'MontoVendido',
    ];

    final groups = <String, List<Map<String, dynamic>>>{};
    final order = <String>[]; // preserve first-seen order of keys
    for (final r in rows) {
      final row = (r as Map).cast<String, dynamic>();
      final key = (row['MODELO'] ?? '').toString().trim().toUpperCase();
      final bucket = groups[key];
      if (bucket == null) {
        order.add(key);
        groups[key] = [row];
      } else {
        bucket.add(row);
      }
    }

    final result = <Map<String, dynamic>>[];
    for (final key in order) {
      final group = groups[key]!;
      // Start from a copy of the first row so every other column resolves
      // (representative keys: MODELO, DETALLE, Clasificacion_Descripcion, FOB,
      // Cost, Precio, UTILIDAD, Codigo_Barras, Proveedor_Nombre, plus any
      // others present).
      final agg = Map<String, dynamic>.from(group.first);
      for (final k in sumKeys) {
        var sum = 0.0;
        for (final row in group) {
          sum += (row[k] as num?)?.toDouble() ?? 0;
        }
        // Keep whole-number sums as ints so the table renders them the same
        // way it does the original integer-like quantities.
        agg[k] = sum == sum.roundToDouble() ? sum.toInt() : sum;
      }
      // Code column now shows how many article codes rolled up.
      agg['PK_Articulo'] = group.length;
      // MatchBasis is NOT summed: aggregate it explicitly. If ANY article in
      // the group is genuinely the supplier's ('Directo' or 'Comprado') the
      // whole model row reflects that (preferring 'Directo'); only when EVERY
      // article qualified merely by shared MODELO do we show 'Por modelo'.
      if (group.any((row) =>
          (row['MatchBasis'] ?? '').toString().isNotEmpty)) {
        final bases = group
            .map((row) => (row['MatchBasis'] ?? '').toString())
            .toSet();
        agg['MatchBasis'] = bases.contains('Directo')
            ? 'Directo'
            : bases.contains('Comprado')
                ? 'Comprado'
                : 'Por modelo';
      }
      result.add(agg);
    }

    result.sort((a, b) {
      final av = (a['Vendido'] as num?)?.toDouble() ?? 0;
      final bv = (b['Vendido'] as num?)?.toDouble() ?? 0;
      return bv.compareTo(av);
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Manual PL', style: textTheme.headlineSmall),
              const Spacer(),
              IconButton(
                icon: Icon(_filtersVisible
                    ? Icons.filter_list_off
                    : Icons.filter_list),
                tooltip:
                    _filtersVisible ? 'Ocultar filtros' : 'Mostrar filtros',
                onPressed: () =>
                    setState(() => _filtersVisible = !_filtersVisible),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // LEFT: results area fills remaining space.
                Expanded(
                  child: BlocBuilder<ManualPlCubit, ManualPlState>(
                    builder: (context, state) => switch (state) {
                      ManualPlInitial() => Center(
                          child: Text(
                            'Selecciona un rango y presiona Generar.',
                            style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ManualPlLoading() =>
                        const Center(child: CircularProgressIndicator()),
                      ManualPlFailure(:final error) => Center(
                          child: Text(error,
                              style: TextStyle(color: colorScheme.error)),
                        ),
                      ManualPlLoaded(:final rows) => () {
                          final shown = _soloConModelo
                              ? rows.where((r) {
                                  final m = ((r as Map)['MODELO'] ?? '')
                                      .toString()
                                      .trim();
                                  // Treat the POS placeholder "NO MODEL" as
                                  // no model, same as a blank value.
                                  return m.isNotEmpty &&
                                      m.toUpperCase() != 'NO MODEL';
                                }).toList()
                              : rows;
                          // When a proveedor is selected, collapse all rows
                          // sharing the same MODELO into a single aggregated
                          // row (quantities summed). Pure render-time
                          // transform of the already-loaded rows.
                          final result = _selectedProveedor != null
                              ? _groupByModelo(shown)
                              : shown;
                          return result.isEmpty
                              ? Center(
                                  child: Text('Sin datos para este período.',
                                      style: textTheme.bodyMedium?.copyWith(
                                          color:
                                              colorScheme.onSurfaceVariant)))
                              : _ResultsTable(rows: result);
                        }(),
                    },
                  ),
                ),
                // RIGHT: filter sidebar (retractable).
                if (_filtersVisible) ...[
                  const SizedBox(width: 16),
                  _buildSidebar(context, textTheme, colorScheme),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(
      BuildContext context, TextTheme textTheme, ColorScheme colorScheme) {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border(
          left: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text('Filtros',
                          style: textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        tooltip: 'Ocultar filtros',
                        visualDensity: VisualDensity.compact,
                        onPressed: () =>
                            setState(() => _filtersVisible = false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Mode
                  Text('Modo',
                      style: textTheme.labelMedium
                          ?.copyWith(color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'sold', label: Text('Vendido')),
                      ButtonSegment(value: 'bought', label: Text('Comprado')),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (v) =>
                        setState(() => _mode = v.first),
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Date range + all-time toggle
                  Text('Rango de fechas',
                      style: textTheme.labelMedium
                          ?.copyWith(color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: _allTime ? null : _pickRange,
                    icon: const Icon(Icons.date_range, size: 16),
                    label: Text(
                      _rangeLabel,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                  CheckboxListTile(
                    value: _allTime,
                    onChanged: (v) =>
                        setState(() => _allTime = v ?? false),
                    title: const Text('Todo el tiempo'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
                  const SizedBox(height: 12),

                  // Clasificación
                  BlocBuilder<ManualPlCubit, ManualPlState>(
                    buildWhen: (prev, curr) =>
                        prev is ManualPlInitial && curr is ManualPlInitial,
                    builder: (context, _) {
                      final items =
                          context.read<ManualPlCubit>().clasificaciones;
                      return DropdownButtonFormField<String?>(
                        isExpanded: true,
                        value: _selectedClasificacion,
                        decoration: const InputDecoration(
                          labelText: 'Clasificación',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Todas'),
                          ),
                          ...items.map((c) => DropdownMenuItem<String?>(
                                value: c['PK_Clasificacion']?.toString(),
                                child: Text(
                                  c['Descripcion']?.toString() ?? '',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )),
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedClasificacion = v),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Proveedor
                  BlocBuilder<ManualPlCubit, ManualPlState>(
                    buildWhen: (prev, curr) =>
                        prev is ManualPlInitial && curr is ManualPlInitial,
                    builder: (context, _) {
                      final items =
                          context.read<ManualPlCubit>().proveedores;
                      return DropdownButtonFormField<String?>(
                        isExpanded: true,
                        value: _selectedProveedor,
                        decoration: const InputDecoration(
                          labelText: 'Proveedor',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Todos'),
                          ),
                          ...items.map((p) => DropdownMenuItem<String?>(
                                value: p['Nombre']?.toString(),
                                child: Text(
                                  p['Nombre']?.toString() ?? '',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )),
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedProveedor = v),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Coincidencia (match mode) — affects proveedor-filtered
                  // results: Exacto = directly linked / purchased; Por modelo
                  // = broaden to same-MODELO items.
                  Text('Coincidencia',
                      style: textTheme.labelMedium
                          ?.copyWith(color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'exact', label: Text('Exacto')),
                      ButtonSegment(
                          value: 'model', label: Text('Por modelo')),
                    ],
                    selected: {_matchMode},
                    onSelectionChanged: (v) =>
                        setState(() => _matchMode = v.first),
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Solo con modelo
                  SwitchListTile(
                    value: _soloConModelo,
                    onChanged: (v) => setState(() => _soloConModelo = v),
                    title: const Text('Solo con modelo'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ],
              ),
            ),
          ),
          // Generar pinned to the bottom, full-width.
          Padding(
            padding: const EdgeInsets.all(16),
            child: BlocBuilder<ManualPlCubit, ManualPlState>(
              builder: (context, state) => FilledButton.icon(
                onPressed: state is ManualPlLoading ? null : _generate,
                icon: state is ManualPlLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.play_arrow_outlined, size: 18),
                label: const Text('Generar'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultsTable extends StatefulWidget {
  final List<dynamic> rows;
  const _ResultsTable({required this.rows});

  @override
  State<_ResultsTable> createState() => _ResultsTableState();
}

class _ResultsTableState extends State<_ResultsTable> {
  String? _sortColumn;
  bool _ascending = true;
  late List<Map<String, dynamic>> _sorted;
  final Map<String, double> _colWidths = {};
  final ScrollController _hScroll = ScrollController();
  final Set<int> _selected = {};
  static const double _defaultWidth = 130;
  static const double _minWidth = 50;

  static const _visibleColumns = [
    'DETALLE',
    'MODELO',
    'PK_Articulo',
    'FOB',
    'Cost',
    'Vendido',
    'Ingresado',
    'Disponible',
    'MatchBasis',
    'Clasificacion_Descripcion',
  ];

  static const _columnLabels = {
    'DETALLE': 'Detalle',
    'MODELO': 'Modelo',
    'PK_Articulo': 'Codigo',
    'FOB': 'FOB',
    'Cost': 'Costo',
    'Vendido': 'Vendido',
    'Ingresado': 'Ingresado',
    'Disponible': 'Disponible',
    'MatchBasis': 'Origen',
    'Clasificacion_Descripcion': 'Clasificación',
  };

  List<String> get _columns {
    final available = (widget.rows.first as Map<String, dynamic>).keys.toSet();
    return _visibleColumns.where(available.contains).toList();
  }

  String _label(String col) => _columnLabels[col] ?? col;

  double _w(String col) => _colWidths[col] ?? _defaultWidth;

  @override
  void initState() {
    super.initState();
    _sorted = widget.rows.cast<Map<String, dynamic>>().toList();
  }

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ResultsTable old) {
    super.didUpdateWidget(old);
    if (old.rows != widget.rows) {
      _sorted = widget.rows.cast<Map<String, dynamic>>().toList();
      _selected.clear();
      if (_sortColumn != null) _applySort();
    }
  }

  void _onHeaderTap(String col) {
    setState(() {
      if (_sortColumn == col) {
        _ascending = !_ascending;
      } else {
        _sortColumn = col;
        _ascending = true;
      }
      _applySort();
    });
  }

  void _applySort() {
    final col = _sortColumn!;
    _sorted.sort((a, b) {
      final va = a[col];
      final vb = b[col];
      int cmp;
      if (va is num && vb is num) {
        cmp = va.compareTo(vb);
      } else {
        cmp = '${va ?? ''}'.compareTo('${vb ?? ''}');
      }
      return _ascending ? cmp : -cmp;
    });
  }

  Widget _buildHeaderCell(
      String col, TextTheme textTheme, ColorScheme colorScheme) {
    return SizedBox(
      width: _w(col),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _onHeaderTap(col),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      _label(col),
                      style: textTheme.labelSmall?.copyWith(
                        color: _sortColumn == col
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_sortColumn == col)
                    Icon(
                      _ascending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 12,
                      color: colorScheme.primary,
                    ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onHorizontalDragUpdate: (d) {
              setState(() {
                _colWidths[col] =
                    (_w(col) + d.delta.dx).clamp(_minWidth, 600);
              });
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: SizedBox(
                width: 8,
                height: 28,
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
      ),
    );
  }

  void _showInspectDialog(BuildContext context, String code) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 700),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: InventorySearchScreen(initialQuery: code),
          ),
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    final rows = _selected.map((i) => _sorted[i]).toList();
    if (rows.isEmpty) return;
    await _exportRows(context, rows, 'manual_pl');
  }

  Future<void> _exportAll(BuildContext context) async {
    if (_sorted.isEmpty) return;
    await _exportRows(context, _sorted, 'manual_pl_todo');
  }

  Future<void> _exportRows(
      BuildContext context, List<Map<String, dynamic>> rows, String prefix) async {
    final columns = _columns;

    String esc(String v) {
      if (v.contains(',') || v.contains('"') || v.contains('\n')) {
        return '"${v.replaceAll('"', '""')}"';
      }
      return v;
    }

    final buf = StringBuffer();
    buf.writeln(columns.map((c) => esc(_label(c))).join(','));
    for (final row in rows) {
      buf.writeln(columns.map((c) => esc('${row[c] ?? ''}')).join(','));
    }

    final dir = Platform.isWindows
        ? '${Platform.environment['USERPROFILE']}\\Downloads'
        : '/Users/${Platform.environment['USER']}/Downloads';
    await Directory(dir).create(recursive: true);
    final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final sep = Platform.isWindows ? '\\' : '/';
    final path = '$dir$sep${prefix}_$ts.csv';
    await File(path).writeAsString(buf.toString());

    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', path]);
    } else {
      await Process.run('open', [path]);
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${rows.length} filas exportadas → $path')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final columns = _columns;
    final totalWidth =
        columns.fold<double>(0, (sum, col) => sum + _w(col)) + 36;

    final contentWidth = totalWidth + 24;

    return Column(
      children: [
        if (_sorted.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                if (_selected.isNotEmpty)
                  Text(
                    '${_selected.length} seleccionadas',
                    style: textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                const Spacer(),
                if (_selected.isNotEmpty) ...[
                  FilledButton.icon(
                    onPressed: () => _export(context),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Exportar seleccionadas'),
                  ),
                  const SizedBox(width: 8),
                ],
                FilledButton.tonalIcon(
                  onPressed: () => _exportAll(context),
                  icon: const Icon(Icons.download_for_offline_outlined, size: 18),
                  label: const Text('Exportar todo'),
                ),
              ],
            ),
          ),
        Expanded(child: Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          controller: _hScroll,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: contentWidth,
            child: Column(
              children: [
                Container(
                  color: colorScheme.surfaceContainerLow,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Row(
                    children: columns
                        .map((col) =>
                            _buildHeaderCell(col, textTheme, colorScheme))
                        .toList(),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    itemCount: _sorted.length,
                    separatorBuilder: (_, _) => Divider(
                        height: 1, color: colorScheme.outlineVariant),
                    itemBuilder: (context, i) {
                      final row = _sorted[i];
                      final isSelected = _selected.contains(i);
                      return InkWell(
                        onTap: () => setState(() {
                          if (isSelected) {
                            _selected.remove(i);
                          } else {
                            _selected.add(i);
                          }
                        }),
                        child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        color: isSelected
                            ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                            : i.isOdd
                                ? colorScheme.surfaceContainerLowest
                                : null,
                        child: Row(
                          children: [
                            ...columns.map((col) => SizedBox(
                                  width: _w(col),
                                  child: Text(
                                    '${row[col] ?? ''}',
                                    style: textTheme.bodySmall,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )),
                            SizedBox(
                              width: 36,
                              child: IconButton(
                                icon: Icon(Icons.visibility_outlined,
                                    size: 16,
                                    color: colorScheme.onSurfaceVariant),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 28, minHeight: 28),
                                tooltip: 'Inspeccionar',
                                onPressed: () {
                                  final code =
                                      '${row['PK_Articulo'] ?? ''}';
                                  if (code.isEmpty) return;
                                  _showInspectDialog(context, code);
                                },
                              ),
                            ),
                          ],
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
    )),
    ],
    );
  }
}
