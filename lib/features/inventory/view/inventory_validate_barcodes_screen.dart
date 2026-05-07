import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../di/service_locator.dart';
import '../cubit/validate_barcodes_cubit.dart';

class InventoryValidateBarcodesScreen extends StatelessWidget {
  const InventoryValidateBarcodesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ValidateBarcodesCubit(sl()),
      child: const _ValidateBarcodesView(),
    );
  }
}

class _ValidateBarcodesView extends StatelessWidget {
  const _ValidateBarcodesView();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Validar Códigos', style: textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Sube un archivo CSV, TXT o XLSX con códigos de barras (primera columna). '
            'Te diremos cuáles ya existen en SITSA.',
            style: textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          BlocBuilder<ValidateBarcodesCubit, ValidateBarcodesState>(
            builder: (context, state) {
              final cubit = context.read<ValidateBarcodesCubit>();
              final isLoading = state is ValidateBarcodesLoading;
              final hasFile = state.selectedFileName != null;

              return Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: isLoading ? null : cubit.pickFile,
                    icon: const Icon(Icons.upload_file_outlined, size: 18),
                    label: const Text('Seleccionar archivo'),
                  ),
                  const SizedBox(width: 12),
                  if (hasFile) ...[
                    Flexible(
                      child: _FileChip(
                        name: state.selectedFileName!,
                        onClear: isLoading ? null : cubit.clearFile,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  FilledButton.icon(
                    onPressed:
                        (!hasFile || isLoading) ? null : cubit.validate,
                    icon: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Validar'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Expanded(
            child: BlocBuilder<ValidateBarcodesCubit, ValidateBarcodesState>(
              builder: (context, state) => _ResultArea(state: state),
            ),
          ),
        ],
      ),
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
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
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

class _ResultArea extends StatelessWidget {
  final ValidateBarcodesState state;
  const _ResultArea({required this.state});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    if (state is ValidateBarcodesInitial || state is ValidateBarcodesLoading) {
      return const SizedBox.shrink();
    }

    if (state is ValidateBarcodesFailure) {
      final s = state as ValidateBarcodesFailure;
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
              child: Text(
                s.error,
                style: textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      );
    }

    final s = state as ValidateBarcodesSuccess;
    final summaryColor =
        s.allFree ? const Color(0xFFD4F0DC) : const Color(0xFFFFE4B5);
    final summaryFg =
        s.allFree ? const Color(0xFF1B5E2A) : const Color(0xFF8A5A00);
    final summaryIcon = s.allFree
        ? Icons.check_circle_outline
        : Icons.warning_amber_outlined;

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
              Icon(summaryIcon, color: summaryFg),
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
                        color: summaryFg,
                        fontWeight: FontWeight.w600,
                      ),
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
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('PK')),
                  DataColumn(label: Text('Código de Barras')),
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
            ),
          ),
        ),
      ),
    );
  }
}
