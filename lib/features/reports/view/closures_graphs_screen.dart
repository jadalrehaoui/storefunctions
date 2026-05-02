import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../di/service_locator.dart';
import '../../../shared/utils/privilege_helpers.dart';
import '../cubit/closures_cubit.dart';

class ClosuresGraphsScreen extends StatelessWidget {
  const ClosuresGraphsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!canSeeGraphs(context)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No tienes permiso para ver los gráficos.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return BlocProvider(
      create: (_) => ClosuresCubit(sl())..load(),
      child: const _ClosuresGraphsView(),
    );
  }
}

class _ClosuresGraphsView extends StatefulWidget {
  const _ClosuresGraphsView();

  @override
  State<_ClosuresGraphsView> createState() => _ClosuresGraphsViewState();
}

class _ClosuresGraphsViewState extends State<_ClosuresGraphsView> {
  DateTime? _from;
  DateTime? _to;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Gráficos de Cierres', style: theme.textTheme.headlineSmall),
              const Spacer(),
              IconButton.outlined(
                onPressed: () => context.read<ClosuresCubit>().load(),
                icon: const Icon(Icons.refresh_outlined, size: 18),
                tooltip: 'Recargar',
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
                        style: TextStyle(color: theme.colorScheme.error))),
                ClosuresLoaded(:final closures) =>
                  _buildBody(context, closures),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, List<Map<String, dynamic>> closures) {
    if (closures.isEmpty) {
      return const Center(child: Text('No hay cierres para graficar.'));
    }

    final dates = closures
        .map((c) {
          final raw = c['date'] as String?;
          return raw != null ? DateTime.tryParse(raw) : null;
        })
        .whereType<DateTime>()
        .toList()
      ..sort();
    if (dates.isEmpty) {
      return const Center(child: Text('Cierres sin fecha válida.'));
    }

    final earliest = DateTime(dates.first.year, dates.first.month, 1);
    final latest = dates.last;
    final defaultTo = DateTime(latest.year, latest.month, latest.day);
    final defaultFrom = DateTime(latest.year - 1, latest.month, 1);
    final from = _from ?? (defaultFrom.isBefore(earliest) ? earliest : defaultFrom);
    final to = _to ?? defaultTo;

    final filtered = closures.where((c) {
      final raw = c['date'] as String?;
      if (raw == null) return false;
      final dt = DateTime.tryParse(raw);
      if (dt == null) return false;
      final day = DateTime(dt.year, dt.month, dt.day);
      return !day.isBefore(DateTime(from.year, from.month, from.day)) &&
          !day.isAfter(DateTime(to.year, to.month, to.day));
    }).toList();

    final aggregated = _aggregateByMonth(filtered, from, to);
    final showCosts = canSeeProfitMargins(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _DatePicker(
                label: 'Desde',
                value: from,
                first: earliest,
                last: latest,
                onChanged: (d) => setState(() => _from = d),
              ),
              _DatePicker(
                label: 'Hasta',
                value: to,
                first: earliest,
                last: latest,
                onChanged: (d) => setState(() => _to = d),
              ),
              TextButton.icon(
                onPressed: () => setState(() {
                  _from = null;
                  _to = null;
                }),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Restablecer'),
              ),
              Text(
                '${filtered.length} cierres en el rango',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text('Sin datos en el rango seleccionado.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
            )
          else ...[
            _ChartCard(
              title: 'Venta Neta',
              labels: aggregated.labels,
              values: aggregated.ventaNeta,
              yFormatter: _formatColones,
            ),
            const SizedBox(height: 16),
            _ChartCard(
              title: 'Venta Bruta',
              labels: aggregated.labels,
              values: aggregated.ventaBruta,
              yFormatter: _formatColones,
            ),
            const SizedBox(height: 16),
            _ChartCard(
              title: 'Descuentos (incluye bonos)',
              labels: aggregated.labels,
              values: aggregated.descuentos,
              yFormatter: _formatColones,
            ),
            if (showCosts) ...[
              const SizedBox(height: 16),
              _ChartCard(
                title: 'Inventario (último del mes)',
                labels: aggregated.labels,
                values: aggregated.inventario,
                yFormatter: _formatColones,
              ),
            ],
            const SizedBox(height: 16),
            _ChartCard(
              title: '% Descuento',
              labels: aggregated.labels,
              values: aggregated.discountPct,
              yFormatter: (v) => '${v.toStringAsFixed(1)}%',
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}

String _formatColones(double v) {
  if (v.abs() >= 1000000) {
    return '₡${(v / 1000000).toStringAsFixed(1)}M';
  } else if (v.abs() >= 1000) {
    return '₡${(v / 1000).toStringAsFixed(0)}K';
  }
  return '₡${v.toStringAsFixed(0)}';
}

class _RangeAggregate {
  final List<String> labels;
  final List<double?> ventaNeta;
  final List<double?> ventaBruta;
  final List<double?> descuentos;
  final List<double?> inventario;
  final List<double?> discountPct;

  _RangeAggregate({
    required this.labels,
    required this.ventaNeta,
    required this.ventaBruta,
    required this.descuentos,
    required this.inventario,
    required this.discountPct,
  });
}

_RangeAggregate _aggregateByMonth(
    List<Map<String, dynamic>> closures, DateTime from, DateTime to) {
  // Build monthly buckets from `from`'s month through `to`'s month, inclusive.
  final start = DateTime(from.year, from.month, 1);
  final end = DateTime(to.year, to.month, 1);
  final buckets = <DateTime>[];
  for (var cursor = start;
      !cursor.isAfter(end);
      cursor = DateTime(cursor.year, cursor.month + 1, 1)) {
    buckets.add(cursor);
  }
  final n = buckets.length;
  final indexOf = <String, int>{
    for (var i = 0; i < n; i++) '${buckets[i].year}-${buckets[i].month}': i
  };

  final neta = List<double>.filled(n, 0);
  final netaCount = List<int>.filled(n, 0);
  final bruta = List<double>.filled(n, 0);
  final brutaCount = List<int>.filled(n, 0);
  final desc = List<double>.filled(n, 0);
  final descCount = List<int>.filled(n, 0);
  final invByBucket = <int, MapEntry<DateTime, double>>{};
  final pctSum = List<double>.filled(n, 0);
  final pctCount = List<int>.filled(n, 0);

  double? num_(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  for (final c in closures) {
    final raw = c['date'] as String?;
    if (raw == null) continue;
    final dt = DateTime.tryParse(raw);
    if (dt == null) continue;
    final i = indexOf['${dt.year}-${dt.month}'];
    if (i == null) continue;

    final general = c['general'] as Map? ?? {};
    final calc = c['calculations'] as Map? ?? {};

    final brutTotal = num_(general['BrutTotal']);
    final discount = num_(general['TotalDiscount']);
    final bonos = num_(general['TotalBonos']);
    final ventaNeta = num_(calc['ventaNeta']) ??
        ((brutTotal ?? 0) - (discount ?? 0) - (bonos ?? 0));
    final pct = num_(calc['discountPct']);
    final inv = num_(c['prev_inventory_cost']) ?? num_(c['inventory_cost']);

    if (brutTotal != null) {
      bruta[i] += brutTotal;
      brutaCount[i]++;
    }
    neta[i] += ventaNeta;
    netaCount[i]++;
    if (discount != null || bonos != null) {
      desc[i] += (discount ?? 0) + (bonos ?? 0);
      descCount[i]++;
    }
    if (pct != null) {
      pctSum[i] += pct;
      pctCount[i]++;
    }
    if (inv != null) {
      final existing = invByBucket[i];
      if (existing == null || dt.isAfter(existing.key)) {
        invByBucket[i] = MapEntry(dt, inv);
      }
    }
  }

  List<double?> nullify(List<double> sums, List<int> counts) =>
      List.generate(n, (i) => counts[i] == 0 ? null : sums[i]);
  List<double?> avg(List<double> sums, List<int> counts) =>
      List.generate(n, (i) => counts[i] == 0 ? null : sums[i] / counts[i]);

  // Label format: "Mar '25" if range crosses years, "Mar" otherwise.
  final crossesYears = buckets.first.year != buckets.last.year;
  final labels = buckets.map((d) {
    final mon = DateFormat.MMM('es').format(d);
    return crossesYears ? "$mon '${d.year % 100}" : mon;
  }).toList();

  return _RangeAggregate(
    labels: labels,
    ventaNeta: nullify(neta, netaCount),
    ventaBruta: nullify(bruta, brutaCount),
    descuentos: nullify(desc, descCount),
    inventario: List.generate(n, (i) => invByBucket[i]?.value),
    discountPct: avg(pctSum, pctCount),
  );
}

class _DatePicker extends StatelessWidget {
  final String label;
  final DateTime value;
  final DateTime first;
  final DateTime last;
  final ValueChanged<DateTime> onChanged;

  const _DatePicker({
    required this.label,
    required this.value,
    required this.first,
    required this.last,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM y', 'es');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label:',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value,
              firstDate: first,
              lastDate: last,
            );
            if (picked != null) onChanged(picked);
          },
          icon: const Icon(Icons.calendar_today_outlined, size: 16),
          label: Text(fmt.format(value)),
        ),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final List<String> labels;
  final List<double?> values;
  final String Function(double) yFormatter;

  const _ChartCard({
    required this.title,
    required this.labels,
    required this.values,
    required this.yFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lineColor = theme.colorScheme.primary;

    final hasAny = values.any((v) => v != null);
    final maxY = _maxOf(values);
    final minY = _minOf(values);
    final yRange = (maxY - minY).abs();
    final yPad = yRange == 0 ? (maxY.abs() * 0.1 + 1) : yRange * 0.1;

    final n = values.length;
    final labelInterval = n <= 12 ? 1.0 : (n / 12).ceilToDouble();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          SizedBox(
            height: 240,
            child: !hasAny
                ? Center(
                    child: Text('Sin datos',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)))
                : LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: (n - 1).toDouble().clamp(0, double.infinity),
                      minY: minY - yPad,
                      maxY: maxY + yPad,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => FlLine(
                            color: theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.4),
                            strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 56,
                            getTitlesWidget: (v, meta) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(yFormatter(v),
                                  style: theme.textTheme.labelSmall),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: labelInterval,
                            getTitlesWidget: (v, meta) {
                              final i = v.round();
                              if (i < 0 || i >= labels.length) {
                                return const SizedBox();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(labels[i],
                                    style: theme.textTheme.labelSmall),
                              );
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(
                            color: theme.colorScheme.outlineVariant),
                      ),
                      lineBarsData: [_series(values, lineColor)],
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touched) => touched.map((s) {
                            final i = s.x.round();
                            final lbl = (i >= 0 && i < labels.length)
                                ? labels[i]
                                : '';
                            return LineTooltipItem(
                              '$lbl\n${yFormatter(s.y)}',
                              TextStyle(
                                color: lineColor,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  static LineChartBarData _series(List<double?> values, Color color) {
    final spots = <FlSpot>[];
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v != null) spots.add(FlSpot(i.toDouble(), v));
    }
    return LineChartBarData(
      spots: spots,
      isCurved: false,
      color: color,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 3,
          color: color,
          strokeColor: Colors.white,
          strokeWidth: 1.5,
        ),
      ),
    );
  }

  static double _maxOf(Iterable<double?> values) {
    double m = double.negativeInfinity;
    for (final v in values) {
      if (v != null && v > m) m = v;
    }
    return m == double.negativeInfinity ? 0 : m;
  }

  static double _minOf(Iterable<double?> values) {
    double m = double.infinity;
    for (final v in values) {
      if (v != null && v < m) m = v;
    }
    return m == double.infinity ? 0 : m;
  }
}
