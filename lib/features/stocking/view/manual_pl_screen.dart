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
      create: (_) => ManualPlCubit(sl(), sl())..loadClasificaciones(),
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
  String _mode = 'sold';

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
          startDate: _startDate,
          endDate: _endDate,
          clasificacion: _selectedClasificacion,
          mode: _mode,
        );
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
          Text('Manual PL', style: textTheme.headlineSmall),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('entre',
                    style: textTheme.bodyMedium
                        ?.copyWith(color: colorScheme.onSurfaceVariant)),
              ),
              OutlinedButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range, size: 16),
                label: Text(_rangeLabel),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('de',
                    style: textTheme.bodyMedium
                        ?.copyWith(color: colorScheme.onSurfaceVariant)),
              ),
              BlocBuilder<ManualPlCubit, ManualPlState>(
                buildWhen: (prev, curr) =>
                    prev is ManualPlInitial && curr is ManualPlInitial,
                builder: (context, _) {
                  final items =
                      context.read<ManualPlCubit>().clasificaciones;
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: DropdownButtonFormField<String?>(
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
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              BlocBuilder<ManualPlCubit, ManualPlState>(
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
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: BlocBuilder<ManualPlCubit, ManualPlState>(
              builder: (context, state) => switch (state) {
                ManualPlInitial() => Center(
                    child: Text(
                      'Selecciona un rango y presiona Generar.',
                      style: textTheme.bodyMedium
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ManualPlLoading() =>
                  const Center(child: CircularProgressIndicator()),
                ManualPlFailure(:final error) => Center(
                    child: Text(error,
                        style:
                            TextStyle(color: colorScheme.error)),
                  ),
                ManualPlLoaded(:final rows) => rows.isEmpty
                    ? Center(
                        child: Text('Sin datos para este período.',
                            style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant)))
                    : _ResultsTable(rows: rows),
              },
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
    'Disponible',
    'Clasificacion_Descripcion',
  ];

  static const _columnLabels = {
    'DETALLE': 'Detalle',
    'MODELO': 'Modelo',
    'PK_Articulo': 'Codigo',
    'FOB': 'FOB',
    'Cost': 'Costo',
    'Vendido': 'Vendido',
    'Disponible': 'Disponible',
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
    final columns = _columns;
    final selectedRows =
        _selected.map((i) => _sorted[i]).toList();
    if (selectedRows.isEmpty) return;

    String esc(String v) {
      if (v.contains(',') || v.contains('"') || v.contains('\n')) {
        return '"${v.replaceAll('"', '""')}"';
      }
      return v;
    }

    final buf = StringBuffer();
    buf.writeln(columns.map((c) => esc(_label(c))).join(','));
    for (final row in selectedRows) {
      buf.writeln(columns.map((c) => esc('${row[c] ?? ''}')).join(','));
    }

    final dir = Platform.isWindows
        ? '${Platform.environment['USERPROFILE']}\\Downloads'
        : '/Users/${Platform.environment['USER']}/Downloads';
    await Directory(dir).create(recursive: true);
    final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final sep = Platform.isWindows ? '\\' : '/';
    final path = '$dir${sep}manual_pl_$ts.csv';
    await File(path).writeAsString(buf.toString());

    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', path]);
    } else {
      await Process.run('open', [path]);
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('${selectedRows.length} filas exportadas → $path')),
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
        if (_selected.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(
                  '${_selected.length} seleccionadas',
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _export(context),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Exportar'),
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
