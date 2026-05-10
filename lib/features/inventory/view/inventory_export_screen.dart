import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../di/service_locator.dart';
import '../../../l10n/l10n.dart';
import '../cubit/export_inventory_cubit.dart';

class InventoryExportScreen extends StatelessWidget {
  const InventoryExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ExportInventoryCubit(sl())..loadClasificaciones(),
      child: const _ExportView(),
    );
  }
}

class _ExportView extends StatefulWidget {
  const _ExportView();

  @override
  State<_ExportView> createState() => _ExportViewState();
}

class _ExportViewState extends State<_ExportView> {
  DateTime? _startDate;
  DateTime? _endDate;
  final List<String> _clasificaciones = [];

  final _dateFmt = DateFormat('dd/MM/yyyy');

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

  void _export() {
    context.read<ExportInventoryCubit>().export(
          startingDate: _startDate,
          endingDate: _endDate,
          clasificaciones: _clasificaciones.isEmpty ? null : _clasificaciones,
        );
  }

  void _exportWithTica() {
    context.read<ExportInventoryCubit>().exportWithTica(
          startingDate: _startDate,
          endingDate: _endDate,
          clasificaciones: _clasificaciones.isEmpty ? null : _clasificaciones,
        );
  }

  Future<void> _addClasificacion() async {
    final cubit = context.read<ExportInventoryCubit>();
    final available = cubit.clasificaciones.where((c) {
      final id = c['PK_Clasificacion']?.toString();
      return id != null && !_clasificaciones.contains(id);
    }).toList();
    if (available.isEmpty) return;

    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(context.l10n.labelClasificacion),
        children: [
          for (final c in available)
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.pop(ctx, c['PK_Clasificacion']?.toString()),
              child: Text(c['Descripcion']?.toString() ?? ''),
            ),
        ],
      ),
    );
    if (picked != null) {
      setState(() => _clasificaciones.add(picked));
    }
  }

  String _clasificacionLabel(String id) {
    final cubit = context.read<ExportInventoryCubit>();
    final match = cubit.clasificaciones.firstWhere(
      (c) => c['PK_Clasificacion']?.toString() == id,
      orElse: () => <String, dynamic>{},
    );
    return match['Descripcion']?.toString() ?? id;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.navExportInventory, style: textTheme.headlineSmall),
          const SizedBox(height: 24),

          // Date range + filters row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DatePickerTile(
                label: context.l10n.labelFechaInicio,
                value: (_startDate != null && _endDate != null)
                    ? (_startDate == _endDate
                        ? _dateFmt.format(_startDate!)
                        : '${_dateFmt.format(_startDate!)} – ${_dateFmt.format(_endDate!)}')
                    : null,
                onTap: _pickRange,
                onClear: (_startDate != null || _endDate != null)
                    ? _clearRange
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: BlocBuilder<ExportInventoryCubit, ExportInventoryState>(
                  builder: (context, _) {
                    final cubit = context.read<ExportInventoryCubit>();
                    final allSelected = _clasificaciones.length >=
                        cubit.clasificaciones.length;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.labelClasificacion,
                          style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (_clasificaciones.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Text(
                                  context.l10n.labelTodas,
                                  style: textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant),
                                ),
                              ),
                            for (final id in _clasificaciones)
                              InputChip(
                                label: Text(_clasificacionLabel(id)),
                                onDeleted: () => setState(
                                    () => _clasificaciones.remove(id)),
                              ),
                            OutlinedButton.icon(
                              onPressed:
                                  allSelected ? null : _addClasificacion,
                              icon: const Icon(Icons.add, size: 18),
                              label: Text(context.l10n.btnAdd),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
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
                    onPressed: loading ? null : _export,
                    icon: loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.download_outlined, size: 18),
                    label: Text(context.l10n.btnExportCsv),
                  ),
                  OutlinedButton.icon(
                    onPressed: loading ? null : _exportWithTica,
                    icon: loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.merge_type_outlined, size: 18),
                    label: const Text('Exportar CSV con TICA'),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 32),

          // Status
          BlocBuilder<ExportInventoryCubit, ExportInventoryState>(
            builder: (context, state) {
              if (state is ExportInventoryInitial) return const SizedBox.shrink();

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
                              context.l10n.msgArticulosExportados(state.rowCount),
                              style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1B5E2A)),
                            ),
                            const SizedBox(height: 2),
                            SelectableText(
                              state.filePath,
                              style: textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF1B5E2A)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (state is ExportInventoryFailure) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: colorScheme.onErrorContainer),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          state.error,
                          style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ],
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
