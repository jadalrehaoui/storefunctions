import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../di/service_locator.dart';
import '../cubit/sales_report_cubit.dart';

class SalesReportsScreen extends StatelessWidget {
  const SalesReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SalesReportCubit(sl()),
      child: const _SalesReportsView(),
    );
  }
}

class _SalesReportsView extends StatefulWidget {
  const _SalesReportsView();

  @override
  State<_SalesReportsView> createState() => _SalesReportsViewState();
}

class _SalesReportsViewState extends State<_SalesReportsView> {
  DateTime _startDate = DateTime.now().copyWith(day: 1);
  DateTime _endDate = DateTime.now();

  static final _displayFmt = DateFormat('MMM d, yyyy');

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: _endDate,
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  void _load() {
    context.read<SalesReportCubit>().load(_startDate, _endDate);
  }

  Future<void> _download(
      BuildContext context, Future<String> Function() fn) async {
    try {
      final path = await fn();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Saved: $path')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
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
          Text('Sales Reports',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 20),
          // Date range row
          Row(
            children: [
              _DateButton(
                label: 'From',
                value: _displayFmt.format(_startDate),
                onTap: _pickStart,
              ),
              const SizedBox(width: 12),
              _DateButton(
                label: 'To',
                value: _displayFmt.format(_endDate),
                onTap: _pickEnd,
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Generate'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Split panels
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sitsa panel
                Expanded(
                  child: BlocBuilder<SalesReportCubit, SalesReportState>(
                    builder: (context, state) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PanelHeader(
                          title: 'Sitsa',
                          color: colorScheme.primaryContainer,
                          onColor: colorScheme.onPrimaryContainer,
                          onDownload: state is SalesReportLoaded &&
                                  state.sitsaRows.isNotEmpty
                              ? () => _download(context, () =>
                                  context
                                      .read<SalesReportCubit>()
                                      .downloadSitsa(state.sitsaRows))
                              : null,
                        ),
                        const SizedBox(height: 12),
                        const Expanded(child: _SitsaPanel()),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Mikail panel
                Expanded(
                  child: BlocBuilder<SalesReportCubit, SalesReportState>(
                    builder: (context, state) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PanelHeader(
                          title: 'Mikail',
                          color: colorScheme.secondaryContainer,
                          onColor: colorScheme.onSecondaryContainer,
                          onDownload: state is SalesReportLoaded &&
                                  state.mikailRows.isNotEmpty
                              ? () => _download(context, () =>
                                  context
                                      .read<SalesReportCubit>()
                                      .downloadMikail(state.mikailRows))
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Expanded(child: _MikailPanel()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SitsaPanel extends StatelessWidget {
  const _SitsaPanel();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SalesReportCubit, SalesReportState>(
      builder: (context, state) => switch (state) {
        SalesReportInitial() => const Center(
            child: Text('Select a date range and press Generate')),
        SalesReportLoading() =>
          const Center(child: CircularProgressIndicator()),
        SalesReportFailure(:final error) => Center(
            child: Text(error,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error))),
        SalesReportLoaded(:final sitsaRows) => sitsaRows.isEmpty
            ? const Center(child: Text('No data for this period'))
            : _ReportTable(rows: sitsaRows),
      },
    );
  }
}

class _MikailPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SalesReportCubit, SalesReportState>(
      builder: (context, state) => switch (state) {
        SalesReportInitial() => const Center(
            child: Text('Select a date range and press Generate')),
        SalesReportLoading() =>
          const Center(child: CircularProgressIndicator()),
        SalesReportFailure(:final error) => Center(
            child: Text(error,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error))),
        SalesReportLoaded(:final mikailRows) => mikailRows.isEmpty
            ? const Center(child: Text('No data for this period'))
            : _ReportTable(rows: mikailRows),
      },
    );
  }
}

class _ReportTable extends StatelessWidget {
  final List<dynamic> rows;
  const _ReportTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final columns = (rows.first as Map<String, dynamic>).keys.toList();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            Container(
              color: colorScheme.surfaceContainerLow,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: columns
                    .map((col) => Expanded(
                          child: Text(
                            '$col',
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: colorScheme.outlineVariant),
                itemBuilder: (context, i) {
                  final row = rows[i] as Map<String, dynamic>;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    color: i.isOdd
                        ? colorScheme.surfaceContainerLowest
                        : null,
                    child: Row(
                      children: columns
                          .map((col) => Expanded(
                                child: Text(
                                  '${row[col] ?? ''}',
                                  style: textTheme.bodySmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
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
}

class _PanelHeader extends StatelessWidget {
  final String title;
  final Color color;
  final Color onColor;
  final VoidCallback? onDownload;

  const _PanelHeader({
    required this.title,
    required this.color,
    required this.onColor,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: onColor,
            ),
          ),
          const Spacer(),
          if (onDownload != null)
            IconButton(
              onPressed: onDownload,
              icon: Icon(Icons.download_outlined, size: 18, color: onColor),
              tooltip: 'Download CSV',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

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
            Text('$label  ',
                style: TextStyle(
                    fontSize: 12, color: colorScheme.onSurfaceVariant)),
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
