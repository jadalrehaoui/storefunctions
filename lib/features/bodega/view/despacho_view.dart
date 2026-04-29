import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../cubit/despacho_cubit.dart';
import '../model/ferreteria_invoice.dart';

/// Shared despacho UI driven by [DespachoCubit]. The [channel] argument
/// selects which pipeline this view renders (bodega or tec); the cubit
/// itself owns subscription lifecycle, dedup, and auto-print decisions.
class DespachoView extends StatefulWidget {
  final DespachoChannel channel;
  final String title;

  const DespachoView({
    super.key,
    required this.channel,
    required this.title,
  });

  @override
  State<DespachoView> createState() => _DespachoViewState();
}

class _DespachoViewState extends State<DespachoView> {
  Timer? _tick;
  late final DespachoCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<DespachoCubit>();
    _cubit.requestActive(widget.channel);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted &&
          _channelState(_cubit.state).invoices.isNotEmpty) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _cubit.releaseActive(widget.channel);
    _tick?.cancel();
    super.dispose();
  }

  DespachoChannelState _channelState(DespachoState s) =>
      widget.channel == DespachoChannel.bodega ? s.bodega : s.tec;

  bool _autoprintEnabled(DespachoState s) =>
      widget.channel == DespachoChannel.bodega
          ? s.bodegaEnabled
          : s.tecnologiaEnabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return BlocBuilder<DespachoCubit, DespachoState>(
      builder: (context, state) {
        final cs = _channelState(state);
        final autoprint = _autoprintEnabled(state);
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(widget.title, style: textTheme.headlineSmall),
                  const SizedBox(width: 16),
                  _StatusBadge(connected: cs.connected),
                  if (autoprint) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.print,
                              size: 14,
                              color: colorScheme.onPrimaryContainer),
                          const SizedBox(width: 4),
                          Text('Auto-imprimir',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onPrimaryContainer)),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    tooltip: 'Reconectar',
                    icon: const Icon(Icons.refresh),
                    onPressed: () => _cubit.reconnect(widget.channel),
                  ),
                ],
              ),
              if (cs.error != null) ...[
                const SizedBox(height: 8),
                Text('Error: ${cs.error}',
                    style: textTheme.bodySmall
                        ?.copyWith(color: colorScheme.error)),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: cs.invoices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_shipping_outlined,
                                size: 64,
                                color: colorScheme.onSurfaceVariant),
                            const SizedBox(height: 12),
                            Text('Esperando facturas…',
                                style: textTheme.titleMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: cs.invoices.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 12),
                        itemBuilder: (_, i) => _InvoiceCard(
                          invoice: cs.invoices[i],
                          onEntregado: () => _cubit.markEntregado(
                              widget.channel, cs.invoices[i]),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool connected;
  const _StatusBadge({required this.connected});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = connected ? const Color(0xFF4CAF50) : colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            connected ? 'En vivo' : 'Desconectado',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final FerreteriaInvoice invoice;
  final VoidCallback onEntregado;
  const _InvoiceCard({required this.invoice, required this.onEntregado});

  static final _qty = NumberFormat.decimalPattern('es_CR');

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final elapsed = invoice.primeraVenta != null
        ? DateTime.now().difference(invoice.primeraVenta!.toLocal())
        : null;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(invoice.cliente ?? '—',
                          style: textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      if (invoice.clienteCodigo != null)
                        Text(invoice.clienteCodigo!,
                            style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (elapsed != null) _ElapsedBadge(elapsed: elapsed),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Entregado'),
                  onPressed: onEntregado,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          for (var i = 0; i < invoice.items.length; i++) ...[
            if (i > 0) Divider(height: 1, color: colorScheme.outlineVariant),
            _ItemRow(item: invoice.items[i], qtyFormat: _qty),
          ],
        ],
      ),
    );
  }
}

class _ElapsedBadge extends StatelessWidget {
  final Duration elapsed;
  const _ElapsedBadge({required this.elapsed});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final overdue = elapsed.inMinutes >= 7;
    final Color bg;
    final Color fg;
    if (overdue) {
      bg = colorScheme.errorContainer;
      fg = colorScheme.onErrorContainer;
    } else {
      bg = const Color(0xFF4CAF50).withOpacity(0.12);
      fg = const Color(0xFF2E7D32);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            _format(elapsed),
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: fg),
          ),
        ],
      ),
    );
  }

  static String _format(Duration d) {
    final neg = d.isNegative;
    if (neg) d = -d;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    String two(int n) => n.toString().padLeft(2, '0');
    final base =
        h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
    return neg ? '-$base' : base;
  }
}

class _ItemRow extends StatelessWidget {
  final FerreteriaInvoiceItem item;
  final NumberFormat qtyFormat;
  const _ItemRow({required this.item, required this.qtyFormat});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              '${qtyFormat.format(item.qty)}x',
              style: textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.codigo,
                    style: textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                if (item.detalle.isNotEmpty)
                  Text(item.detalle, style: textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (item.existencia != null)
            Text(
              'Stock: ${qtyFormat.format(item.existencia!)}',
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
