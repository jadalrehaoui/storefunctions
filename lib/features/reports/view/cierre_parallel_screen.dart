import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../di/service_locator.dart';
import '../../../l10n/l10n.dart';
import '../cubit/cierre_parallel_cubit.dart';
import '../utils/parallel_pdf.dart' as parallel_pdf;

class CierreParallelScreen extends StatelessWidget {
  const CierreParallelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CierreParallelCubit(sl())..generate(),
      child: const _CierreParallelView(),
    );
  }
}

class _CierreParallelView extends StatefulWidget {
  const _CierreParallelView();

  @override
  State<_CierreParallelView> createState() => _CierreParallelViewState();
}

class _CierreParallelViewState extends State<_CierreParallelView> {
  static final _displayFmt = DateFormat('MMM d, yyyy');

  Future<void> _print(ParallelDailySummary summary) async {
    try {
      final path =
          await parallel_pdf.generateAndOpenParallel(summary, summary.date);
      if (mounted && path != 'printed') {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.msgSavedAt(path))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.l10n.msgErrorDetail(e.toString()))));
      }
    }
  }

  Future<void> _pickDate() async {
    final cubit = context.read<CierreParallelCubit>();
    final picked = await showDatePicker(
      context: context,
      initialDate: cubit.date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      cubit.setDate(picked);
      cubit.generate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.navCierreParallel,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          BlocBuilder<CierreParallelCubit, CierreParallelState>(
            builder: (context, state) {
              final cubit = context.read<CierreParallelCubit>();
              return Row(
                children: [
                  _DateButton(
                    value: _displayFmt.format(cubit.date),
                    onTap: _pickDate,
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: cubit.generate,
                    icon: const Icon(Icons.play_arrow_outlined, size: 18),
                    label: Text(l10n.btnGenerate),
                  ),
                  const SizedBox(width: 12),
                  if (state is CierreParallelSuccess)
                    IconButton.outlined(
                      onPressed: () => _print(state.summary),
                      icon: const Icon(Icons.print_outlined, size: 18),
                      tooltip: l10n.btnPrint,
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Expanded(
            child: BlocBuilder<CierreParallelCubit, CierreParallelState>(
              builder: (context, state) => switch (state) {
                CierreParallelInitial() => Center(
                    child: Text(l10n.msgSelectDateGenerate)),
                CierreParallelLoading() =>
                  const Center(child: CircularProgressIndicator()),
                CierreParallelFailure(:final error) => Center(
                    child: Text(error,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))),
                CierreParallelSuccess(:final summary) =>
                  _ParallelLayout(summary: summary),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ParallelLayout extends StatelessWidget {
  final ParallelDailySummary summary;
  const _ParallelLayout({required this.summary});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final colones = NumberFormat.currency(symbol: '₡', decimalDigits: 0);
    final l10n = context.l10n;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total tile
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.labelTotalDia,
                    style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.7))),
                const SizedBox(height: 4),
                Text(colones.format(summary.totalNet),
                    style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onPrimaryContainer)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Counts row
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _Stat(
                  label: '${l10n.invoiceListTitle} (${l10n.invoiceStatusActive})',
                  value: summary.invoices.length.toString()),
              _Stat(
                  label: l10n.invoiceStatusVoided,
                  value: summary.voidedInvoices.length.toString(),
                  color: Colors.red),
              _Stat(label: 'Bruto', value: colones.format(summary.totalGross)),
              _Stat(
                  label: l10n.invoiceDiscount,
                  value: colones.format(summary.totalDiscount)),
            ],
          ),
          const SizedBox(height: 24),

          // Active invoices
          Text(l10n.invoiceListTitle,
              style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _ParallelTable(
            columns: [
              l10n.invoiceColInvoiceId,
              l10n.invoiceColClient,
              l10n.invoiceCreatedBy,
              l10n.invoiceSubtotal,
              l10n.invoiceDiscount,
              l10n.invoiceColTotal,
            ],
            flexes: const [2, 4, 3, 2, 2, 2],
            aligns: const [
              TextAlign.start,
              TextAlign.start,
              TextAlign.start,
              TextAlign.end,
              TextAlign.end,
              TextAlign.end,
            ],
            rows: summary.invoices
                .map((inv) => [
                      '#${inv.id}',
                      inv.clientName ?? '',
                      inv.createdBy ?? '',
                      colones.format(inv.subtotal),
                      colones.format(inv.discount),
                      colones.format(inv.total),
                    ])
                .toList(),
          ),
          const SizedBox(height: 24),

          // Items sold
          Text('Artículos Vendidos',
              style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _ParallelTable(
            columns: const [
              'Código',
              'Descripción',
              'Cant.',
              'Bruto',
              'Descuento',
              'Neto'
            ],
            flexes: const [2, 5, 1, 2, 2, 2],
            aligns: const [
              TextAlign.start,
              TextAlign.start,
              TextAlign.end,
              TextAlign.end,
              TextAlign.end,
              TextAlign.end,
            ],
            rows: summary.itemsSold
                .map((i) => [
                      i.sitsaCode,
                      i.description,
                      i.quantity.toStringAsFixed(0),
                      colones.format(i.gross),
                      colones.format(i.discount),
                      colones.format(i.net),
                    ])
                .toList(),
          ),

          if (summary.voidedInvoices.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(l10n.invoiceStatusVoided,
                style: textTheme.titleSmall?.copyWith(
                    color: Colors.red, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _ParallelTable(
              columns: [
                l10n.invoiceColInvoiceId,
                l10n.invoiceColClient,
                l10n.invoiceCreatedBy,
                l10n.invoiceColTotal,
              ],
              flexes: const [2, 4, 3, 2],
              aligns: const [
                TextAlign.start,
                TextAlign.start,
                TextAlign.start,
                TextAlign.end,
              ],
              rows: summary.voidedInvoices
                  .map((inv) => [
                        '#${inv.id}',
                        inv.clientName ?? '',
                        inv.createdBy ?? '',
                        colones.format(inv.total),
                      ])
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Stat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: ts.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.outline)),
        Text(value,
            style: ts.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _ParallelTable extends StatelessWidget {
  final List<String> columns;
  final List<int> flexes;
  final List<TextAlign> aligns;
  final List<List<String>> rows;

  const _ParallelTable({
    required this.columns,
    required this.flexes,
    required this.aligns,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Widget headerCell(int i) => Expanded(
          flex: flexes[i],
          child: Text(columns[i],
              style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600),
              textAlign: aligns[i]),
        );

    Widget dataCell(int col, String text) => Expanded(
          flex: flexes[col],
          child: Text(text,
              style: textTheme.bodySmall,
              textAlign: aligns[col],
              overflow: TextOverflow.ellipsis),
        );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: colorScheme.surfaceContainerLow,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: List.generate(columns.length, headerCell),
              ),
            ),
            const Divider(height: 1),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(context.l10n.invoiceNoItems,
                      style: TextStyle(color: colorScheme.outline)),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: rows.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: colorScheme.outlineVariant),
                itemBuilder: (context, i) {
                  final row = rows[i];
                  return Container(
                    color: i.isOdd
                        ? colorScheme.surfaceContainerLowest
                        : null,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Row(
                      children: List.generate(
                          row.length, (c) => dataCell(c, row[c])),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String value;
  final VoidCallback onTap;

  const _DateButton({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${context.l10n.labelDate}  ',
                style: TextStyle(
                    fontSize: 12, color: colorScheme.onSurfaceVariant)),
            Text(value,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(width: 8),
            Icon(Icons.calendar_today_outlined,
                size: 14, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
