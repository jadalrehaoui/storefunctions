import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../di/service_locator.dart';
import '../../../l10n/l10n.dart';
import '../cubit/closures_cubit.dart';

class ClosuresScreen extends StatelessWidget {
  const ClosuresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ClosuresCubit(sl())..load(),
      child: const _ClosuresView(),
    );
  }
}

class _ClosuresView extends StatelessWidget {
  const _ClosuresView();

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
                onPressed: () => context.read<ClosuresCubit>().load(),
                icon: const Icon(Icons.refresh_outlined, size: 18),
                tooltip: context.l10n.tooltipRefresh,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: BlocBuilder<ClosuresCubit, ClosuresState>(
              builder: (context, state) => switch (state) {
                ClosuresInitial() => const SizedBox.shrink(),
                ClosuresLoading() =>
                  const Center(child: CircularProgressIndicator()),
                ClosuresFailure(:final error) => Center(
                    child: Text(error,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))),
                ClosuresLoaded(:final closures) => closures.isEmpty
                    ? Center(
                        child: Text(context.l10n.msgNoClosures,
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)))
                    : _ClosuresTable(closures: closures),
              },
            ),
          ),
        ],
      ),
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
                            prevInv != null ? colones.format(prevInv) : '—',
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
