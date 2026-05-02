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

class _SalesReportsViewState extends State<_SalesReportsView>
    with SingleTickerProviderStateMixin {
  DateTime _startDate = DateTime.now().copyWith(day: 1);
  DateTime _endDate = DateTime.now();
  late final TabController _tabs = TabController(length: 3, vsync: this);

  static final _displayFmt = DateFormat('MMM d, yyyy');

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
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
            .showSnackBar(SnackBar(content: Text('Guardado: $path')));
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reporte de Venta', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 20),
          Row(
            children: [
              _DateButton(
                label: 'Rango',
                value: _startDate == _endDate
                    ? _displayFmt.format(_startDate)
                    : '${_displayFmt.format(_startDate)} – ${_displayFmt.format(_endDate)}',
                onTap: _pickRange,
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Generar'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabs: const [
              Tab(text: '1. Sitsa'),
              Tab(text: '2. Parallel'),
              Tab(text: '3. Mikail'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _ReportTab(
                  title: 'Sitsa',
                  rowsSelector: (s) => s.sitsaRows,
                  download: (cubit, rows) => cubit.downloadSitsa(rows),
                  onDownload: _download,
                ),
                _ReportTab(
                  title: 'Parallel',
                  rowsSelector: (s) => s.parallelRows,
                  download: (cubit, rows) => cubit.downloadParallel(rows),
                  onDownload: _download,
                ),
                _ReportTab(
                  title: 'Mikail',
                  rowsSelector: (s) => s.mikailRows,
                  download: (cubit, rows) => cubit.downloadMikail(rows),
                  onDownload: _download,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportTab extends StatelessWidget {
  final String title;
  final List<dynamic> Function(SalesReportLoaded state) rowsSelector;
  final Future<String> Function(SalesReportCubit cubit, List<dynamic> rows)
      download;
  final Future<void> Function(BuildContext, Future<String> Function()) onDownload;

  const _ReportTab({
    required this.title,
    required this.rowsSelector,
    required this.download,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return BlocBuilder<SalesReportCubit, SalesReportState>(
      builder: (context, state) {
        Widget body;
        VoidCallback? downloadCb;
        switch (state) {
          case SalesReportInitial():
            body = const Center(
                child: Text('Selecciona un rango y presiona Generar'));
            break;
          case SalesReportLoading():
            body = const Center(child: CircularProgressIndicator());
            break;
          case SalesReportFailure(:final error):
            body = Center(
                child: Text(error,
                    style: TextStyle(color: colorScheme.error)));
            break;
          case SalesReportLoaded():
            final rows = rowsSelector(state);
            if (rows.isEmpty) {
              body =
                  const Center(child: Text('Sin datos para este período'));
            } else {
              body = _ReportTable(rows: rows);
              downloadCb = () => onDownload(
                  context,
                  () => download(
                      context.read<SalesReportCubit>(), rows));
            }
            break;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PanelHeader(
              title: title,
              color: colorScheme.primaryContainer,
              onColor: colorScheme.onPrimaryContainer,
              onDownload: downloadCb,
            ),
            const SizedBox(height: 12),
            Expanded(child: body),
          ],
        );
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
              tooltip: 'Descargar CSV',
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
