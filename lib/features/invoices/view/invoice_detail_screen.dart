import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../di/service_locator.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/utils/privilege_helpers.dart';
import '../cubit/invoice_detail_cubit.dart';
import '../model/invoice_models.dart';

final _money = NumberFormat.currency(symbol: '₡', decimalDigits: 2);
final _dateFmt = DateFormat('yyyy-MM-dd');
final _dateTimeFmt = DateFormat('yyyy-MM-dd HH:mm');

class InvoiceDetailScreen extends StatelessWidget {
  final String invoiceId;
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InvoiceDetailCubit(sl(), invoiceId)..load(),
      child: const _InvoiceDetailView(),
    );
  }
}

class _InvoiceDetailView extends StatelessWidget {
  const _InvoiceDetailView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.invoiceDetailTitle)),
      body: BlocBuilder<InvoiceDetailCubit, InvoiceDetailState>(
        builder: (context, state) {
          if (state is InvoiceDetailLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is InvoiceDetailFailure) {
            return Center(
              child: Text(state.error,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
            );
          }
          final invoice = (state as InvoiceDetailSuccess).invoice;
          return _DetailBody(invoice: invoice);
        },
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final InvoiceDetail invoice;
  const _DetailBody({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(invoice: invoice),
          const SizedBox(height: 16),
          Expanded(child: _ItemsTable(items: invoice.items)),
          const Divider(),
          _Totals(invoice: invoice),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (invoice.isActive && canEditInvoice(context))
                FilledButton.icon(
                  onPressed: () =>
                      context.go('/invoices/${invoice.id}/edit'),
                  icon: const Icon(Icons.edit),
                  label: Text(l10n.invoiceEdit),
                ),
              const SizedBox(width: 8),
              if (invoice.isActive && canVoidInvoice(context))
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error),
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
                      await context
                          .read<InvoiceDetailCubit>()
                          .voidInvoice();
                    }
                  },
                  icon: const Icon(Icons.block),
                  label: Text(l10n.invoiceVoid),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final InvoiceDetail invoice;
  const _Header({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ts = Theme.of(context).textTheme;

    Widget kv(String k, String? v) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              SizedBox(
                width: 140,
                child: Text(k,
                    style: ts.bodySmall?.copyWith(color: Colors.grey)),
              ),
              Expanded(child: Text(v ?? '-')),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('#${invoice.id}', style: ts.titleLarge),
                const SizedBox(width: 12),
                _StatusChip(status: invoice.status),
              ],
            ),
            const SizedBox(height: 8),
            kv(l10n.invoiceDate, _dateFmt.format(invoice.date)),
            kv(l10n.invoiceClientName, invoice.clientName),
            kv(l10n.invoiceClientId, invoice.clientId),
            kv(l10n.invoiceNotes, invoice.notes),
            kv(l10n.invoiceCreatedBy, invoice.createdBy),
            kv(
                l10n.invoiceCreatedAt,
                invoice.createdAt != null
                    ? _dateTimeFmt.format(invoice.createdAt!)
                    : null),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

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

class _ItemsTable extends StatelessWidget {
  final List<InvoiceLineItem> items;
  const _ItemsTable({required this.items});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: [
            DataColumn(label: Text(l10n.invoiceDescription)),
            DataColumn(label: Text(l10n.invoiceCode)),
            DataColumn(label: Text(l10n.invoiceBarcode)),
            DataColumn(label: Text(l10n.invoiceQty)),
            DataColumn(label: Text(l10n.invoiceUnitPrice)),
            DataColumn(label: Text(l10n.invoiceDiscountPct)),
            DataColumn(label: Text(l10n.invoiceLineTotal)),
          ],
          rows: [
            for (final i in items)
              DataRow(cells: [
                DataCell(SizedBox(width: 220, child: Text(i.description))),
                DataCell(Text(i.sitsaCode)),
                DataCell(Text(i.barcode ?? '')),
                DataCell(Text(i.quantity.toString())),
                DataCell(Text(_money.format(i.unitPrice))),
                DataCell(Text('${i.discountPct}%')),
                DataCell(Text(_money.format(i.lineTotal))),
              ]),
          ],
        ),
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  final InvoiceDetail invoice;
  const _Totals({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ts = Theme.of(context).textTheme;
    Widget row(String k, String v, TextStyle s) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(k, style: s),
              const SizedBox(width: 16),
              SizedBox(
                width: 140,
                child: Text(v, style: s, textAlign: TextAlign.right),
              ),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        row(l10n.invoiceSubtotal, _money.format(invoice.subtotal),
            ts.bodyMedium!),
        row(l10n.invoiceDiscount, _money.format(invoice.discountAmount),
            ts.bodyMedium!),
        const Divider(),
        row(l10n.invoiceTotal, _money.format(invoice.total),
            ts.titleMedium!.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
