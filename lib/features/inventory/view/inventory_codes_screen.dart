import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../di/service_locator.dart';
import '../../../l10n/l10n.dart';
import '../../../services/inventory_service.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../cubit/enrich_codes_cubit.dart';
import '../cubit/export_inventory_cubit.dart';
import '../cubit/validate_barcodes_cubit.dart';

// ---------------------------------------------------------------------------
// Shared column model
// ---------------------------------------------------------------------------

/// One selectable column shared by the Enriquecer and Exportar modes.
/// [exportKey] is the JSON key in `get-inventory.data`; [enrichKey] is the
/// JSON key in `enrich-codes.items`.
class InventoryColumn {
  final String id;
  final String label;
  final String exportKey;
  final String enrichKey;
  final bool isTica;

  const InventoryColumn({
    required this.id,
    required this.label,
    required this.exportKey,
    required this.enrichKey,
    this.isTica = false,
  });
}

const kInventoryColumns = <InventoryColumn>[
  InventoryColumn(
      id: 'codigo',
      label: 'Código',
      exportKey: 'PK_FK_Articulo',
      enrichKey: 'sitsa_code'),
  InventoryColumn(
      id: 'barras',
      label: 'Barras',
      exportKey: 'Codigo_Barras',
      enrichKey: 'barcode'),
  InventoryColumn(
      id: 'descripcion',
      label: 'Descripción',
      exportKey: 'Articulo_Descripcion',
      enrichKey: 'descripcion'),
  InventoryColumn(
      id: 'modelo', label: 'Modelo', exportKey: 'MODELO', enrichKey: 'modelo'),
  InventoryColumn(
      id: 'clasificacion',
      label: 'Clasificación',
      exportKey: 'Clasificacion_Descripcion',
      enrichKey: 'Clasificacion'),
  InventoryColumn(
      id: 'cabys',
      label: 'Cabys',
      exportKey: 'Cabys',
      enrichKey: 'Cabys'),
  InventoryColumn(
      id: 'fob', label: 'FOB', exportKey: 'FOB', enrichKey: 'FOB'),
  InventoryColumn(
      id: 'costo', label: 'Costo', exportKey: 'Cost', enrichKey: 'Costo'),
  InventoryColumn(
      id: 'utilidad',
      label: 'Utilidad %',
      exportKey: 'UTILIDAD',
      enrichKey: 'UTILIDAD'),
  InventoryColumn(
      id: 'precio', label: 'Precio', exportKey: 'Precio', enrichKey: 'Precio'),
  InventoryColumn(
      id: 'disponible',
      label: 'Disponible',
      exportKey: 'Cantidad_Disponible',
      enrichKey: 'qty'),
  InventoryColumn(
      id: 'reservada',
      label: 'Reservada',
      exportKey: 'Cantidad_Reservada',
      enrichKey: 'Reservada'),
  InventoryColumn(
      id: 'proveedor',
      label: 'Proveedor',
      exportKey: 'Proveedor_Nombre',
      enrichKey: 'Proveedor_Nombre'),
  InventoryColumn(
      id: 'ingresado',
      label: 'Ingresado',
      exportKey: 'Ingresado',
      enrichKey: 'Ingresado'),
  InventoryColumn(
      id: 'vendido',
      label: 'Vendido',
      exportKey: 'Vendido',
      enrichKey: 'Vendido'),
  InventoryColumn(
      id: 'tica',
      label: 'Tica',
      exportKey: 'Tica',
      enrichKey: 'tica',
      isTica: true),
];

/// Sensible default-checked subset.
const _kDefaultChecked = <String>{
  'codigo',
  'barras',
  'descripcion',
  'modelo',
  'disponible',
};

const _kTicaWarning =
    'Incluir Tica consulta Hacienda en vivo y puede tardar bastante.';
const _kTicaConcurrency = 3;

enum InventoryCodesMode { validar, enriquecer, exportar }

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class InventoryCodesScreen extends StatelessWidget {
  const InventoryCodesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ValidateBarcodesCubit(sl())),
        BlocProvider(create: (_) => EnrichCodesCubit(sl())),
        BlocProvider(
            create: (_) => ExportInventoryCubit(sl())..loadClasificaciones()),
      ],
      child: const _CodesView(),
    );
  }
}

class _CodesView extends StatefulWidget {
  const _CodesView();

  @override
  State<_CodesView> createState() => _CodesViewState();
}

class _CodesViewState extends State<_CodesView> {
  InventoryCodesMode _mode = InventoryCodesMode.validar;

  // "Revisar CABYS" action — audits CABYS on in-stock items. Always available
  // (the whole screen is already privilege-gated in nav).
  bool _checkingCabys = false;

  // Shared column-picker selection (column id -> checked).
  final Set<String> _checked = {..._kDefaultChecked};

  // Export filters.
  // Date range is gated behind a checkbox: OFF by default → no date filter
  // (export all time). When ON, the date-range picker is revealed and its
  // range filters the export.
  bool _filterByFecha = false;
  DateTime? _startDate;
  DateTime? _endDate;
  // Clasificación filter, driven by the Clasificación column chip in the picker.
  // Empty = "Todas" (no filter → export everything). Cleared when the
  // Clasificación column is unchecked.
  final Set<String> _selectedClasificaciones = {};
  final _dateFmt = DateFormat('dd/MM/yyyy');

  bool _has(String privilege) {
    final state = context.read<AuthCubit>().state;
    return state is AuthAuthenticated && state.hasPrivilege(privilege);
  }

  bool get _ticaChecked => _checked.contains('tica');

  List<InventoryColumn> get _selectedColumns =>
      kInventoryColumns.where((c) => _checked.contains(c.id)).toList();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final canExport = _has('generate_inventory');

    // If somehow stuck on a now-disallowed mode, bounce back.
    if (_mode == InventoryCodesMode.exportar && !canExport) {
      _mode = InventoryCodesMode.validar;
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Códigos e inventario', style: textTheme.headlineSmall),
          const SizedBox(height: 16),
          Row(
            children: [
              SegmentedButton<InventoryCodesMode>(
                segments: [
                  const ButtonSegment(
                    value: InventoryCodesMode.validar,
                    label: Text('Validar'),
                    icon: Icon(Icons.fact_check_outlined, size: 18),
                  ),
                  const ButtonSegment(
                    value: InventoryCodesMode.enriquecer,
                    label: Text('Completar'),
                    icon: Icon(Icons.auto_awesome_outlined, size: 18),
                  ),
                  if (canExport)
                    const ButtonSegment(
                      value: InventoryCodesMode.exportar,
                      label: Text('Exportar'),
                      icon: Icon(Icons.download_outlined, size: 18),
                    ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: _checkingCabys ? null : _runCabysCheck,
                icon: _checkingCabys
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.fact_check_outlined, size: 18),
                label: const Text('Revisar CABYS'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(child: _buildMode(canExport)),
        ],
      ),
    );
  }

  Widget _buildMode(bool canExport) {
    switch (_mode) {
      case InventoryCodesMode.validar:
        return const _ValidarPane();
      case InventoryCodesMode.enriquecer:
        return _EnriquecerPane(
          checked: _checked,
          onToggle: _toggleColumn,
          ticaChecked: _ticaChecked,
          selectedColumns: _selectedColumns,
        );
      case InventoryCodesMode.exportar:
        if (!canExport) return const SizedBox.shrink();
        return _ExportarPane(
          checked: _checked,
          onToggle: _toggleColumn,
          ticaChecked: _ticaChecked,
          selectedColumns: _selectedColumns,
          filterByFecha: _filterByFecha,
          onToggleFilterByFecha: _toggleFilterByFecha,
          startDate: _startDate,
          endDate: _endDate,
          dateFmt: _dateFmt,
          onPickRange: _pickRange,
          onClearRange: _clearRange,
          selectedClasificaciones: _selectedClasificaciones,
          onToggleClasificacion: _toggleClasificacion,
        );
    }
  }

  void _toggleColumn(String id, bool checked) {
    setState(() {
      if (checked) {
        _checked.add(id);
      } else {
        _checked.remove(id);
        // Turning the Clasificación column off clears its filter selection.
        if (id == 'clasificacion') _selectedClasificaciones.clear();
      }
    });
  }

  void _toggleClasificacion(String pk, bool selected) {
    setState(() {
      if (selected) {
        _selectedClasificaciones.add(pk);
      } else {
        _selectedClasificaciones.remove(pk);
      }
    });
  }

  void _toggleFilterByFecha(bool enabled) {
    setState(() {
      _filterByFecha = enabled;
      // On first enable, seed a sensible default range (1st-of-month → today)
      // that the user can change. Disabling keeps the dates (we simply stop
      // sending them) so re-checking restores the prior range.
      if (enabled && _startDate == null && _endDate == null) {
        final now = DateTime.now();
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month, now.day);
      }
    });
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: (_startDate != null && _endDate != null)
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _clearRange() => setState(() {
        _startDate = null;
        _endDate = null;
      });

  Future<void> _runCabysCheck() async {
    setState(() => _checkingCabys = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await sl<InventoryService>().checkCabys();
      final map = (res is Map) ? res : <String, dynamic>{};
      final total = (map['totalChecked'] as num?)?.toInt() ?? 0;
      final bad = (map['badCount'] as num?)?.toInt() ?? 0;
      final items = ((map['items'] as List?) ?? const [])
          .whereType<Map>()
          .map(_CabysBadItem.fromMap)
          .toList();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _CabysResultDialog(
          totalChecked: total,
          badCount: bad,
          items: items,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo revisar CABYS: $e')),
      );
    } finally {
      if (mounted) setState(() => _checkingCabys = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Revisar CABYS — model + result dialog
// ---------------------------------------------------------------------------

class _CabysBadItem {
  final String codigo;
  final String codigoBarras;
  final String descripcion;
  final String modelo;
  final String cabys;
  final String motivo;

  const _CabysBadItem({
    required this.codigo,
    required this.codigoBarras,
    required this.descripcion,
    required this.modelo,
    required this.cabys,
    required this.motivo,
  });

  factory _CabysBadItem.fromMap(Map m) {
    String s(dynamic v) => v?.toString() ?? '';
    return _CabysBadItem(
      codigo: s(m['Codigo']),
      codigoBarras: s(m['Codigo_Barras']),
      descripcion: s(m['Descripcion']),
      modelo: s(m['Modelo']),
      cabys: s(m['Cabys']),
      motivo: s(m['Motivo']),
    );
  }
}

class _CabysResultDialog extends StatelessWidget {
  final int totalChecked;
  final int badCount;
  final List<_CabysBadItem> items;

  const _CabysResultDialog({
    required this.totalChecked,
    required this.badCount,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ok = badCount == 0;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_outline : Icons.warning_amber_outlined,
            color: ok ? const Color(0xFF1B5E2A) : const Color(0xFF8A5A00),
          ),
          const SizedBox(width: 10),
          const Text('Revisar CABYS'),
        ],
      ),
      content: ok
          ? Text(
              'Todos los items disponibles tienen un CABYS válido '
              '(13 caracteres). (Revisados: $totalChecked)',
              style: textTheme.bodyMedium,
            )
          : SizedBox(
              width: 700,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$badCount de $totalChecked items disponibles tienen '
                    'CABYS faltante o inválido.',
                    style: textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: Container(
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Scrollbar(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columnSpacing: 20,
                                headingRowColor: WidgetStatePropertyAll(
                                    colorScheme.surfaceContainerLow),
                                columns: const [
                                  DataColumn(label: Text('Código')),
                                  DataColumn(label: Text('Descripción')),
                                  DataColumn(label: Text('Cabys')),
                                  DataColumn(label: Text('Motivo')),
                                ],
                                rows: [
                                  for (final it in items)
                                    DataRow(cells: [
                                      DataCell(SelectableText(it.codigo)),
                                      DataCell(SizedBox(
                                        width: 280,
                                        child: Text(it.descripcion,
                                            overflow: TextOverflow.ellipsis),
                                      )),
                                      DataCell(SelectableText(it.cabys)),
                                      DataCell(Text(it.motivo)),
                                    ]),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        if (!ok)
          TextButton.icon(
            onPressed: () => _downloadCsv(context),
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Descargar CSV'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Future<void> _downloadCsv(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dir = Platform.isMacOS
          ? '/Users/${Platform.environment['USER']}/Downloads'
          : '${Platform.environment['USERPROFILE']}\\Downloads';
      await Directory(dir).create(recursive: true);
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final path = '$dir${Platform.pathSeparator}cabys_invalidos_$ts.csv';

      const headers = <String>[
        'Codigo',
        'Codigo_Barras',
        'Descripcion',
        'Modelo',
        'Cabys',
        'Motivo',
      ];
      final buf = StringBuffer('\u{FEFF}${headers.map(_csv).join(',')}\n');
      for (final it in items) {
        buf.writeln([
          _csv(it.codigo),
          _csv(it.codigoBarras),
          _csv(it.descripcion),
          _csv(it.modelo),
          _csv(it.cabys),
          _csv(it.motivo),
        ].join(','));
      }
      await File(path).writeAsString(buf.toString());
      if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', path]);
      }
      messenger.showSnackBar(SnackBar(content: Text('Guardado: $path')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    }
  }

  static String _csv(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }
}

// ---------------------------------------------------------------------------
// Shared column picker widget
// ---------------------------------------------------------------------------

class _ColumnPicker extends StatelessWidget {
  final Set<String> checked;
  final void Function(String id, bool checked) onToggle;
  final bool ticaChecked;

  /// When non-null, the Clasificación column chip expands into an inline
  /// multi-select dropdown once checked. Only wired in Exportar mode; in
  /// Enriquecer it stays null and Clasificación is a plain column chip.
  final Set<String>? selectedClasificaciones;
  final void Function(String pk, bool selected)? onToggleClasificacion;

  /// Fecha export filter — a chip appended as the LAST item in the column Wrap,
  /// and (when on) its revealed date-range picker below the Wrap. Only wired in
  /// Exportar mode; null in Enriquecer so the Fecha chip does not render there.
  final bool? filterByFecha;
  final void Function(bool enabled)? onToggleFilterByFecha;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateFormat? dateFmt;
  final VoidCallback? onPickRange;
  final VoidCallback? onClearRange;

  const _ColumnPicker({
    required this.checked,
    required this.onToggle,
    required this.ticaChecked,
    this.selectedClasificaciones,
    this.onToggleClasificacion,
    this.filterByFecha,
    this.onToggleFilterByFecha,
    this.startDate,
    this.endDate,
    this.dateFmt,
    this.onPickRange,
    this.onClearRange,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final clasifFilterEnabled =
        selectedClasificaciones != null && onToggleClasificacion != null;
    // The Fecha export filter is only wired in Exportar mode (same as the
    // Clasificación multi-select); in Enriquecer these props stay null.
    final fechaFilterEnabled =
        filterByFecha != null && onToggleFilterByFecha != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Columnas',
            style: textTheme.labelLarge
                ?.copyWith(color: colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final col in kInventoryColumns)
              if (col.id == 'clasificacion' &&
                  clasifFilterEnabled &&
                  checked.contains(col.id))
                _ClasificacionFilterChip(
                  selected: selectedClasificaciones!,
                  onToggleSelection: onToggleClasificacion!,
                  onRemoveColumn: () => onToggle(col.id, false),
                )
              else
                FilterChip(
                  label: Text(col.label),
                  selected: checked.contains(col.id),
                  onSelected: (v) => onToggle(col.id, v),
                  avatar: col.isTica
                      ? const Icon(Icons.public, size: 16)
                      : null,
                ),
            // Fecha export filter — last chip, Exportar-only.
            if (fechaFilterEnabled)
              FilterChip(
                label: const Text('Fecha'),
                selected: filterByFecha!,
                onSelected: onToggleFilterByFecha,
                avatar: const Icon(Icons.calendar_today_outlined, size: 16),
              ),
          ],
        ),
        // Revealed date-range picker, just below the Wrap, when Fecha is on.
        if (fechaFilterEnabled && filterByFecha!) ...[
          const SizedBox(height: 12),
          _DatePickerTile(
            label: context.l10n.labelFechaInicio,
            value: (startDate != null && endDate != null)
                ? (startDate == endDate
                    ? dateFmt!.format(startDate!)
                    : '${dateFmt!.format(startDate!)} – ${dateFmt!.format(endDate!)}')
                : null,
            onTap: onPickRange!,
            onClear:
                (startDate != null || endDate != null) ? onClearRange : null,
          ),
        ],
        if (ticaChecked) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE4B5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_outlined,
                    color: Color(0xFF8A5A00), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _kTicaWarning,
                    style: textTheme.bodySmall
                        ?.copyWith(color: const Color(0xFF8A5A00)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The Clasificación column chip in its "checked" state: a compact dropdown
/// (MenuAnchor) listing **Todas** plus every clasificación as checkboxes, so
/// the user can pick 1 or many. Empty selection = Todas (no filter).
class _ClasificacionFilterChip extends StatelessWidget {
  final Set<String> selected;
  final void Function(String pk, bool selected) onToggleSelection;
  final VoidCallback onRemoveColumn;

  const _ClasificacionFilterChip({
    required this.selected,
    required this.onToggleSelection,
    required this.onRemoveColumn,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // Rebuild when the cubit (re)loads clasificaciones.
    return BlocBuilder<ExportInventoryCubit, ExportInventoryState>(
      builder: (context, _) {
        final cubit = context.read<ExportInventoryCubit>();
        final clasificaciones = cubit.clasificaciones;
        final label = selected.isEmpty
            ? 'Clasificación: Todas'
            : 'Clasificación: ${selected.length} seleccionada(s)';
        return MenuAnchor(
          menuChildren: [
            // "Todas" — clears the whole selection.
            CheckboxMenuButton(
              value: selected.isEmpty,
              onChanged: (_) {
                // Clear every currently-selected pk → back to Todas.
                for (final pk in selected.toList()) {
                  onToggleSelection(pk, false);
                }
              },
              child: const Text('Todas'),
            ),
            for (final c in clasificaciones)
              if (c['PK_Clasificacion'] != null)
                CheckboxMenuButton(
                  value: selected.contains(c['PK_Clasificacion'].toString()),
                  onChanged: (v) => onToggleSelection(
                      c['PK_Clasificacion'].toString(), v ?? false),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Text(
                      c['Descripcion']?.toString() ?? '',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
          ],
          builder: (context, controller, child) {
            return InputChip(
              showCheckmark: false,
              selected: true,
              avatar: Icon(Icons.filter_list,
                  size: 16, color: colorScheme.onSecondaryContainer),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: textTheme.bodyMedium),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, size: 18),
                ],
              ),
              // Tapping the chip body opens the multi-select menu.
              onSelected: (_) =>
                  controller.isOpen ? controller.close() : controller.open(),
              // The delete (x) unchecks the Clasificación column entirely.
              onDeleted: onRemoveColumn,
            );
          },
        );
      },
    );
  }
}

class _FileChip extends StatelessWidget {
  final String name;
  final VoidCallback? onClear;
  const _FileChip({required this.name, this.onClear});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_outlined,
              size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Text(name,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          if (onClear != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onClear,
              child: Icon(Icons.close,
                  size: 16, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: colorScheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Validar pane
// ---------------------------------------------------------------------------

class _ValidarPane extends StatelessWidget {
  const _ValidarPane();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sube un archivo CSV, TXT o XLSX con códigos de barras (primera '
          'columna). Te diremos cuáles ya existen en SITSA.',
          style: textTheme.bodyMedium
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        BlocBuilder<ValidateBarcodesCubit, ValidateBarcodesState>(
          builder: (context, state) {
            final cubit = context.read<ValidateBarcodesCubit>();
            final isLoading = state is ValidateBarcodesLoading;
            final hasFile = state.selectedFileName != null;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: isLoading ? null : cubit.pickFile,
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('Seleccionar archivo'),
                ),
                if (hasFile)
                  _FileChip(
                    name: state.selectedFileName!,
                    onClear: isLoading ? null : cubit.clearFile,
                  ),
                FilledButton.icon(
                  onPressed: (!hasFile || isLoading) ? null : cubit.validate,
                  icon: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Validar'),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Expanded(
          child: BlocBuilder<ValidateBarcodesCubit, ValidateBarcodesState>(
            builder: (context, state) => _ValidarResults(state: state),
          ),
        ),
      ],
    );
  }
}

class _ValidarResults extends StatelessWidget {
  final ValidateBarcodesState state;
  const _ValidarResults({required this.state});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (state is ValidateBarcodesInitial || state is ValidateBarcodesLoading) {
      return const SizedBox.shrink();
    }
    if (state is ValidateBarcodesFailure) {
      return _ErrorBanner((state as ValidateBarcodesFailure).error);
    }
    final s = state as ValidateBarcodesSuccess;
    final summaryColor =
        s.allFree ? const Color(0xFFD4F0DC) : const Color(0xFFFFE4B5);
    final summaryFg =
        s.allFree ? const Color(0xFF1B5E2A) : const Color(0xFF8A5A00);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: summaryColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                  s.allFree
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_outlined,
                  color: summaryFg),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.message.isNotEmpty
                          ? s.message
                          : (s.allFree
                              ? 'Todos los códigos están libres.'
                              : '${s.existingCount} código(s) ya existen.'),
                      style: textTheme.bodyMedium?.copyWith(
                          color: summaryFg, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Total revisados: ${s.total}  ·  '
                      'Existentes: ${s.existingCount}  ·  '
                      'Libres: ${s.total - s.existingCount}',
                      style: textTheme.bodySmall?.copyWith(color: summaryFg),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (s.existing.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Códigos existentes', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Expanded(child: _ExistingTable(rows: s.existing)),
        ],
      ],
    );
  }
}

class _ExistingTable extends StatelessWidget {
  final List<ExistingBarcode> rows;
  const _ExistingTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return _TableShell(
      child: DataTable(
        columnSpacing: 20,
        headingRowColor: WidgetStatePropertyAll(
            Theme.of(context).colorScheme.surfaceContainerLow),
        columns: const [
          DataColumn(label: Text('PK')),
          DataColumn(label: Text('Barras')),
          DataColumn(label: Text('Descripción')),
          DataColumn(label: Text('Modelo')),
        ],
        rows: rows
            .map((r) => DataRow(cells: [
                  DataCell(Text('${r.pkArticulo ?? ''}')),
                  DataCell(SelectableText(r.codigoBarras)),
                  DataCell(Text(r.descripcion)),
                  DataCell(Text(r.modelo)),
                ]))
            .toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Enriquecer pane
// ---------------------------------------------------------------------------

class _EnriquecerPane extends StatelessWidget {
  final Set<String> checked;
  final void Function(String, bool) onToggle;
  final bool ticaChecked;
  final List<InventoryColumn> selectedColumns;

  const _EnriquecerPane({
    required this.checked,
    required this.onToggle,
    required this.ticaChecked,
    required this.selectedColumns,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sube un archivo CSV o XLSX con códigos (primera columna). '
            'Te devolvemos las columnas seleccionadas y opcionalmente Tica.',
            style: textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          _ColumnPicker(
              checked: checked, onToggle: onToggle, ticaChecked: ticaChecked),
          const SizedBox(height: 16),
          BlocBuilder<EnrichCodesCubit, EnrichCodesState>(
            builder: (context, state) {
              final cubit = context.read<EnrichCodesCubit>();
              final isLoading = state is EnrichCodesLoading;
              final hasFile = state.selectedFileName != null;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: isLoading ? null : cubit.pickFile,
                    icon: const Icon(Icons.upload_file_outlined, size: 18),
                    label: const Text('Seleccionar archivo'),
                  ),
                  if (hasFile)
                    _FileChip(
                      name: state.selectedFileName!,
                      onClear: isLoading ? null : cubit.clearFile,
                    ),
                  FilledButton.icon(
                    onPressed: (!hasFile || isLoading)
                        ? null
                        : () {
                            // Sync the Tica checkbox into the cubit before run.
                            cubit.setTicaEnabled(ticaChecked);
                            cubit.run();
                          },
                    icon: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Completar'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          BlocBuilder<EnrichCodesCubit, EnrichCodesState>(
            builder: (context, state) {
              if (state is EnrichCodesLoading) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                );
              }
              return const SizedBox(height: 8);
            },
          ),
          BlocBuilder<EnrichCodesCubit, EnrichCodesState>(
            builder: (context, state) =>
                _EnrichResults(state: state, columns: selectedColumns),
          ),
        ],
      ),
    );
  }
}

class _EnrichResults extends StatelessWidget {
  final EnrichCodesState state;
  final List<InventoryColumn> columns;
  const _EnrichResults({required this.state, required this.columns});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (state is EnrichCodesInitial || state is EnrichCodesLoading) {
      return const SizedBox.shrink();
    }
    if (state is EnrichCodesFailure) {
      return _ErrorBanner((state as EnrichCodesFailure).error);
    }
    final s = state as EnrichCodesSuccess;
    final allFound = s.missing.isEmpty;
    final summaryColor =
        allFound ? const Color(0xFFD4F0DC) : const Color(0xFFFFE4B5);
    final summaryFg =
        allFound ? const Color(0xFF1B5E2A) : const Color(0xFF8A5A00);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: summaryColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                  allFound
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_outlined,
                  color: summaryFg),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Total: ${s.total}  ·  Encontrados: ${s.found}  ·  '
                  'Faltantes: ${s.missing.length}',
                  style: textTheme.bodyMedium?.copyWith(
                      color: summaryFg, fontWeight: FontWeight.w600),
                ),
              ),
              if (s.items.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _downloadCsv(context, s),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Descargar CSV'),
                ),
            ],
          ),
        ),
        if (s.missing.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Faltantes (${s.missing.length})', style: textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in s.missing)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFDEDE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(m,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFFB00020))),
                ),
            ],
          ),
        ],
        if (s.items.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Resultados', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 420,
            child: _EnrichTable(rows: s.items, columns: columns),
          ),
        ],
      ],
    );
  }

  Future<void> _downloadCsv(BuildContext context, EnrichCodesSuccess s) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dir = Platform.isMacOS
          ? '/Users/${Platform.environment['USER']}/Downloads'
          : '${Platform.environment['USERPROFILE']}\\Downloads';
      await Directory(dir).create(recursive: true);
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final path = '$dir${Platform.pathSeparator}completar_codigos_$ts.csv';

      // Always include the input `code`, then the checked columns.
      final headers = <String>['code', ...columns.map((c) => c.label)];
      final buf = StringBuffer('\u{FEFF}${headers.map(_csv).join(',')}\n');
      for (final r in s.items) {
        final cells = <String>[
          _csv(r.code),
          ...columns.map((c) => _csv(r.valueForKey(c.enrichKey) ?? '')),
        ];
        buf.writeln(cells.join(','));
      }
      if (s.missing.isNotEmpty) {
        buf.writeln();
        buf.writeln('faltantes');
        for (final m in s.missing) {
          buf.writeln(_csv(m));
        }
      }
      await File(path).writeAsString(buf.toString());
      if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', path]);
      }
      messenger.showSnackBar(SnackBar(content: Text('Guardado: $path')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    }
  }

  static String _csv(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }
}

class _EnrichTable extends StatelessWidget {
  final List<EnrichedRow> rows;
  final List<InventoryColumn> columns;
  const _EnrichTable({required this.rows, required this.columns});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _TableShell(
      child: DataTable(
        columnSpacing: 20,
        headingRowColor:
            WidgetStatePropertyAll(colorScheme.surfaceContainerLow),
        columns: [
          const DataColumn(label: Text('Código')),
          for (final c in columns) DataColumn(label: Text(c.label)),
        ],
        rows: [
          for (final r in rows)
            DataRow(cells: [
              DataCell(SelectableText(r.code)),
              for (final c in columns)
                DataCell(c.id == 'descripcion'
                    ? SizedBox(
                        width: 280,
                        child: Text(r.valueForKey(c.enrichKey) ?? '',
                            overflow: TextOverflow.ellipsis))
                    : Text(r.valueForKey(c.enrichKey) ?? '')),
            ]),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Exportar pane
// ---------------------------------------------------------------------------

class _ExportarPane extends StatelessWidget {
  final Set<String> checked;
  final void Function(String, bool) onToggle;
  final bool ticaChecked;
  final List<InventoryColumn> selectedColumns;
  final bool filterByFecha;
  final void Function(bool enabled) onToggleFilterByFecha;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateFormat dateFmt;
  final VoidCallback onPickRange;
  final VoidCallback onClearRange;
  final Set<String> selectedClasificaciones;
  final void Function(String pk, bool selected) onToggleClasificacion;

  const _ExportarPane({
    required this.checked,
    required this.onToggle,
    required this.ticaChecked,
    required this.selectedColumns,
    required this.filterByFecha,
    required this.onToggleFilterByFecha,
    required this.startDate,
    required this.endDate,
    required this.dateFmt,
    required this.onPickRange,
    required this.onClearRange,
    required this.selectedClasificaciones,
    required this.onToggleClasificacion,
  });

  /// The clasificación filter to send to the export call. Driven by the
  /// Clasificación column chip: only when that column is checked AND at least
  /// one specific clasificación is picked (empty = "Todas"); otherwise null →
  /// export everything.
  List<String>? get _clasificacionFilter =>
      (checked.contains('clasificacion') && selectedClasificaciones.isNotEmpty)
          ? selectedClasificaciones.toList()
          : null;

  /// Date filter to send to the export calls. Only when the Fecha checkbox is
  /// checked; otherwise null → no date filter (export all time).
  DateTime? get _startingDateFilter => filterByFecha ? startDate : null;
  DateTime? get _endingDateFilter => filterByFecha ? endDate : null;

  Future<void> _exportCsv(BuildContext context) async {
    final cubit = context.read<ExportInventoryCubit>();
    await cubit.exportSelected(
      startingDate: _startingDateFilter,
      endingDate: _endingDateFilter,
      clasificaciones: _clasificacionFilter,
      tica: ticaChecked,
      concurrency: ticaChecked ? _kTicaConcurrency : null,
      columns: [
        for (final c in selectedColumns) (label: c.label, key: c.exportKey),
      ],
    );
  }

  void _exportWithTica(BuildContext context) {
    context.read<ExportInventoryCubit>().exportWithTica(
          startingDate: _startingDateFilter,
          endingDate: _endingDateFilter,
          clasificaciones: _clasificacionFilter,
        );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The Fecha filter chip lives inside the column picker Wrap (as its
          // last chip) and reveals the date-range picker below the Wrap when on.
          // Unchecked (default) → no date filter (export all time).
          _ColumnPicker(
            checked: checked,
            onToggle: onToggle,
            ticaChecked: ticaChecked,
            selectedClasificaciones: selectedClasificaciones,
            onToggleClasificacion: onToggleClasificacion,
            filterByFecha: filterByFecha,
            onToggleFilterByFecha: onToggleFilterByFecha,
            startDate: startDate,
            endDate: endDate,
            dateFmt: dateFmt,
            onPickRange: onPickRange,
            onClearRange: onClearRange,
          ),
          const SizedBox(height: 16),
          BlocBuilder<ExportInventoryCubit, ExportInventoryState>(
            builder: (context, state) {
              final loading = state is ExportInventoryLoading;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: loading ? null : () => _exportCsv(context),
                    icon: loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.download_outlined, size: 18),
                    label: Text(context.l10n.btnExportCsv),
                  ),
                  OutlinedButton.icon(
                    onPressed: loading ? null : () => _exportWithTica(context),
                    icon: loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.merge_type_outlined, size: 18),
                    label: const Text('Exportar CSV con TICA (archivo)'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          BlocBuilder<ExportInventoryCubit, ExportInventoryState>(
            builder: (context, state) {
              if (state is ExportInventoryInitial) {
                return const SizedBox.shrink();
              }
              if (state is ExportInventoryLoading) {
                return Row(
                  children: [
                    const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 12),
                    Text(state.stage ?? context.l10n.msgDescargandoDatos,
                        style: textTheme.bodyMedium),
                  ],
                );
              }
              if (state is ExportInventorySuccess) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4F0DC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: Color(0xFF1B5E2A)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n
                                  .msgArticulosExportados(state.rowCount),
                              style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1B5E2A)),
                            ),
                            const SizedBox(height: 2),
                            SelectableText(state.filePath,
                                style: textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF1B5E2A))),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }
              if (state is ExportInventoryFailure) {
                return _ErrorBanner(state.error);
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared little widgets
// ---------------------------------------------------------------------------

class _TableShell extends StatelessWidget {
  final Widget child;
  const _TableShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DatePickerTile({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 16, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant)),
                Text(
                  value ?? context.l10n.labelSinFiltro,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: value != null
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            if (onClear != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close,
                    size: 16, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
