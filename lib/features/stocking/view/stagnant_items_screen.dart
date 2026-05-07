import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../di/service_locator.dart';
import '../../inventory/view/inventory_search_screen.dart';
import '../cubit/stagnant_items_cubit.dart';

class StagnantItemsScreen extends StatelessWidget {
  const StagnantItemsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => StagnantItemsCubit(sl())..loadClasificaciones(),
      child: const _StagnantItemsView(),
    );
  }
}

class _StagnantItemsView extends StatefulWidget {
  const _StagnantItemsView();

  @override
  State<_StagnantItemsView> createState() => _StagnantItemsViewState();
}

class _StagnantItemsViewState extends State<_StagnantItemsView> {
  final _daysController = TextEditingController(text: '90');
  final _limitController = TextEditingController(text: '500');
  String? _selectedClasificacion;

  @override
  void dispose() {
    _daysController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  void _generate() {
    final days = int.tryParse(_daysController.text.trim()) ?? 90;
    final limit = int.tryParse(_limitController.text.trim()) ?? 500;
    final clasif = _selectedClasificacion != null
        ? int.tryParse(_selectedClasificacion!)
        : null;
    context.read<StagnantItemsCubit>().generate(
          days: days < 1 ? 1 : days,
          clasificacion: clasif,
          limit: limit.clamp(1, 2000),
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
          Text('Movimiento de Artículo', style: textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Artículos con stock que no han vendido en X días.',
            style: textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _daysController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Días',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  ),
                  onSubmitted: (_) => _generate(),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _limitController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Límite',
                    helperText: 'máx 2000',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  ),
                  onSubmitted: (_) => _generate(),
                ),
              ),
              const SizedBox(width: 12),
              BlocBuilder<StagnantItemsCubit, StagnantItemsState>(
                buildWhen: (prev, curr) =>
                    prev is StagnantItemsInitial && curr is StagnantItemsInitial,
                builder: (context, _) {
                  final items =
                      context.read<StagnantItemsCubit>().clasificaciones;
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
              BlocBuilder<StagnantItemsCubit, StagnantItemsState>(
                builder: (context, state) => FilledButton.icon(
                  onPressed:
                      state is StagnantItemsLoading ? null : _generate,
                  icon: state is StagnantItemsLoading
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
            child: BlocBuilder<StagnantItemsCubit, StagnantItemsState>(
              builder: (context, state) => switch (state) {
                StagnantItemsInitial() => Center(
                    child: Text(
                      'Ajusta los filtros y presiona Generar.',
                      style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                StagnantItemsLoading() =>
                  const Center(child: CircularProgressIndicator()),
                StagnantItemsFailure(:final error) => Center(
                    child: Text(error,
                        style: TextStyle(color: colorScheme.error)),
                  ),
                StagnantItemsLoaded(:final rows) => rows.isEmpty
                    ? Center(
                        child: Text(
                            'Sin artículos estancados con estos filtros.',
                            style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant)))
                    : _StagnantTable(rows: rows),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StagnantTable extends StatefulWidget {
  final List<Map<String, dynamic>> rows;
  const _StagnantTable({required this.rows});

  @override
  State<_StagnantTable> createState() => _StagnantTableState();
}

class _StagnantTableState extends State<_StagnantTable> {
  String? _sortColumn;
  bool _ascending = true;
  late List<Map<String, dynamic>> _sorted;
  final Map<String, double> _colWidths = {};
  final ScrollController _hScroll = ScrollController();
  final Set<int> _selected = {};
  static const double _minWidth = 50;

  static const _columns = <String>[
    'PK_Articulo',
    'Codigo_Barras',
    'Articulo_Descripcion',
    'MODELO',
    'Clasificacion_Descripcion',
    'Cantidad_Disponible',
    'Costo',
    'Precio',
    'capital_tied',
    'last_sale_date',
    'days_since_last_sale',
    'same_modelo_active',
    'Fecha_Creacion',
  ];

  static const _labels = <String, String>{
    'PK_Articulo': 'Código',
    'Codigo_Barras': 'Cod. Barras',
    'Articulo_Descripcion': 'Descripción',
    'MODELO': 'Modelo',
    'Clasificacion_Descripcion': 'Clasificación',
    'Cantidad_Disponible': 'Disp.',
    'Costo': 'Costo',
    'Precio': 'Precio',
    'capital_tied': 'Capital atado',
    'last_sale_date': 'Última venta',
    'days_since_last_sale': 'Días sin vender',
    'same_modelo_active': 'Modelo activo',
    'Fecha_Creacion': 'Creado',
  };

  static const _defaultWidths = <String, double>{
    'PK_Articulo': 80,
    'Codigo_Barras': 130,
    'Articulo_Descripcion': 240,
    'MODELO': 110,
    'Clasificacion_Descripcion': 140,
    'Cantidad_Disponible': 70,
    'Costo': 90,
    'Precio': 90,
    'capital_tied': 110,
    'last_sale_date': 110,
    'days_since_last_sale': 110,
    'same_modelo_active': 100,
    'Fecha_Creacion': 110,
  };

  static final _moneyFmt = NumberFormat('#,##0.00');
  static final _dateFmt = DateFormat('yyyy-MM-dd');

  String _label(String col) => _labels[col] ?? col;

  double _w(String col) =>
      _colWidths[col] ?? _defaultWidths[col] ?? 120;

  @override
  void initState() {
    super.initState();
    _sorted = List<Map<String, dynamic>>.from(widget.rows);
  }

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _StagnantTable old) {
    super.didUpdateWidget(old);
    if (old.rows != widget.rows) {
      _sorted = List<Map<String, dynamic>>.from(widget.rows);
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
      if (va == null && vb == null) return 0;
      if (va == null) return _ascending ? -1 : 1;
      if (vb == null) return _ascending ? 1 : -1;
      int cmp;
      if (va is num && vb is num) {
        cmp = va.compareTo(vb);
      } else if (va is bool && vb is bool) {
        cmp = (va ? 1 : 0).compareTo(vb ? 1 : 0);
      } else {
        cmp = '$va'.compareTo('$vb');
      }
      return _ascending ? cmp : -cmp;
    });
  }

  String _formatCell(String col, dynamic value) {
    if (value == null) return '—';
    switch (col) {
      case 'Costo':
      case 'Precio':
      case 'capital_tied':
        if (value is num) return _moneyFmt.format(value);
        return value.toString();
      case 'last_sale_date':
      case 'Fecha_Creacion':
        final s = value.toString();
        final parsed = DateTime.tryParse(s);
        return parsed != null ? _dateFmt.format(parsed) : s;
      case 'same_modelo_active':
        if (value is bool) return value ? 'Sí' : 'No';
        return value.toString();
      default:
        return value.toString();
    }
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
                      _ascending ? Icons.arrow_upward : Icons.arrow_downward,
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

  Future<void> _exportRows(BuildContext context,
      List<Map<String, dynamic>> rows, String prefix) async {
    String esc(String v) {
      if (v.contains(',') || v.contains('"') || v.contains('\n')) {
        return '"${v.replaceAll('"', '""')}"';
      }
      return v;
    }

    final buf = StringBuffer();
    buf.write('\u{FEFF}'); // UTF-8 BOM so Excel renders accents correctly
    buf.writeln(_columns.map((c) => esc(_label(c))).join(','));
    for (final row in rows) {
      buf.writeln(_columns
          .map((c) => esc(_formatCell(c, row[c])))
          .join(','));
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
    final totalWidth =
        _columns.fold<double>(0, (sum, col) => sum + _w(col)) + 36;
    final contentWidth = totalWidth + 24;

    return Column(
      children: [
        if (_sorted.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(
                  '${_sorted.length} artículo(s)',
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(width: 16),
                if (_selected.isNotEmpty)
                  Text(
                    '${_selected.length} seleccionadas',
                    style: textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                const Spacer(),
                if (_selected.isNotEmpty) ...[
                  FilledButton.icon(
                    onPressed: () => _exportRows(
                        context,
                        _selected.map((i) => _sorted[i]).toList(),
                        'movimiento_articulo'),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Exportar seleccionadas'),
                  ),
                  const SizedBox(width: 8),
                ],
                FilledButton.tonalIcon(
                  onPressed: () => _exportRows(
                      context, _sorted, 'movimiento_articulo_todo'),
                  icon: const Icon(
                      Icons.download_for_offline_outlined, size: 18),
                  label: const Text('Exportar todo'),
                ),
              ],
            ),
          ),
        Expanded(
          child: Container(
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
                          children: _columns
                              .map((col) => _buildHeaderCell(
                                  col, textTheme, colorScheme))
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
                            final neverSold = row['last_sale_date'] == null;
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
                                    ? colorScheme.primaryContainer
                                        .withValues(alpha: 0.5)
                                    : neverSold
                                        ? colorScheme.errorContainer
                                            .withValues(alpha: 0.18)
                                        : i.isOdd
                                            ? colorScheme
                                                .surfaceContainerLowest
                                            : null,
                                child: Row(
                                  children: [
                                    ..._columns.map((col) => SizedBox(
                                          width: _w(col),
                                          child: Text(
                                            _formatCell(col, row[col]),
                                            style: textTheme.bodySmall,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        )),
                                    SizedBox(
                                      width: 36,
                                      child: IconButton(
                                        icon: Icon(Icons.visibility_outlined,
                                            size: 16,
                                            color:
                                                colorScheme.onSurfaceVariant),
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
          ),
        ),
      ],
    );
  }
}
