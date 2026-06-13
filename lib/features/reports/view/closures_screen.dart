import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../di/service_locator.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/utils/privilege_helpers.dart';
import '../cubit/closures_cubit.dart';
import '../cubit/closures_parallel_cubit.dart';

enum _ClosuresSource { sitsa, parallel }

class ClosuresScreen extends StatelessWidget {
  const ClosuresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ClosuresCubit(sl())..load()),
        BlocProvider(create: (_) => ClosuresParallelCubit(sl())..load()),
      ],
      child: const _ClosuresView(),
    );
  }
}

class _ClosuresView extends StatefulWidget {
  const _ClosuresView();

  @override
  State<_ClosuresView> createState() => _ClosuresViewState();
}

class _ClosuresViewState extends State<_ClosuresView> {
  _ClosuresSource _source = _ClosuresSource.sitsa;

  void _refresh() {
    switch (_source) {
      case _ClosuresSource.sitsa:
        context.read<ClosuresCubit>().load();
      case _ClosuresSource.parallel:
        context.read<ClosuresParallelCubit>().load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(context.l10n.closuresTitle,
                  style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              IconButton.outlined(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_outlined, size: 18),
                tooltip: context.l10n.tooltipRefresh,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SegmentedButton<_ClosuresSource>(
            segments: const [
              ButtonSegment(
                value: _ClosuresSource.sitsa,
                label: Text('SITSA'),
                icon: Icon(Icons.history_outlined, size: 18),
              ),
              ButtonSegment(
                value: _ClosuresSource.parallel,
                label: Text('Parallel'),
                icon: Icon(Icons.storefront_outlined, size: 18),
              ),
            ],
            selected: {_source},
            onSelectionChanged: (s) => setState(() => _source = s.first),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: switch (_source) {
              _ClosuresSource.sitsa => const _SitsaSourceView(),
              _ClosuresSource.parallel => const _ParallelSourceView(),
            },
          ),
        ],
      ),
    );
  }
}

class _SitsaSourceView extends StatelessWidget {
  const _SitsaSourceView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClosuresCubit, ClosuresState>(
      builder: (context, state) => switch (state) {
        ClosuresInitial() => const SizedBox.shrink(),
        ClosuresLoading() => const Center(child: CircularProgressIndicator()),
        ClosuresFailure(:final error) => Center(
            child: Text(error,
                style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ClosuresLoaded(:final closures) => closures.isEmpty
            ? Center(
                child: Text(context.l10n.msgNoClosures,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)))
            : _ClosuresTable(closures: closures),
      },
    );
  }
}

class _ParallelSourceView extends StatelessWidget {
  const _ParallelSourceView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClosuresParallelCubit, ClosuresParallelState>(
      builder: (context, state) => switch (state) {
        ClosuresParallelInitial() => const SizedBox.shrink(),
        ClosuresParallelLoading() =>
          const Center(child: CircularProgressIndicator()),
        ClosuresParallelFailure(:final error) => Center(
            child: Text(error,
                style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ClosuresParallelLoaded(:final closures) => closures.isEmpty
            ? Center(
                child: Text(context.l10n.msgNoClosures,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)))
            : _ClosuresParallelTable(closures: closures),
      },
    );
  }
}

class _ClosuresTable extends StatelessWidget {
  final List<Map<String, dynamic>> closures;

  const _ClosuresTable({required this.closures});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final colones = NumberFormat.currency(symbol: '₡', decimalDigits: 2);
    final dateFmt = DateFormat('MMM d, yyyy');

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(
          children: [
            // Header
            Container(
              color: colorScheme.surfaceContainerLow,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _HeaderCell(context.l10n.colFecha, flex: 2, textTheme: textTheme, colorScheme: colorScheme),
                  _HeaderCell(context.l10n.colPor, flex: 2, textTheme: textTheme, colorScheme: colorScheme),
                  _HeaderCell(context.l10n.tileBruto, flex: 2, textTheme: textTheme, colorScheme: colorScheme, align: TextAlign.end),
                  _HeaderCell(context.l10n.colVentaNeta, flex: 2, textTheme: textTheme, colorScheme: colorScheme, align: TextAlign.end),
                  _HeaderCell(context.l10n.colPctDesc, flex: 1, textTheme: textTheme, colorScheme: colorScheme, align: TextAlign.end),
                  _HeaderCell(context.l10n.colDifDepositar, flex: 2, textTheme: textTheme, colorScheme: colorScheme, align: TextAlign.end),
                  _HeaderCell(context.l10n.colInvAnterior, flex: 2, textTheme: textTheme, colorScheme: colorScheme, align: TextAlign.end),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: closures.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: colorScheme.outlineVariant),
                itemBuilder: (context, i) {
                  final c = closures[i];
                  final id = c['id']?.toString() ?? c['_id']?.toString();
                  final dateRaw = c['date'] as String?;
                  final date = dateRaw != null
                      ? dateFmt.format(DateTime.parse(dateRaw))
                      : '—';
                  final general = c['general'] as Map? ?? {};
                  final brutTotal = (general['BrutTotal'] as num?)?.toDouble();
                  final calc = c['calculations'] as Map? ?? {};
                  final ventaNeta = (calc['ventaNeta'] as num?)?.toDouble();
                  final pct = (calc['discountPct'] as num?)?.toDouble();
                  final dif = (calc['diferenciaADepositar'] as num?)?.toDouble();
                  final prevInv = num.tryParse('${c['prev_inventory_cost'] ?? ''}')?.toDouble();

                  return InkWell(
                    onTap: id != null
                        ? () => context.push('/reports/closures/$id')
                        : null,
                    child: Container(
                    color: i.isOdd
                        ? colorScheme.surfaceContainerLowest
                        : null,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(date,
                              style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            c['created_by'] as String? ?? '—',
                            style: textTheme.bodyMedium,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            brutTotal != null
                                ? colones.format(brutTotal)
                                : '—',
                            style: textTheme.bodyMedium,
                            textAlign: TextAlign.end,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            ventaNeta != null
                                ? colones.format(ventaNeta)
                                : '—',
                            style: textTheme.bodyMedium,
                            textAlign: TextAlign.end,
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            pct != null
                                ? '${NumberFormat('0.00').format(pct)}%'
                                : '—',
                            style: textTheme.bodyMedium,
                            textAlign: TextAlign.end,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            dif != null ? colones.format(dif) : '—',
                            style: textTheme.bodyMedium?.copyWith(
                              color: dif != null && dif < 0
                                  ? colorScheme.error
                                  : null,
                            ),
                            textAlign: TextAlign.end,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            prevInv != null ? (canSeeProfitMargins(context) ? colones.format(prevInv) : redacted) : '—',
                            style: textTheme.bodyMedium,
                            textAlign: TextAlign.end,
                          ),
                        ),
                        const SizedBox(width: 40),
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
    );
  }
}

class _ClosuresParallelTable extends StatelessWidget {
  final List<Map<String, dynamic>> closures;

  const _ClosuresParallelTable({required this.closures});

  static double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final colones = NumberFormat.currency(symbol: '₡', decimalDigits: 2);
    final dateFmt = DateFormat('MMM d, yyyy');

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(
          children: [
            // Header
            Container(
              color: colorScheme.surfaceContainerLow,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _HeaderCell('Fecha',
                      flex: 2,
                      textTheme: textTheme,
                      colorScheme: colorScheme),
                  _HeaderCell('Por',
                      flex: 2,
                      textTheme: textTheme,
                      colorScheme: colorScheme),
                  _HeaderCell('Facturas',
                      flex: 1,
                      textTheme: textTheme,
                      colorScheme: colorScheme,
                      align: TextAlign.end),
                  _HeaderCell('Neto',
                      flex: 2,
                      textTheme: textTheme,
                      colorScheme: colorScheme,
                      align: TextAlign.end),
                  _HeaderCell('Bruto',
                      flex: 2,
                      textTheme: textTheme,
                      colorScheme: colorScheme,
                      align: TextAlign.end),
                  _HeaderCell('Descuento',
                      flex: 2,
                      textTheme: textTheme,
                      colorScheme: colorScheme,
                      align: TextAlign.end),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: closures.length,
                itemBuilder: (context, i) {
                  final c = closures[i];
                  final dateRaw = c['date']?.toString();
                  final date = dateRaw != null
                      ? dateFmt.format(DateTime.parse(dateRaw))
                      : '—';
                  final summary = c['summary'] as Map? ?? const {};
                  final invCount = summary['active_invoices_count'] ??
                      (summary['invoices'] is List
                          ? (summary['invoices'] as List).length
                          : null);
                  final net = _num(c['total_net']);
                  final gross = _num(c['total_gross']);
                  final disc = _num(c['total_discount']);

                  return Container(
                    decoration: BoxDecoration(
                      color: i.isOdd
                          ? colorScheme.surfaceContainerLowest
                          : null,
                      border: Border(
                        top: i == 0
                            ? BorderSide.none
                            : BorderSide(color: colorScheme.outlineVariant),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(date,
                              style: textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w500)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            c['created_by']?.toString() ?? '—',
                            style: textTheme.bodyMedium,
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            invCount?.toString() ?? '—',
                            style: textTheme.bodyMedium,
                            textAlign: TextAlign.end,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            net != null ? colones.format(net) : '—',
                            style: textTheme.bodyMedium,
                            textAlign: TextAlign.end,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            gross != null ? colones.format(gross) : '—',
                            style: textTheme.bodyMedium,
                            textAlign: TextAlign.end,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            disc != null ? colones.format(disc) : '—',
                            style: textTheme.bodyMedium,
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

class _HeaderCell extends StatelessWidget {
  final String label;
  final int flex;
  final TextAlign align;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  const _HeaderCell(
    this.label, {
    required this.flex,
    required this.textTheme,
    required this.colorScheme,
    this.align = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600),
        textAlign: align,
      ),
    );
  }
}
