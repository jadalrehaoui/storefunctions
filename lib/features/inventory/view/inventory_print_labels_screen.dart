import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../di/service_locator.dart';
import '../../../l10n/l10n.dart';
import '../../../models/article_result.dart';
import '../../../shared/utils/label_printer.dart';
import '../../../shared/widgets/barcode_display.dart';
import '../cubit/print_labels_cubit.dart';

class InventoryPrintLabelsScreen extends StatelessWidget {
  const InventoryPrintLabelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PrintLabelsCubit(sl()),
      child: const _PrintLabelsView(),
    );
  }
}

class _PrintLabelsView extends StatefulWidget {
  const _PrintLabelsView();

  @override
  State<_PrintLabelsView> createState() => _PrintLabelsViewState();
}

class _PrintLabelsViewState extends State<_PrintLabelsView> {
  final _controller = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _rowsFocusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _searchFocusNode.dispose();
    _rowsFocusNode.dispose();
    super.dispose();
  }

  void _submit() =>
      context.read<PrintLabelsCubit>().searchByBarcode(_controller.text);

  void _onPrinted() {
    context.read<PrintLabelsCubit>().reset();
    _controller.clear();
    _searchFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PrintLabelsCubit, PrintLabelsState>(
      listener: (context, state) {
        if (state is PrintLabelsSuccess && state.results.isNotEmpty) {
          _rowsFocusNode.requestFocus();
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.inventoryPrintLabelsTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Código / Barcode',
                      prefixIcon: Icon(Icons.qr_code),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    focusNode: _searchFocusNode,
                    onSubmitted: (_) => _submit(),
                    autofocus: true,
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Buscar'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _ResultView(
                rowsFocusNode: _rowsFocusNode,
                onPrinted: _onPrinted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final FocusNode rowsFocusNode;
  final VoidCallback onPrinted;

  const _ResultView({required this.rowsFocusNode, required this.onPrinted});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PrintLabelsCubit, PrintLabelsState>(
      builder: (context, state) => switch (state) {
        PrintLabelsInitial() => const SizedBox.shrink(),
        PrintLabelsLoading() =>
          const Center(child: CircularProgressIndicator()),
        PrintLabelsFailure(:final error) => Center(
            child: Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        PrintLabelsSuccess(:final results) => results.isEmpty
            ? const Center(child: Text('Sin resultados'))
            : ListView.separated(
                itemCount: results.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _ArticleCard(
                  article: results[i],
                  rowsFocusNode: i == 0 ? rowsFocusNode : null,
                  onPrinted: onPrinted,
                ),
              ),
      },
    );
  }
}

class _ArticleCard extends StatefulWidget {
  final ArticleResult article;
  final FocusNode? rowsFocusNode;
  final VoidCallback onPrinted;

  const _ArticleCard({
    required this.article,
    required this.onPrinted,
    this.rowsFocusNode,
  });

  @override
  State<_ArticleCard> createState() => _ArticleCardState();
}

class _ArticleCardState extends State<_ArticleCard> {
  late final TextEditingController _countController;

  int get _maxRows => (widget.article.quantityAvailable / 2).ceil();

  @override
  void initState() {
    super.initState();
    _countController = TextEditingController(text: '$_maxRows');
  }

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  Future<void> _print() async {
    final count = (int.tryParse(_countController.text) ?? 1).clamp(1, _maxRows);
    await printArticleLabels(widget.article, count);
    widget.onPrinted();
  }

  void _decrement() {
    final v = int.tryParse(_countController.text) ?? 1;
    if (v > 1) _countController.text = '${v - 1}';
  }

  void _increment() {
    final v = int.tryParse(_countController.text) ?? 1;
    if (v < _maxRows) _countController.text = '${v + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final isAvailable = widget.article.quantityAvailable > 0;

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
            // Header row: info + quantity badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.article.description,
                        style: textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.article.model,
                        style: textTheme.bodyMedium
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.article.classification,
                        style: textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                _QuantityBadge(
                  quantity: widget.article.quantityAvailable,
                  isAvailable: isAvailable,
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Price + Barcode row
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _InfoTile(
                  label: 'Precio',
                  value: currency.format(widget.article.price),
                  valueStyle: textTheme.headlineSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 40),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Código de Barras',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    BarcodeDisplay(
                      data: widget.article.barcode,
                      width: 180,
                      height: 72,
                    ),
                  ],
                ),
              ],
            ),

            // Print controls (only when quantity > 0)
            if (isAvailable) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton.outlined(
                    onPressed: _decrement,
                    icon: const Icon(Icons.remove, size: 16),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 72,
                    child: TextField(
                      controller: _countController,
                      focusNode: widget.rowsFocusNode,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onSubmitted: (_) => _print(),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        labelText: 'Filas',
                        helperText: 'Máx $_maxRows',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    onPressed: _increment,
                    icon: const Icon(Icons.add, size: 16),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: _print,
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text('Imprimir'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuantityBadge extends StatelessWidget {
  final int quantity;
  final bool isAvailable;

  const _QuantityBadge({required this.quantity, required this.isAvailable});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = isAvailable
        ? colorScheme.primaryContainer
        : colorScheme.errorContainer;
    final fg = isAvailable
        ? colorScheme.onPrimaryContainer
        : colorScheme.onErrorContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            '$quantity',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700, color: fg),
          ),
          Text('Cantidad', style: TextStyle(fontSize: 11, color: fg)),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _InfoTile({required this.label, required this.value, this.valueStyle});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: valueStyle ??
              textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
