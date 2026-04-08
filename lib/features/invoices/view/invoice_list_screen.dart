import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../di/service_locator.dart';
import '../../../l10n/l10n.dart';
import '../../../services/invoice_service.dart';
import '../../../services/receipt_printer_service.dart';
import '../../../shared/utils/privilege_helpers.dart';
import '../cubit/invoice_list_cubit.dart';
import '../model/invoice_models.dart';
import '../utils/receipt_pdf.dart' as receipt_pdf;

final _money = NumberFormat.currency(symbol: '₡', decimalDigits: 2);
final _dateFmt = DateFormat('yyyy-MM-dd');

class InvoiceListScreen extends StatelessWidget {
  const InvoiceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InvoiceListCubit(sl())..generate(),
      child: const _InvoiceListView(),
    );
  }
}

class _InvoiceListView extends StatefulWidget {
  const _InvoiceListView();

  @override
  State<_InvoiceListView> createState() => _InvoiceListViewState();
}

class _InvoiceListViewState extends State<_InvoiceListView> {
  final _clientCtrl = TextEditingController();
  late DateTimeRange _range;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    _range = DateTimeRange(start: start, end: start);
  }

  @override
  void dispose() {
    _clientCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.invoiceListTitle),
        actions: [
          if (canCreateInvoice(context))
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: () => context.go('/invoices/new'),
                icon: const Icon(Icons.add),
                label: Text(l10n.invoiceCreateTitle),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FilterBar(
              clientCtrl: _clientCtrl,
              range: _range,
              onPickStart: () async {
                final cubit = context.read<InvoiceListCubit>();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _range.start,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  final newEnd = picked.isAfter(_range.end) ? picked : _range.end;
                  setState(() =>
                      _range = DateTimeRange(start: picked, end: newEnd));
                  cubit.setDateRange(picked, newEnd);
                }
              },
              onPickEnd: () async {
                final cubit = context.read<InvoiceListCubit>();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _range.end,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  final newStart =
                      picked.isBefore(_range.start) ? picked : _range.start;
                  setState(() =>
                      _range = DateTimeRange(start: newStart, end: picked));
                  cubit.setDateRange(newStart, picked);
                }
              },
              onClientChanged: (v) =>
                  context.read<InvoiceListCubit>().setClientFilter(v),
              onGenerate: () => context.read<InvoiceListCubit>().generate(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: BlocBuilder<InvoiceListCubit, InvoiceListState>(
                builder: (context, state) {
                  if (state is InvoiceListLoading ||
                      state is InvoiceListInitial) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is InvoiceListFailure) {
                    return Center(
                      child: Text(state.error,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    );
                  }
                  final invoices = (state as InvoiceListSuccess).invoices;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _InvoiceTable(invoices: invoices)),
                      const SizedBox(width: 16),
                      _SummaryPanel(invoices: invoices),
                    ],
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

class _FilterBar extends StatelessWidget {
  final TextEditingController clientCtrl;
  final DateTimeRange range;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final ValueChanged<String> onClientChanged;
  final VoidCallback onGenerate;
  const _FilterBar({
    required this.clientCtrl,
    required this.range,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onClientChanged,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: onPickStart,
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text(_dateFmt.format(range.start)),
        ),
        const SizedBox(width: 8),
        const Text('→'),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: onPickEnd,
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text(_dateFmt.format(range.end)),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 260,
          child: TextField(
            controller: clientCtrl,
            decoration: InputDecoration(
              labelText: l10n.invoiceFilterClient,
              border: const OutlineInputBorder(),
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 18),
            ),
            onSubmitted: onClientChanged,
          ),
        ),
        const SizedBox(width: 16),
        FilledButton.icon(
          onPressed: onGenerate,
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(l10n.btnGenerate),
        ),
      ],
    );
  }
}

class _InvoiceTable extends StatelessWidget {
  final List<InvoiceSummary> invoices;
  const _InvoiceTable({required this.invoices});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: [
            DataColumn(label: Text(l10n.invoiceColInvoiceId)),
            DataColumn(label: Text(l10n.invoiceDate)),
            DataColumn(label: Text(l10n.invoiceColClient)),
            DataColumn(label: Text(l10n.invoiceCreatedBy)),
            DataColumn(label: Text(l10n.invoiceColTotal)),
            DataColumn(label: Text(l10n.invoiceColStatus)),
            DataColumn(label: Text(l10n.invoiceColActions)),
          ],
          rows: [
            for (final inv in invoices)
              DataRow(cells: [
                DataCell(Text('#${inv.id}')),
                DataCell(Text(_dateFmt.format(inv.date))),
                DataCell(Text(inv.clientName ?? '')),
                DataCell(Text(inv.createdBy ?? '')),
                DataCell(Text(_money.format(inv.total))),
                DataCell(_StatusBadge(status: inv.status)),
                DataCell(_RowActions(invoice: inv)),
              ]),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isActive = status == 'active';
    final color = isActive ? Colors.green : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        isActive ? l10n.invoiceStatusActive : l10n.invoiceStatusVoided,
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  final List<InvoiceSummary> invoices;
  const _SummaryPanel({required this.invoices});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final active = invoices.where((i) => i.isActive).toList();
    final voided = invoices.where((i) => !i.isActive).length;
    final totalSum = active.fold<double>(0, (s, i) => s + i.total);
    final ts = Theme.of(context).textTheme;

    Widget row(String label, String value, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: ts.bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.outline)),
              const SizedBox(height: 2),
              Text(value,
                  style: ts.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  )),
            ],
          ),
        );

    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.invoiceListTitle,
                style: ts.titleSmall
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
              const Divider(),
              row('${l10n.invoiceListTitle} (${l10n.invoiceStatusActive})',
                  active.length.toString()),
              row(l10n.invoiceTotal, _money.format(totalSum)),
              row(l10n.invoiceStatusVoided, voided.toString(),
                  color: Colors.red),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowActions extends StatelessWidget {
  final InvoiceSummary invoice;
  const _RowActions({required this.invoice});

  Future<void> _reprint(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final raw = await sl<InvoiceService>().getInvoice(invoice.id);
      final map = (raw is Map && raw['data'] is Map)
          ? raw['data'] as Map<String, dynamic>
          : (raw as Map<String, dynamic>);
      final detail = InvoiceDetail.fromJson(map);
      final bytes = await receipt_pdf.buildReceiptPdf(
        invoiceId: detail.id,
        date: detail.date,
        clientName: detail.clientName ?? '',
        clientId: detail.clientId ?? '',
        notes: detail.notes ?? '',
        items: detail.items,
        createdBy: detail.createdBy,
      );
      final printed = await sl<ReceiptPrinterService>()
          .printPdf(bytes, name: 'invoice_${detail.id}');
      if (!printed) {
        await receipt_pdf.openReceiptPdf(bytes, detail.id);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Reprint error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: () => context.go('/invoices/${invoice.id}'),
          child: Text(l10n.invoiceView),
        ),
        if (canReprintInvoice(context))
          IconButton(
            icon: const Icon(Icons.print_outlined, size: 18),
            tooltip: 'Reimprimir',
            onPressed: () => _reprint(context),
          ),
        if (invoice.isActive && canEditInvoice(context))
          TextButton(
            onPressed: () => context.go('/invoices/${invoice.id}/edit'),
            child: Text(l10n.invoiceEdit),
          ),
        if (invoice.isActive && canVoidInvoice(context))
          TextButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (dialogCtx) => AlertDialog(
                  title: Text(l10n.invoiceVoidConfirmTitle),
                  content: Text(l10n.invoiceVoidConfirmBody),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogCtx, false),
                      child: Text(MaterialLocalizations.of(dialogCtx)
                          .cancelButtonLabel),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor:
                              Theme.of(dialogCtx).colorScheme.error),
                      onPressed: () => Navigator.pop(dialogCtx, true),
                      child: Text(l10n.invoiceVoid),
                    ),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await context.read<InvoiceListCubit>().voidInvoice(invoice.id);
              }
            },
            child: Text(l10n.invoiceVoid,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
      ],
    );
  }
}
