import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../di/service_locator.dart';
import '../cubit/sales_by_codes_cubit.dart';

class InventorySalesByCodesScreen extends StatelessWidget {
  const InventorySalesByCodesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SalesByCodesCubit(sl()),
      child: const SalesByCodesView(),
    );
  }
}

/// The Ventas-por-códigos body. Reads [SalesByCodesCubit] from context, so the
/// caller must provide it (either via [InventorySalesByCodesScreen] above or the
/// unified Exportar ventas screen). Renders no screen title — the host supplies it.
class SalesByCodesView extends StatelessWidget {
  const SalesByCodesView({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sube un CSV con códigos de barras (primera columna). '
            'Generaremos un CSV nuevo con columnas adicionales: '
            'Vendido_SITSA, Vendido_Mikail y Vendido_Parallel.',
            style: textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          BlocBuilder<SalesByCodesCubit, SalesByCodesState>(
            builder: (context, state) {
              final cubit = context.read<SalesByCodesCubit>();
              final isRunning = state is SalesByCodesRunning;
              final hasFile = state.selectedFileName != null;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: isRunning ? null : cubit.pickFile,
                    icon: const Icon(Icons.upload_file_outlined, size: 18),
                    label: const Text('Seleccionar archivo'),
                  ),
                  if (hasFile)
                    _FileChip(
                      name: state.selectedFileName!,
                      onClear: isRunning ? null : cubit.clearFile,
                    ),
                  FilledButton.icon(
                    onPressed: (!hasFile || isRunning) ? null : cubit.run,
                    icon: isRunning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Generar CSV'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Expanded(
            child: BlocBuilder<SalesByCodesCubit, SalesByCodesState>(
              builder: (context, state) => _StatusArea(state: state),
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
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
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

class _StatusArea extends StatelessWidget {
  final SalesByCodesState state;
  const _StatusArea({required this.state});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    if (state is SalesByCodesInitial) return const SizedBox.shrink();

    if (state is SalesByCodesRunning) {
      final s = state as SalesByCodesRunning;
      final pct = s.total == 0 ? 0.0 : s.processed / s.total;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Procesando ${s.processed} de ${s.total}...',
              style: textTheme.bodyMedium),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: LinearProgressIndicator(value: pct),
          ),
        ],
      );
    }

    if (state is SalesByCodesSuccess) {
      final s = state as SalesByCodesSuccess;
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
                    '${s.rowCount} filas procesadas'
                    '${s.notFoundCount > 0 ? ' · ${s.notFoundCount} sin datos' : ''}',
                    style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1B5E2A)),
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    s.filePath,
                    style: textTheme.bodySmall
                        ?.copyWith(color: const Color(0xFF1B5E2A)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (state is SalesByCodesFailure) {
      final s = state as SalesByCodesFailure;
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

    return const SizedBox.shrink();
  }
}
