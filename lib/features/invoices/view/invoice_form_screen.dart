import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../di/service_locator.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../../l10n/l10n.dart';
import '../../../services/receipt_printer_service.dart';
import '../cubit/invoice_detail_cubit.dart';
import '../cubit/invoice_form_cubit.dart';
import '../model/invoice_models.dart';
import '../utils/receipt_pdf.dart' as receipt_pdf;

final _money = NumberFormat.currency(symbol: '₡', decimalDigits: 2);

class InvoiceFormScreen extends StatelessWidget {
  /// If non-null, edits the existing invoice; otherwise creates a new one.
  final String? editingInvoiceId;

  const InvoiceFormScreen({super.key, this.editingInvoiceId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<InvoiceFormCubit>(
      create: (_) {
        final cubit =
            InvoiceFormCubit(sl(), editingInvoiceId: editingInvoiceId);
        if (editingInvoiceId != null) {
          // Pre-load the invoice via a separate detail call.
          final detailCubit = InvoiceDetailCubit(sl(), editingInvoiceId!)
            ..load();
          detailCubit.stream.listen((s) {
            if (s is InvoiceDetailSuccess) {
              cubit.seedFromDetail(s.invoice);
            }
          });
        }
        return cubit;
      },
      child: const _InvoiceFormView(),
    );
  }
}

class _InvoiceFormView extends StatelessWidget {
  const _InvoiceFormView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isEdit = context.read<InvoiceFormCubit>().editingInvoiceId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? l10n.invoiceDetailTitle : l10n.invoiceCreateTitle),
      ),
      body: BlocConsumer<InvoiceFormCubit, InvoiceFormState>(
        listenWhen: (p, n) =>
            p.createdInvoiceId != n.createdInvoiceId &&
            n.createdInvoiceId != null,
        listener: (context, state) async {
          final cubit = context.read<InvoiceFormCubit>();
          final messenger = ScaffoldMessenger.of(context);
          final l10nLocal = context.l10n;
          final auth = context.read<AuthCubit>().state;
          final createdBy = auth is AuthAuthenticated ? auth.username : null;
          final id = state.createdInvoiceId!;

          messenger.showSnackBar(
            SnackBar(content: Text('${l10nLocal.invoiceCreated}: #$id')),
          );

          // Build receipt + print or open it.
          try {
            final bytes = await receipt_pdf.buildReceiptPdf(
              invoiceId: id,
              date: state.date,
              clientName: state.clientName,
              clientId: state.clientId,
              notes: state.notes,
              items: state.items,
              createdBy: createdBy,
            );
            final printer = sl<ReceiptPrinterService>();
            final printed = await printer.printPdf(bytes, name: 'invoice_$id');
            if (printed) {
              // Second copy.
              await printer.printPdf(bytes, name: 'invoice_${id}_copy');
            } else {
              await receipt_pdf.openReceiptPdf(bytes, id);
            }
          } catch (e) {
            messenger.showSnackBar(
              SnackBar(content: Text('Receipt error: $e')),
            );
          }

          // Reset only after we've consumed the items snapshot.
          if (cubit.editingInvoiceId == null) {
            cubit.resetForm();
          } else {
            cubit.acknowledgeCreated();
          }
        },
        builder: (context, state) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeaderBar(state: state),
                const SizedBox(height: 12),
                _LookupBar(state: state),
                const SizedBox(height: 12),
                Expanded(child: _LinesAndTotals(state: state, isEdit: isEdit)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// HEADER: client + date + notes (top bar)
// =============================================================================

class _HeaderBar extends StatefulWidget {
  final InvoiceFormState state;
  const _HeaderBar({required this.state});

  @override
  State<_HeaderBar> createState() => _HeaderBarState();
}

class _HeaderBarState extends State<_HeaderBar> {
  final _clientNameCtrl = TextEditingController();
  final _clientIdCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _seeded = false;

  @override
  void didUpdateWidget(covariant _HeaderBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_seeded &&
        (widget.state.clientName.isNotEmpty ||
            widget.state.clientId.isNotEmpty ||
            widget.state.notes.isNotEmpty)) {
      _clientNameCtrl.text = widget.state.clientName;
      _clientIdCtrl.text = widget.state.clientId;
      _notesCtrl.text = widget.state.notes;
      _seeded = true;
    }
  }

  @override
  void dispose() {
    _clientNameCtrl.dispose();
    _clientIdCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = widget.state;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _clientNameCtrl,
                decoration: InputDecoration(
                  labelText: l10n.invoiceClientName,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: context.read<InvoiceFormCubit>().setClientName,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _clientIdCtrl,
                decoration: InputDecoration(
                  labelText: l10n.invoiceClientId,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: context.read<InvoiceFormCubit>().setClientId,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.invoiceDate,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                child: Text(DateFormat('yyyy-MM-dd').format(state.date)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: TextField(
                controller: _notesCtrl,
                decoration: InputDecoration(
                  labelText: l10n.invoiceNotes,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: context.read<InvoiceFormCubit>().setNotes,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// LOOKUP: code/barcode input bar
// =============================================================================

class _LookupBar extends StatefulWidget {
  final InvoiceFormState state;
  const _LookupBar({required this.state});

  @override
  State<_LookupBar> createState() => _LookupBarState();
}

class _LookupBarState extends State<_LookupBar> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void didUpdateWidget(covariant _LookupBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.lookupLoading &&
        !widget.state.lookupLoading &&
        widget.state.lookupError == null) {
      _ctrl.clear();
      _focus.requestFocus();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _ctrl.text.trim();
    if (code.isEmpty) return;
    context.read<InvoiceFormCubit>().lookupItem(code);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = widget.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                enabled: !state.lookupLoading,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.invoiceItemLookupLabel,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: state.lookupLoading ? null : _submit,
              icon: state.lookupLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add),
              label: Text(l10n.invoiceAdd),
            ),
          ],
        ),
        if (state.lookupError == 'not_found')
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l10n.invoiceItemNotFound,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          )
        else if (state.lookupError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              state.lookupError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// LINE ITEMS + totals + submit
// =============================================================================

class _LinesAndTotals extends StatelessWidget {
  final InvoiceFormState state;
  final bool isEdit;
  const _LinesAndTotals({required this.state, required this.isEdit});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: state.items.isEmpty
              ? Center(
                  child: Text(
                    l10n.invoiceNoItems,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                )
              : _LineItemsTable(items: state.items),
        ),
        const Divider(),
        _TotalsBar(
          subtotal: state.subtotal,
          discount: state.discountAmount,
          total: state.total,
        ),
        const SizedBox(height: 8),
        if (state.submitError != null) ...[
          Text(
            state.submitError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
        ],
        FilledButton(
          onPressed: state.items.isEmpty || state.submitting
              ? null
              : () => context.read<InvoiceFormCubit>().submit(),
          child: state.submitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEdit ? l10n.invoiceSave : l10n.invoiceCreate),
        ),
      ],
    );
  }
}

class _LineItemsTable extends StatelessWidget {
  final List<InvoiceLineItem> items;
  const _LineItemsTable({required this.items});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          const DataColumn(label: Text('#')),
          DataColumn(label: Text(l10n.invoiceDescription)),
          DataColumn(label: Text(l10n.invoiceCode)),
          DataColumn(label: Text(l10n.invoiceBarcode)),
          const DataColumn(label: Text('TICA')),
          DataColumn(label: Text(l10n.invoiceQty)),
          DataColumn(label: Text(l10n.invoiceUnitPrice)),
          DataColumn(label: Text(l10n.invoiceDiscountPct)),
          DataColumn(label: Text(l10n.invoiceLineTotal)),
          const DataColumn(label: Text('')),
        ],
        rows: [
          for (var i = 0; i < items.length; i++)
            DataRow(cells: [
              DataCell(Text('${i + 1}')),
              DataCell(SizedBox(width: 200, child: Text(items[i].description))),
              DataCell(Text(items[i].sitsaCode)),
              DataCell(Text(items[i].barcode ?? '')),
              DataCell(_TicaCell(tica: items[i].tica)),
              DataCell(_NumberCell(
                value: items[i].quantity,
                onChanged: (v) =>
                    context.read<InvoiceFormCubit>().updateLineQty(i, v),
              )),
              DataCell(_NumberCell(
                value: items[i].unitPrice,
                onChanged: (v) => context
                    .read<InvoiceFormCubit>()
                    .updateLineUnitPrice(i, v),
              )),
              DataCell(_DiscountCell(
                index: i,
                value: items[i].discountPct,
              )),
              DataCell(Text(_money.format(items[i].lineTotal))),
              DataCell(IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () =>
                    context.read<InvoiceFormCubit>().removeLine(i),
              )),
            ]),
        ],
      ),
    );
  }
}

class _TicaCell extends StatelessWidget {
  final String? tica;
  const _TicaCell({required this.tica});

  @override
  Widget build(BuildContext context) {
    if (tica == null || tica!.isEmpty) return const Text('');
    final isZero = tica!.trim() == '0/0';
    return Text(
      tica!,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: isZero ? Colors.green : Colors.red,
      ),
    );
  }
}

class _NumberCell extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;
  const _NumberCell({required this.value, required this.onChanged});

  @override
  State<_NumberCell> createState() => _NumberCellState();
}

class _NumberCellState extends State<_NumberCell> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _fmt(widget.value));
  }

  @override
  void didUpdateWidget(covariant _NumberCell old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value && _fmt(widget.value) != _ctrl.text) {
      _ctrl.text = _fmt(widget.value);
    }
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: TextField(
        controller: _ctrl,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(isDense: true),
        onSubmitted: (s) {
          final v = double.tryParse(s);
          if (v != null) widget.onChanged(v);
        },
      ),
    );
  }
}

class _DiscountCell extends StatefulWidget {
  final int index;
  final double value;
  const _DiscountCell({required this.index, required this.value});

  @override
  State<_DiscountCell> createState() => _DiscountCellState();
}

class _DiscountCellState extends State<_DiscountCell> {
  late TextEditingController _ctrl;
  late double _previous;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value.toString());
    _previous = widget.value;
  }

  @override
  void didUpdateWidget(covariant _DiscountCell old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value && widget.value.toString() != _ctrl.text) {
      _ctrl.text = widget.value.toString();
      _previous = widget.value;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _commit(String s) async {
    final v = double.tryParse(s);
    if (v == null) return;
    if (v > 15) {
      final ok = await _showManagerAuthDialog(context, v);
      if (!ok) {
        _ctrl.text = _previous.toString();
        return;
      }
    }
    _previous = v;
    if (mounted) {
      context.read<InvoiceFormCubit>().updateLineDiscount(widget.index, v);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      child: TextField(
        controller: _ctrl,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(isDense: true),
        onSubmitted: _commit,
      ),
    );
  }
}

class _TotalsBar extends StatelessWidget {
  final double subtotal;
  final double discount;
  final double total;
  const _TotalsBar({
    required this.subtotal,
    required this.discount,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ts = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _row(l10n.invoiceSubtotal, _money.format(subtotal), ts.bodyMedium!),
          _row(l10n.invoiceDiscount, _money.format(discount), ts.bodyMedium!),
          const Divider(),
          _row(l10n.invoiceTotal, _money.format(total),
              ts.titleMedium!.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _row(String label, String value, TextStyle style) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(label, style: style),
            const SizedBox(width: 16),
            SizedBox(
              width: 140,
              child: Text(value, style: style, textAlign: TextAlign.right),
            ),
          ],
        ),
      );
}

// =============================================================================
// Manager authorization dialog
// =============================================================================

Future<bool> _showManagerAuthDialog(
    BuildContext context, double discount) async {
  final cubit = context.read<InvoiceFormCubit>();
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _ManagerAuthDialog(discount: discount),
    ),
  );
  return result ?? false;
}

class _ManagerAuthDialog extends StatefulWidget {
  final double discount;
  const _ManagerAuthDialog({required this.discount});

  @override
  State<_ManagerAuthDialog> createState() => _ManagerAuthDialogState();
}

class _ManagerAuthDialogState extends State<_ManagerAuthDialog> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _authorize() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await context.read<InvoiceFormCubit>().authorizeDiscount(
          username: _userCtrl.text.trim(),
          password: _passCtrl.text,
          discount: widget.discount,
        );
    if (!mounted) return;
    if (err == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.invoiceManagerAuthTitle),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.invoiceManagerAuthBody),
            const SizedBox(height: 12),
            TextField(
              controller: _userCtrl,
              decoration: InputDecoration(
                labelText: l10n.invoiceManagerUsername,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.invoiceManagerPassword,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _busy ? null : _authorize,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.invoiceAuthorize),
        ),
      ],
    );
  }
}
