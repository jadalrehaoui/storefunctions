import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../di/service_locator.dart';
import '../../../l10n/l10n.dart';
import '../../../models/combined_item.dart';
import '../../../shared/utils/label_printer.dart';
import '../../../shared/utils/privilege_helpers.dart';
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

  void _submit() => context.read<PrintLabelsCubit>().search(_controller.text);

  void _showCustomLabelDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const _CustomLabelDialog(),
    );
  }

  void _onPrinted() {
    context.read<PrintLabelsCubit>().reset();
    _controller.clear();
    _searchFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PrintLabelsCubit, PrintLabelsState>(
      listener: (context, state) {
        if (state is PrintLabelsSuccess) {
          _rowsFocusNode.requestFocus();
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  context.l10n.inventoryPrintLabelsTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => _showCustomLabelDialog(context),
                  icon: const Icon(Icons.edit_note, size: 18),
                  label: Text(context.l10n.btnCustomLabel),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      labelText: context.l10n.searchFieldLabel,
                      prefixIcon: const Icon(Icons.qr_code),
                      border: const OutlineInputBorder(),
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
                  label: Text(context.l10n.btnSearch),
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
        PrintLabelsSuccess(:final item) => _CombinedItemCard(
            item: item,
            rowsFocusNode: rowsFocusNode,
            onPrinted: onPrinted,
          ),
      },
    );
  }
}

class _CombinedItemCard extends StatefulWidget {
  final CombinedItem item;
  final FocusNode rowsFocusNode;
  final VoidCallback onPrinted;

  const _CombinedItemCard({
    required this.item,
    required this.rowsFocusNode,
    required this.onPrinted,
  });

  @override
  State<_CombinedItemCard> createState() => _CombinedItemCardState();
}

class _CombinedItemCardState extends State<_CombinedItemCard> {
  late final TextEditingController _countController;

  int get _quantity {
    final d = widget.item.sitsa?.disponible;
    if (d != null) return d.toInt();
    return widget.item.mikail?.existencia.toInt() ?? 0;
  }

  int get _maxRows => (_quantity / 2).ceil().clamp(1, 9999);

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
    await printCombinedLabel(widget.item, count);
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
    final sitsa = widget.item.sitsa;
    final mikail = widget.item.mikail;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final colones = NumberFormat.currency(symbol: '₡', decimalDigits: 2);

    final sitsaPrice =
        sitsa != null ? sitsa.costo + sitsa.costo * sitsa.ganancia / 100 : 0.0;
    final barcode = sitsa?.codigoBarras ?? '';
    final canPrint = barcode.isNotEmpty && _quantity > 0;

    return SingleChildScrollView(
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
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sitsa?.description ?? widget.item.code,
                          style: textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (sitsa?.model != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            sitsa!.model,
                            style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                        if (sitsa?.classification != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            sitsa!.classification,
                            style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  _QuantityBadge(
                    quantity: _quantity,
                    isAvailable: _quantity > 0,
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Pricing + barcode row
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Wrap(
                    spacing: 32,
                    runSpacing: 12,
                    children: [
                      if (sitsa != null) ...[
                        _InfoTile(
                          label: context.l10n.labelCosto,
                          value: canSeeProfitMargins(context) ? colones.format(sitsa.costo) : redacted,
                        ),
                        _InfoTile(
                          label: context.l10n.labelPrecio,
                          value: colones.format(sitsaPrice),
                          valueStyle: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const Spacer(),
                  if (barcode.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.labelCodigoBarras,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        BarcodeDisplay(
                          data: barcode,
                          width: 180,
                          height: 72,
                        ),
                      ],
                    ),
                ],
              ),

              // Print controls
              if (canPrint) ...[
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
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        onSubmitted: (_) => _print(),
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          labelText: context.l10n.labelFilas,
                          helperText: context.l10n.helperMaxRows(_maxRows),
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
                      label: Text(context.l10n.btnPrint),
                    ),
                  ],
                ),
              ],
            ],
          ),
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
          Text(context.l10n.labelCantidad, style: TextStyle(fontSize: 11, color: fg)),
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

class _CustomLabelDialog extends StatefulWidget {
  const _CustomLabelDialog();

  @override
  State<_CustomLabelDialog> createState() => _CustomLabelDialogState();
}

class _CustomLabelDialogState extends State<_CustomLabelDialog> {
  final _formKey = GlobalKey<FormState>();
  final _barcodeCtrl = TextEditingController();
  final _articleIdCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _countCtrl = TextEditingController(text: '1');

  bool _printing = false;
  String? _error;

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _articleIdCtrl.dispose();
    _priceCtrl.dispose();
    _descriptionCtrl.dispose();
    _countCtrl.dispose();
    super.dispose();
  }

  Future<void> _print() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _printing = true;
      _error = null;
    });
    try {
      await printCustomLabel(
        barcode: _barcodeCtrl.text.trim(),
        articleId: _articleIdCtrl.text.trim(),
        price: _priceCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        count: int.tryParse(_countCtrl.text) ?? 1,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() { _printing = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.btnCustomLabel),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _barcodeCtrl,
                decoration: InputDecoration(
                  labelText: context.l10n.labelBarcode,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? context.l10n.labelRequired : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _articleIdCtrl,
                decoration: InputDecoration(
                  labelText: context.l10n.labelArticleId,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? context.l10n.labelRequired : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceCtrl,
                decoration: InputDecoration(
                  labelText: context.l10n.labelPrice,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? context.l10n.labelRequired : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionCtrl,
                decoration: InputDecoration(
                  labelText: context.l10n.labelDescription,
                  border: const OutlineInputBorder(),
                  isDense: true,
                  helperText: context.l10n.helperMax28Chars,
                ),
                maxLength: 28,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? context.l10n.labelRequired : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _countCtrl,
                decoration: InputDecoration(
                  labelText: context.l10n.labelFilas,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 1) return context.l10n.validatorMinOne;
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _printing ? null : () => Navigator.of(context).pop(),
          child: Text(context.l10n.btnCancel),
        ),
        FilledButton.icon(
          onPressed: _printing ? null : _print,
          icon: _printing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.print, size: 18),
          label: Text(context.l10n.btnPrint),
        ),
      ],
    );
  }
}
