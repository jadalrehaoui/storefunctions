import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../di/service_locator.dart';
import '../cubit/cierres_personales_cubit.dart';

class CierresPersonalesScreen extends StatelessWidget {
  const CierresPersonalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CierresPersonalesCubit(sl())..load(),
      child: const _CierresPersonalesView(),
    );
  }
}

class _CierresPersonalesView extends StatefulWidget {
  const _CierresPersonalesView();

  @override
  State<_CierresPersonalesView> createState() => _CierresPersonalesViewState();
}

class _CierresPersonalesViewState extends State<_CierresPersonalesView> {
  DateTime? _date;
  final _usuarioCtrl = TextEditingController();

  @override
  void dispose() {
    _usuarioCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    context.read<CierresPersonalesCubit>().load(
          date: _date != null ? DateFormat('yyyy-MM-dd').format(_date!) : null,
          usuario: _usuarioCtrl.text.trim(),
        );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = picked);
      _apply();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Cierres Personales',
                  style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              IconButton.outlined(
                onPressed: _apply,
                icon: const Icon(Icons.refresh_outlined, size: 18),
                tooltip: 'Refrescar',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(_date == null
                    ? 'Fecha'
                    : DateFormat('MMM d, yyyy').format(_date!)),
              ),
              if (_date != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () {
                    setState(() => _date = null);
                    _apply();
                  },
                  icon: const Icon(Icons.close, size: 16),
                  tooltip: 'Limpiar fecha',
                ),
              ],
              const SizedBox(width: 12),
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _usuarioCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Cajero',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _apply(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _apply, child: const Text('Filtrar')),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: BlocBuilder<CierresPersonalesCubit, CierresPersonalesState>(
              builder: (context, state) => switch (state) {
                CierresPersonalesInitial() => const SizedBox.shrink(),
                CierresPersonalesLoading() =>
                  const Center(child: CircularProgressIndicator()),
                CierresPersonalesFailure(:final error) => Center(
                    child: Text(error,
                        style: TextStyle(color: colorScheme.error))),
                CierresPersonalesLoaded(:final items) => items.isEmpty
                    ? Center(
                        child: Text('Sin cierres',
                            style: TextStyle(
                                color: colorScheme.onSurfaceVariant)))
                    : _Table(items: items),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Table extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _Table({required this.items});

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
            Container(
              color: colorScheme.surfaceContainerLow,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _hd('Fecha', flex: 2, t: textTheme, c: colorScheme),
                  _hd('Cajero', flex: 2, t: textTheme, c: colorScheme),
                  _hd('Por', flex: 2, t: textTheme, c: colorScheme),
                  _hd('Tipo', flex: 2, t: textTheme, c: colorScheme),
                  _hd('Total a Pagar',
                      flex: 2, t: textTheme, c: colorScheme, end: true),
                  _hd('Tarjetas',
                      flex: 2, t: textTheme, c: colorScheme, end: true),
                  _hd('Diferencia',
                      flex: 2, t: textTheme, c: colorScheme, end: true),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: colorScheme.outlineVariant),
                itemBuilder: (context, i) {
                  final m = items[i];
                  final id = m['id']?.toString();
                  final type = m['type'] as String? ?? 'sitsa';
                  final isParallel = type == 'parallel';
                  final dateRaw = m['date'] as String?;
                  final date = dateRaw != null
                      ? dateFmt.format(DateTime.parse(dateRaw))
                      : '—';

                  double? totalAPagar;
                  double? cardsTotal;
                  double? dif;
                  if (isParallel) {
                    final totals = m['totals'] as Map? ?? {};
                    totalAPagar =
                        (totals['total_net'] as num?)?.toDouble();
                  } else {
                    final general = m['general'] as Map? ?? {};
                    totalAPagar =
                        (general['SUM_TOTAL_A_PAGAR'] as num?)?.toDouble();
                    final calc = m['calculations'] as Map? ?? {};
                    cardsTotal =
                        (calc['cards_total'] as num?)?.toDouble();
                    dif = (calc['diferencia_a_depositar'] as num?)
                        ?.toDouble();
                  }

                  return InkWell(
                    onTap: (!isParallel && id != null)
                        ? () => context
                            .push('/reports/cierres-personales/$id')
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
                                      fontWeight: FontWeight.w500))),
                          Expanded(
                              flex: 2,
                              child: Text('${m['usuario'] ?? '—'}',
                                  style: textTheme.bodyMedium)),
                          Expanded(
                              flex: 2,
                              child: Text('${m['created_by'] ?? '—'}',
                                  style: textTheme.bodyMedium)),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _TypeChip(
                                  isParallel: isParallel,
                                  colorScheme: colorScheme),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              totalAPagar != null
                                  ? colones.format(totalAPagar)
                                  : '—',
                              style: textTheme.bodyMedium,
                              textAlign: TextAlign.end,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              cardsTotal != null
                                  ? colones.format(cardsTotal)
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

  Widget _hd(String label,
      {required int flex,
      required TextTheme t,
      required ColorScheme c,
      bool end = false}) {
    return Expanded(
      flex: flex,
      child: Text(label,
          style: t.labelSmall?.copyWith(
              color: c.onSurfaceVariant, fontWeight: FontWeight.w600),
          textAlign: end ? TextAlign.end : TextAlign.start),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final bool isParallel;
  final ColorScheme colorScheme;
  const _TypeChip({required this.isParallel, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final bg = isParallel
        ? colorScheme.tertiaryContainer
        : colorScheme.primaryContainer;
    final fg = isParallel
        ? colorScheme.onTertiaryContainer
        : colorScheme.onPrimaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isParallel ? 'Parallel' : 'Sitsa',
        style: TextStyle(
            color: fg, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
