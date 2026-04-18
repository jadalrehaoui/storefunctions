import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../di/service_locator.dart';
import '../../../services/receipt_printer_service.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../billing/utils/cierre_personal_receipt_pdf.dart';
import '../../reports/view/cierre_sitsa_screen.dart' show CardChargeEntry;
import '../cubit/cierres_personales_cubit.dart';

class CierrePersonalDetailScreen extends StatelessWidget {
  final String id;
  const CierrePersonalDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CierrePersonalDetailCubit(sl(), id)..load(),
      child: const _View(),
    );
  }
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cierre Personal'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocBuilder<CierrePersonalDetailCubit, CierrePersonalDetailState>(
        builder: (context, state) => switch (state) {
          CierrePersonalDetailLoading() =>
            const Center(child: CircularProgressIndicator()),
          CierrePersonalDetailFailure(:final error) => Center(
              child: Text(error,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error))),
          CierrePersonalDetailLoaded(:final item) => _Content(item: item),
        },
      ),
    );
  }
}

class _Content extends StatelessWidget {
  final Map<String, dynamic> item;
  const _Content({required this.item});

  Future<void> _print(BuildContext context) async {
    final dateRaw = item['date'] as String?;
    final date =
        dateRaw != null ? DateTime.parse(dateRaw) : DateTime.now();
    final cashier = '${item['usuario'] ?? ''}';
    final createdBy = item['created_by'] as String?;
    final general =
        Map<String, dynamic>.from(item['general'] as Map? ?? {});
    final rawCards =
        (item['card_charges'] as List?)?.cast<dynamic>() ?? const [];
    final cards = <CardChargeEntry>[];
    for (final c in rawCards) {
      final m = Map<String, dynamic>.from(c as Map);
      final entry = CardChargeEntry();
      final bank = '${m['bank'] ?? ''}';
      if (bank == 'BCR' || bank == 'Promerica') {
        entry.bank = bank;
      } else if (bank == 'Custom') {
        entry.bank = 'Custom';
        entry.customBank.text = '${m['custom_bank'] ?? ''}';
      } else {
        entry.bank = 'Custom';
        entry.customBank.text = bank;
      }
      entry.amount.text = '${m['amount'] ?? 0}';
      cards.add(entry);
    }

    try {
      final bytes = await buildCierrePersonalReceiptPdf(
        date: date,
        cashier: cashier,
        createdBy: createdBy,
        general: general,
        cards: cards,
      );
      final printer = sl<ReceiptPrinterService>();
      final printed = await printer.printPdf(bytes,
          name: 'cierre_personal_${cashier}_${date.toIso8601String()}');
      if (!printed) {
        await openCierrePersonalReceiptPdf(bytes, cashier);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Print error: $e')));
      }
    } finally {
      for (final c in cards) {
        c.dispose();
      }
    }
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Eliminar cierre'),
        content: const Text('¿Seguro que quieres eliminar este cierre?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await context.read<CierrePersonalDetailCubit>().delete();
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Delete error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colones = NumberFormat.currency(symbol: '₡', decimalDigits: 2);
    final dateFmt = DateFormat('MMM d, yyyy');

    final dateRaw = item['date'] as String?;
    final date = dateRaw != null
        ? dateFmt.format(DateTime.parse(dateRaw))
        : '—';
    final general = item['general'] as Map? ?? {};
    double _p(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    double n(String k) => _p(general[k]);
    final calc = item['calculations'] as Map? ?? {};
    final cardsTotal = _p(calc['cards_total']);
    final dif = _p(calc['diferencia_a_depositar']);

    final auth = context.read<AuthCubit>().state;
    final canDelete = auth is AuthAuthenticated &&
        auth.hasPrivilege('delete_closure');

    final cards =
        (item['card_charges'] as List?)?.cast<dynamic>() ?? const [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(date,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text(
                      'Cajero: ${item['usuario'] ?? '—'}   •   Por: ${item['created_by'] ?? '—'}',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _print(context),
                icon: const Icon(Icons.print_outlined, size: 18),
                label: const Text('Imprimir Recibo'),
              ),
              if (canDelete) ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: () => _delete(context),
                  icon: Icon(Icons.delete_outline, color: colorScheme.error),
                  tooltip: 'Eliminar',
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Tile(label: 'Venta Bruta', value: colones.format(n('BrutTotal'))),
              _Tile(label: 'Bonos', value: colones.format(n('TotalBonos'))),
              _Tile(label: 'Descuentos', value: colones.format(n('TotalDiscount'))),
              _Tile(
                  label: 'Total a Pagar',
                  value: colones.format(n('SUM_TOTAL_A_PAGAR'))),
              _Tile(
                  label: 'Facturas Anuladas',
                  value: '${n('TotalVoided').toInt()}'),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          Text('Cobros con Tarjeta',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (cards.isEmpty)
            Text('Sin cobros',
                style: TextStyle(color: colorScheme.onSurfaceVariant))
          else
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < cards.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        border: i < cards.length - 1
                            ? Border(
                                bottom: BorderSide(
                                    color: colorScheme.outlineVariant))
                            : null,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                              child: Text(
                                  '${(cards[i] as Map)['bank'] ?? '—'}')),
                          Text(colones.format(
                              _p((cards[i] as Map)['amount']))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Tile(
                  label: 'Total Tarjetas', value: colones.format(cardsTotal)),
              _Tile(
                  label: 'Diferencia a Depositar',
                  value: colones.format(dif),
                  highlight: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _Tile(
      {required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bg = highlight
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerLow;
    final fg =
        highlight ? colorScheme.onPrimaryContainer : colorScheme.onSurface;
    final lc = highlight
        ? colorScheme.onPrimaryContainer.withOpacity(0.7)
        : colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: highlight
            ? null
            : Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: textTheme.labelSmall?.copyWith(color: lc)),
          const SizedBox(height: 4),
          Text(value,
              style: textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}
