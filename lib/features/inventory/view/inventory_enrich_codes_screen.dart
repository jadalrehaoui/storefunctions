import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../di/service_locator.dart';
import '../cubit/enrich_codes_cubit.dart';

class InventoryEnrichCodesScreen extends StatelessWidget {
  const InventoryEnrichCodesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => EnrichCodesCubit(sl()),
      child: const _EnrichCodesView(),
    );
  }
}

class _EnrichCodesView extends StatelessWidget {
  const _EnrichCodesView();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Enriquecer Códigos', style: textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Sube un archivo CSV o XLSX con códigos (primera columna). '
            'Te devolvemos descripción, modelo, qty y opcionalmente TICA.',
            style: textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('TICA'),
                      const SizedBox(width: 6),
                      Switch(
                        value: state.ticaEnabled,
                        onChanged:
                            isLoading ? null : (v) => cubit.setTicaEnabled(v),
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: (!hasFile || isLoading) ? null : cubit.run,
                    icon: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Enriquecer'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          if (!_isLoadingState(context))
            const SizedBox.shrink()
          else
            const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 8),
          Expanded(
            child: BlocBuilder<EnrichCodesCubit, EnrichCodesState>(
              builder: (context, state) => _ResultArea(state: state),
            ),
          ),
        ],
      ),
    );
  }

  bool _isLoadingState(BuildContext context) {
    return context.watch<EnrichCodesCubit>().state is EnrichCodesLoading;
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
  final EnrichCodesState state;
  const _ResultArea({required this.state});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    if (state is EnrichCodesInitial || state is EnrichCodesLoading) {
      return const SizedBox.shrink();
    }
    if (state is EnrichCodesFailure) {
      final s = state as EnrichCodesFailure;
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
                color: summaryFg,
              ),
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
        const SizedBox(height: 16),
        if (s.items.isNotEmpty) ...[
          Text('Resultados', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Expanded(
            child: _ResultsTable(rows: s.items, ticaEnabled: s.ticaEnabled),
          ),
        ],
      ],
    );
  }

  Future<void> _downloadCsv(
      BuildContext context, EnrichCodesSuccess s) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dir = Platform.isMacOS
          ? '/Users/${Platform.environment['USER']}/Downloads'
          : '${Platform.environment['USERPROFILE']}\\Downloads';
      await Directory(dir).create(recursive: true);
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final path =
          '$dir${Platform.pathSeparator}enriquecer_codigos_$ts.csv';
      final buf = StringBuffer(
          '\u{FEFF}code,sitsa_code,barcode,descripcion,modelo,qty,tica\n');
      for (final r in s.items) {
        buf.writeln([
          _csv(r.code),
          _csv(r.sitsaCode ?? ''),
          _csv(r.barcode ?? ''),
          _csv(r.descripcion ?? ''),
          _csv(r.modelo ?? ''),
          _csv(r.qty?.toString() ?? ''),
          _csv(r.tica ?? ''),
        ].join(','));
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

class _ResultsTable extends StatelessWidget {
  final List<EnrichedRow> rows;
  final bool ticaEnabled;
  const _ResultsTable({required this.rows, required this.ticaEnabled});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
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
                headingRowColor:
                    WidgetStatePropertyAll(colorScheme.surfaceContainerLow),
                columns: [
                  const DataColumn(label: Text('Código')),
                  const DataColumn(label: Text('Sitsa')),
                  const DataColumn(label: Text('Barras')),
                  const DataColumn(label: Text('Descripción')),
                  const DataColumn(label: Text('Modelo')),
                  const DataColumn(label: Text('Qty'), numeric: true),
                  if (ticaEnabled) const DataColumn(label: Text('TICA')),
                ],
                rows: [
                  for (final r in rows)
                    DataRow(cells: [
                      DataCell(SelectableText(r.code)),
                      DataCell(Text(r.sitsaCode ?? '')),
                      DataCell(Text(r.barcode ?? '')),
                      DataCell(SizedBox(
                        width: 280,
                        child: Text(
                          r.descripcion ?? '',
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                      DataCell(Text(r.modelo ?? '')),
                      DataCell(Text('${r.qty ?? ''}')),
                      if (ticaEnabled) DataCell(Text(r.tica ?? '')),
                    ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
