import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../di/service_locator.dart';
import '../../../l10n/l10n.dart';
import '../cubit/dashboard_sales_cubit.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DashboardSalesCubit(sl())..start(),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.navDashboard,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          const _SalesSection(),
        ],
      ),
    );
  }
}

class _SalesSection extends StatelessWidget {
  const _SalesSection();

  Future<void> _pickDateRange(BuildContext context) async {
    final cubit = context.read<DashboardSalesCubit>();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: cubit.selectedRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      cubit.selectRange(picked);
    }
  }

  String _formatRange(DateTimeRange range, DateFormat fmt) {
    if (range.start.toIso8601String().substring(0, 10) ==
        range.end.toIso8601String().substring(0, 10)) {
      return fmt.format(range.start);
    }
    return '${fmt.format(range.start)} – ${fmt.format(range.end)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final dateFmt = DateFormat.yMMMd();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.dashboardToday,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Divider(color: colorScheme.outlineVariant),
            ),
            const SizedBox(width: 12),
            BlocBuilder<DashboardSalesCubit, DashboardSalesState>(
              buildWhen: (prev, curr) =>
                  _rangeOf(prev) != _rangeOf(curr),
              builder: (context, state) {
                final range = context
                    .read<DashboardSalesCubit>()
                    .selectedRange;
                return ActionChip(
                  avatar: const Icon(Icons.date_range, size: 16),
                  label: Text(_formatRange(range, dateFmt)),
                  onPressed: () => _pickDateRange(context),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        BlocBuilder<DashboardSalesCubit, DashboardSalesState>(
          builder: (context, state) => switch (state) {
            DashboardSalesLoading() =>
              const Center(child: CircularProgressIndicator()),
            DashboardSalesFailure(:final error) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error,
                        style: TextStyle(color: colorScheme.error)),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () =>
                          context.read<DashboardSalesCubit>().load(),
                      child: Text(l10n.btnRetry),
                    ),
                  ],
                ),
              ),
            DashboardSalesLoaded(:final current, :final lastYear, :final mikail) =>
              SizedBox(
                height: 380,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SalesCard(data: current, mikail: mikail),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _ComparisonChart(
                          current: current, lastYear: lastYear),
                    ),
                  ],
                ),
              ),
          },
        ),
      ],
    );
  }

  DateTimeRange? _rangeOf(DashboardSalesState state) {
    if (state is DashboardSalesLoaded) return state.range;
    if (state is DashboardSalesFailure) return state.range;
    return null;
  }
}

class _SalesCard extends StatelessWidget {
  final DashboardSalesData data;
  final MikailSalesData mikail;
  const _SalesCard({required this.data, required this.mikail});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final colones = NumberFormat.currency(symbol: '\u20a1', decimalDigits: 2);
    final numFmt = NumberFormat.decimalPattern();

    return SizedBox(
      width: 480,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Row(
                label: l10n.dashboardTotalSales,
                value: colones.format(data.brutTotal),
                icon: Icons.point_of_sale_outlined,
              ),
              const SizedBox(height: 12),
              _Row(
                label: l10n.dashboardTotalDiscounts,
                value: colones.format(data.totalDiscount),
                icon: Icons.discount_outlined,
              ),
              const SizedBox(height: 12),
              _Row(
                label: l10n.dashboardTotalBonos,
                value: colones.format(data.totalBonos),
                icon: Icons.card_giftcard_outlined,
              ),
              Divider(
                height: 24,
                color: colorScheme.outlineVariant,
              ),
              _Row(
                label: l10n.dashboardNetSales,
                value: colones.format(data.netSales),
                icon: Icons.trending_up_outlined,
                bold: true,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.receipt_outlined,
                    label: l10n.dashboardInvoices,
                    value: numFmt.format(data.totalCount),
                    textTheme: textTheme,
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(width: 16),
                  _InfoChip(
                    icon: Icons.cancel_outlined,
                    label: l10n.dashboardNulledInvoices,
                    value: numFmt.format(data.totalNulled),
                    textTheme: textTheme,
                    colorScheme: colorScheme,
                  ),
                ],
              ),
              Divider(
                height: 24,
                color: colorScheme.outlineVariant,
              ),
              _Row(
                label: l10n.dashboardClientCount,
                value: numFmt.format(data.clientCount),
                icon: Icons.people_outlined,
              ),
              const SizedBox(height: 12),
              _Row(
                label: l10n.dashboardAvgPerClient,
                value: colones.format(data.averageSpentPerClient),
                icon: Icons.person_outlined,
              ),
              Divider(
                height: 24,
                color: colorScheme.outlineVariant,
              ),
              _Row(
                label: l10n.dashboardMikailSales,
                value: colones.format(mikail.total),
                icon: Icons.storefront_outlined,
              ),
              const SizedBox(height: 12),
              _Row(
                label: l10n.dashboardMikailItems,
                value: numFmt.format(mikail.totalItems),
                icon: Icons.inventory_2_outlined,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComparisonChart extends StatelessWidget {
  final DashboardSalesData current;
  final DashboardSalesData lastYear;

  const _ComparisonChart({required this.current, required this.lastYear});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final labels = [
      l10n.dashboardTotalSales,
      l10n.dashboardTotalDiscounts,
      l10n.dashboardTotalBonos,
      l10n.dashboardNetSales,
    ];
    final currentValues = [
      current.brutTotal,
      current.totalDiscount,
      current.totalBonos,
      current.netSales,
    ];
    final lastYearValues = [
      lastYear.brutTotal,
      lastYear.totalDiscount,
      lastYear.totalBonos,
      lastYear.netSales,
    ];

    final maxValue = [...currentValues, ...lastYearValues]
        .fold<double>(0, (a, b) => a > b ? a : b);
    final interval = maxValue > 0 ? (maxValue / 4).ceilToDouble() : 1.0;

    final currentColor = colorScheme.primary;
    final lastYearColor = colorScheme.primary.withValues(alpha: 0.35);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _LegendDot(
                      color: currentColor,
                      label: l10n.dashboardCurrentYear),
                  const SizedBox(width: 16),
                  _LegendDot(
                      color: lastYearColor,
                      label: l10n.dashboardLastYear),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxValue > 0 ? maxValue * 1.15 : 10,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final colones = NumberFormat.currency(
                              symbol: '\u20a1', decimalDigits: 0);
                          final label = rodIndex == 0
                              ? l10n.dashboardCurrentYear
                              : l10n.dashboardLastYear;
                          return BarTooltipItem(
                            '$label\n${colones.format(rod.toY)}',
                            textTheme.bodySmall!.copyWith(
                              color: colorScheme.onInverseSurface,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 60,
                          interval: interval,
                          getTitlesWidget: (value, meta) {
                            final fmt = NumberFormat.compact();
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                fmt.format(value),
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= labels.length) {
                              return const SizedBox.shrink();
                            }
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                labels[idx],
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: interval,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: colorScheme.outlineVariant
                            .withValues(alpha: 0.5),
                        strokeWidth: 1,
                      ),
                    ),
                    barGroups: List.generate(labels.length, (i) {
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: currentValues[i],
                            color: currentColor,
                            width: 18,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                          BarChartRodData(
                            toY: lastYearValues[i],
                            color: lastYearColor,
                            width: 18,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool bold;

  const _Row({
    required this.label,
    required this.value,
    required this.icon,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: bold
              ? textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
              : textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.textTheme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
