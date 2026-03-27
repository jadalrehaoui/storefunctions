import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../di/service_locator.dart';
import '../cubit/export_inventory_cubit.dart';

class InventoryExportScreen extends StatelessWidget {
  const InventoryExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ExportInventoryCubit(sl()),
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

  final _dateFmt = DateFormat('dd/MM/yyyy');

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  void _export() {
    context.read<ExportInventoryCubit>().export(
          startingDate: _startDate,
          endingDate: _endDate,
        );
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
          Text('Exportar inventario', style: textTheme.headlineSmall),
          const SizedBox(height: 24),

          // Date pickers row
          Row(
            children: [
              _DatePickerTile(
                label: 'Fecha inicio',
                value: _startDate != null ? _dateFmt.format(_startDate!) : null,
                onTap: _pickStart,
                onClear: _startDate != null
                    ? () => setState(() => _startDate = null)
                    : null,
              ),
              const SizedBox(width: 16),
              _DatePickerTile(
                label: 'Fecha fin',
                value: _endDate != null ? _dateFmt.format(_endDate!) : null,
                onTap: _pickEnd,
                onClear: _endDate != null
                    ? () => setState(() => _endDate = null)
                    : null,
              ),
              const SizedBox(width: 24),
              BlocBuilder<ExportInventoryCubit, ExportInventoryState>(
                builder: (context, state) => FilledButton.icon(
                  onPressed:
                      state is ExportInventoryLoading ? null : _export,
                  icon: state is ExportInventoryLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Exportar CSV'),
                ),
              ),
            ],
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
                    Text('Descargando datos...',
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
                              '${state.rowCount} artículos exportados',
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
                  value ?? 'Sin filtro',
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
