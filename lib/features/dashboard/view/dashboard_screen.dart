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

  Future<void> _pickRange(BuildContext context) async {
    final cubit = context.read<DashboardSalesCubit>();
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange:
          DateTimeRange(start: cubit.startDate, end: cubit.endDate),
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked != null) {
      cubit.selectRange(picked.start, picked.end);
    }
  }

  String _formatRange(DateTime start, DateTime end, DateFormat fmt) {
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return fmt.format(start);
    }
    return '${fmt.format(start)} – ${fmt.format(end)}';
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
              buildWhen: (prev, curr) => _rangeOf(prev) != _rangeOf(curr),
              builder: (context, state) {
                final cubit = context.read<DashboardSalesCubit>();
                return ActionChip(
                  avatar: const Icon(Icons.date_range, size: 16),
                  label: Text(
                      _formatRange(cubit.startDate, cubit.endDate, dateFmt)),
                  onPressed: () => _pickRange(context),
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
            DashboardSalesLoaded(:final current, :final lastYear, :final twoYearsAgo, :final mikail, :final workdb) =>
              SizedBox(
                height: 520,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SalesCard(data: current, mikail: mikail, workdb: workdb),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _ComparisonChart(
                          current: current,
                          lastYear: lastYear,
                          twoYearsAgo: twoYearsAgo),
                    ),
                  ],
                ),
              ),
          },
        ),
      ],
    );
  }

  (DateTime, DateTime)? _rangeOf(DashboardSalesState state) {
    if (state is DashboardSalesLoaded) return (state.startDate, state.endDate);
    if (state is DashboardSalesFailure) {
      return (state.startDate, state.endDate);
    }
    return null;
  }
}

class _SalesCard extends StatelessWidget {
  final DashboardSalesData data;
  final MikailSalesData mikail;
  final WorkdbSalesData workdb;
  const _SalesCard(
      {required this.data, required this.mikail, required this.workdb});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
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
              Divider(
                height: 24,
                color: colorScheme.outlineVariant,
              ),
              _Row(
                label: l10n.dashboardClientCount,
                value: numFmt.format(data.clientCount),
                icon: Icons.people_outline,
              ),
              const SizedBox(height: 12),
              _Row(
                label: l10n.dashboardAvgPerClient,
                value: colones.format(data.averageSpentPerClient),
                icon: Icons.person_outline,
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
              Divider(
                height: 24,
                color: colorScheme.outlineVariant,
              ),
              _Row(
                label: l10n.dashboardWorkdbSales,
                value: colones.format(workdb.total),
                icon: Icons.receipt_long_outlined,
              ),
              const SizedBox(height: 12),
              _Row(
                label: l10n.dashboardWorkdbDiscount,
                value: colones.format(workdb.totalDiscount),
                icon: Icons.discount_outlined,
              ),
              const SizedBox(height: 12),
              _Row(
                label: l10n.dashboardWorkdbNet,
                value: colones.format(workdb.netTotal),
                icon: Icons.trending_up_outlined,
              ),
              const SizedBox(height: 12),
              _Row(
                label: l10n.dashboardWorkdbInvoices,
                value: numFmt.format(workdb.invoiceCount),
                icon: Icons.receipt_outlined,
              ),
              const SizedBox(height: 12),
              _Row(
                label: l10n.dashboardWorkdbItems,
                value: numFmt.format(workdb.itemsCount),
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
  final DashboardSalesData twoYearsAgo;

  const _ComparisonChart({
    required this.current,
    required this.lastYear,
    required this.twoYearsAgo,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final colones = NumberFormat.currency(symbol: '\u20a1', decimalDigits: 0);

    final currentColor = colorScheme.primary;
    final lastYearColor = colorScheme.primary.withValues(alpha: 0.5);
    final twoYearsColor = colorScheme.primary.withValues(alpha: 0.2);

    final yearLabels = [
      l10n.dashboardCurrentYear,
      l10n.dashboardLastYear,
      l10n.dashboardTwoYearsAgo,
    ];
    final values = [
      current.brutTotal,
      lastYear.brutTotal,
      twoYearsAgo.brutTotal,
    ];
    final colors = [currentColor, lastYearColor, twoYearsColor];

    final maxValue = values.fold<double>(0, (a, b) => a > b ? a : b);

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
                Text(
                  l10n.dashboardTotalSales,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () =>
                      context.read<DashboardSalesCubit>().load(),
                  icon: Icon(Icons.refresh,
                      size: 18, color: colorScheme.onSurfaceVariant),
                  tooltip: l10n.btnRetry,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(values.length, (i) {
                  final fraction = maxValue > 0 ? values[i] / maxValue : 0.0;
                  return Padding(
                    padding: EdgeInsets.only(
                        bottom: i < values.length - 1 ? 16 : 0),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text(
                            yearLabels[i],
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 400),
                                  height: 40,
                                  width: constraints.maxWidth * fraction,
                                  decoration: BoxDecoration(
                                    color: colors[i],
                                    borderRadius: const BorderRadius.horizontal(
                                      right: Radius.circular(4),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          colones.format(values[i]),
                          style: textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
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

