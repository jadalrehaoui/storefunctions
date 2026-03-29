import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../di/service_locator.dart';
import '../../../l10n/l10n.dart';
import '../cubit/cierre_mikail_cubit.dart';
import '../utils/mikail_pdf.dart' as mikail_pdf;

class CierreMikailScreen extends StatelessWidget {
  const CierreMikailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CierreMikailCubit(sl()),
      child: const _CierreMikailView(),
    );
  }
}

class _CierreMikailView extends StatefulWidget {
  const _CierreMikailView();

  @override
  State<_CierreMikailView> createState() => _CierreMikailViewState();
}

class _CierreMikailViewState extends State<_CierreMikailView> {
  DateTime _date = DateTime.now();
  String? _closureId;
  static final _displayFmt = DateFormat('MMM d, yyyy');

  Future<void> _save(Map<String, dynamic> data) async {
    try {
      final isNew = _closureId == null;
      final payload = {
        'date': DateFormat('yyyy-MM-dd').format(_date),
        'type': 'mikail',
        'invoices': data['invoices'],
        'detail': data['detail'],
        'calculations': {'total': data['total']},
      };
      final id = await context
          .read<CierreMikailCubit>()
          .saveOrUpdate(payload, closureId: _closureId);
      setState(() => _closureId = id);
      if (mounted) {
        final l10n = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isNew ? l10n.msgSaved : l10n.msgUpdated)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.msgErrorDetail(e.toString()))));
      }
    }
  }

  Future<void> _print(Map<String, dynamic> data) async {
    try {
      final path =
          await mikail_pdf.generateAndOpenMikail(data, _date);
      if (mounted && path != 'printed') {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.msgSavedAt(path))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.msgErrorDetail(e.toString()))));
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.cierreMikailTitle,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          Row(
            children: [
              _DateButton(
                value: _displayFmt.format(_date),
                onTap: _pickDate,
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () {
                  setState(() => _closureId = null);
                  context.read<CierreMikailCubit>().load(_date);
                },
                icon: const Icon(Icons.play_arrow_outlined, size: 18),
                label: Text(context.l10n.btnGenerate),
              ),
              const SizedBox(width: 12),
              BlocBuilder<CierreMikailCubit, CierreMikailState>(
                builder: (context, state) => state is CierreMikailLoaded
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton.outlined(
                            onPressed: () => _print(state.data),
                            icon: const Icon(Icons.print_outlined, size: 18),
                            tooltip: context.l10n.btnPrint,
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: () => _save(state.data),
                            icon: Icon(
                              _closureId == null
                                  ? Icons.save_outlined
                                  : Icons.sync_outlined,
                              size: 18,
                            ),
                            tooltip: _closureId == null ? context.l10n.tooltipGuardar : context.l10n.tooltipActualizar,
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: BlocBuilder<CierreMikailCubit, CierreMikailState>(
              builder: (context, state) => switch (state) {
                CierreMikailInitial() => Center(
                    child: Text(context.l10n.msgSelectDateGenerate)),
                CierreMikailLoading() =>
                  const Center(child: CircularProgressIndicator()),
                CierreMikailFailure(:final error) => Center(
                    child: Text(error,
                        style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.error))),
                CierreMikailLoaded(:final data) =>
                  _MikailLayout(data: data),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MikailLayout extends StatelessWidget {
  final Map<String, dynamic> data;
  const _MikailLayout({required this.data});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final colones = NumberFormat.currency(symbol: '₡', decimalDigits: 0);
    final dateFmt = DateFormat('dd/MM/yyyy');

    final total = (data['total'] as num?)?.toDouble() ?? 0.0;
    final invoices = ((data['invoices'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final detail = ((data['detail'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    String fmtDate(dynamic v) {
      if (v == null) return '—';
      final raw = v is List ? v.first : v;
      if (raw == null) return '—';
      try {
        return dateFmt.format(DateTime.parse('$raw'));
      } catch (_) {
        return '$raw';
      }
    }


    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total tile
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.labelTotalDia,
                    style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer.withOpacity(0.7))),
                const SizedBox(height: 4),
                Text(colones.format(total),
                    style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onPrimaryContainer)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Invoices table
          Text(context.l10n.sectionFacturas,
              style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _MikailTable(
            columns: const ['Factura', 'Fecha', 'Cliente', 'Monto'],
            flexes: const [2, 2, 3, 2],
            aligns: const [
              TextAlign.start, TextAlign.start,
              TextAlign.start, TextAlign.end,
            ],
            rows: invoices.map((inv) => [
              '${inv['Factura'] ?? '—'}',
              fmtDate(inv['Fecha']),
              (inv['Cliente01'] as String? ?? '—').trim(),
              colones.format((inv['Monto'] as num?)?.toDouble() ?? 0),
            ]).toList(),
          ),
          const SizedBox(height: 24),

          // Detail table
          Text(context.l10n.sectionDetalle,
              style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _MikailTable(
            columns: const ['Factura', 'Artículo', 'Descripción', 'Modelo', 'Cant.'],
            flexes: const [2, 2, 5, 3, 1],
            aligns: const [
              TextAlign.start, TextAlign.start, TextAlign.start,
              TextAlign.start, TextAlign.end,
            ],
            rows: detail.map((d) => [
              '${d['Factura'] ?? '—'}',
              (d['Articulo'] as String? ?? '—').trim(),
              (d['Descripcion'] as String? ?? '—').trim(),
              (d['Modelo'] as String? ?? '—').trim(),
              '${d['Cantidad'] ?? '—'}',
            ]).toList(),
          ),
        ],
      ),
    );
  }
}

class _MikailTable extends StatelessWidget {
  final List<String> columns;
  final List<int> flexes;
  final List<TextAlign> aligns;
  final List<List<String>> rows;

  const _MikailTable({
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

    Widget dataCell(int col, String text, bool odd) => Expanded(
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: List.generate(columns.length, headerCell),
              ),
            ),
            const Divider(height: 1),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rows.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: colorScheme.outlineVariant),
              itemBuilder: (context, i) {
                final row = rows[i];
                return Container(
                  color: i.isOdd ? colorScheme.surfaceContainerLowest : null,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Row(
                    children: List.generate(
                        row.length, (c) => dataCell(c, row[c], i.isOdd)),
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
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant)),
            Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(width: 8),
            Icon(Icons.calendar_today_outlined,
                size: 14, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
