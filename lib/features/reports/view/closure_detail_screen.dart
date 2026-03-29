import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../di/service_locator.dart';
import '../../../features/auth/cubit/auth_cubit.dart';
import '../../../l10n/l10n.dart';
import '../cubit/closure_detail_cubit.dart';
import '../utils/closure_pdf.dart' as closure_pdf;

class ClosureDetailScreen extends StatelessWidget {
  final String closureId;
  const ClosureDetailScreen({super.key, required this.closureId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ClosureDetailCubit(sl())..load(closureId),
      child: const _ClosureDetailView(),
    );
  }
}

class _ClosureDetailView extends StatelessWidget {
  const _ClosureDetailView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_outlined),
                tooltip: context.l10n.tooltipBack,
              ),
              const SizedBox(width: 8),
              Text(context.l10n.closureDetailTitle,
                  style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              BlocBuilder<ClosureDetailCubit, ClosureDetailState>(
                builder: (context, state) => state is ClosureDetailLoaded
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (context.select((AuthCubit c) =>
                              c.state is AuthAuthenticated &&
                              (c.state as AuthAuthenticated)
                                  .hasPrivilege('edit_closure')))
                          IconButton.outlined(
                            onPressed: () => showDialog(
                              context: context,
                              builder: (_) => _EditClosureDialog(
                                closure: state.closure,
                                onSave: (payload) => context
                                    .read<ClosureDetailCubit>()
                                    .update('${state.closure['id']}', payload),
                              ),
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: context.l10n.tooltipEdit,
                          ),
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            onPressed: () async {
                          try {
                            final path = await closure_pdf
                                .generateAndOpenClosure(state.closure);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(context.l10n.msgSavedAt(path))),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(context.l10n.msgErrorDetail(e.toString()))),
                              );
                            }
                          }
                        },
                            icon: const Icon(Icons.print_outlined, size: 18),
                            tooltip: context.l10n.btnPrint,
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: BlocBuilder<ClosureDetailCubit, ClosureDetailState>(
              builder: (context, state) => switch (state) {
                ClosureDetailLoading() =>
                  const Center(child: CircularProgressIndicator()),
                ClosureDetailFailure(:final error) => Center(
                    child: Text(error,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))),
                ClosureDetailLoaded(:final closure) =>
                  _ClosureDetailBody(closure: closure),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ClosureDetailBody extends StatelessWidget {
  final Map<String, dynamic> closure;

  const _ClosureDetailBody({required this.closure});

  static Map<String, dynamic> _map(dynamic value) =>
      Map<String, dynamic>.from(value as Map? ?? {});

  static List<Map<String, dynamic>> _list(dynamic value) =>
      ((value as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  @override
  Widget build(BuildContext context) {
    final colones = NumberFormat.currency(symbol: '₡', decimalDigits: 2);
    final pctFmt = NumberFormat('0.00');
    final dateFmt = DateFormat('MMM d, yyyy');
    final numFmt = NumberFormat.decimalPattern();

    final dateRaw = closure['date'] as String?;
    final date = dateRaw != null ? dateFmt.format(DateTime.parse(dateRaw)) : '—';
    final createdBy = closure['created_by'] as String? ?? '—';

    final general = _map(closure['general']);
    final calc = _map(closure['calculations']);
    final invoices = _list(closure['invoices']);
    final deposits = _list(closure['deposits']);
    final cards = _list(closure['card_charges']);
    final prevInv = num.tryParse('${closure['prev_inventory_cost'] ?? ''}')?.toDouble();
    final invCost = num.tryParse('${closure['inventory_cost'] ?? ''}')?.toDouble();

    final ventaNeta = (calc['ventaNeta'] as num?)?.toDouble();
    final pct = (calc['discountPct'] as num?)?.toDouble();
    final dif = (calc['diferenciaADepositar'] as num?)?.toDouble();

    final l10n = context.l10n;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Meta ───────────────────────────────────────────────────────
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Tile(label: l10n.colFecha, value: date),
              _Tile(label: l10n.labelCreadoPor, value: createdBy),
              if (prevInv != null)
                _Tile(label: l10n.colInvAnterior, value: colones.format(prevInv)),
              if (invCost != null)
                _Tile(label: l10n.tileCostoInventario, value: colones.format(invCost), highlight: true),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),

          // ── General ────────────────────────────────────────────────────
          _SectionTitle(l10n.sectionGeneral),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (general['BrutTotal'] != null)
                _Tile(label: l10n.tileBruto, value: colones.format((general['BrutTotal'] as num).toDouble())),
              if (general['TotalBonos'] != null)
                _Tile(label: l10n.tileBonos, value: colones.format((general['TotalBonos'] as num).toDouble())),
              if (general['TotalDiscount'] != null)
                _Tile(label: l10n.tileDescuentos, value: colones.format((general['TotalDiscount'] as num).toDouble())),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),

          // ── Calculations ───────────────────────────────────────────────
          _SectionTitle(l10n.sectionCalculos),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (ventaNeta != null)
                _Tile(label: l10n.tileVentaNeta, value: colones.format(ventaNeta), highlight: true),
              if (pct != null)
                _Tile(label: l10n.tilePctDescuento, value: '${pctFmt.format(pct)}%'),
              if (dif != null)
                _Tile(
                  label: l10n.labelDifDepositar,
                  value: colones.format(dif),
                  highlight: true,
                  error: dif < 0,
                ),
            ],
          ),

          // ── Deposits ───────────────────────────────────────────────────
          if (deposits.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionTitle(l10n.labelDepositosBancarios),
            const SizedBox(height: 12),
            _SimpleTable(
              columns: [l10n.colNoDeposito, l10n.labelBanco, l10n.colMoneda, l10n.labelTC, l10n.labelMonto],
              rows: deposits.map((d) => [
                '${d['depositNo'] ?? '—'}',
                '${d['bank'] ?? '—'}',
                '${d['currency'] ?? '—'}',
                d['exchangeRate'] != null ? '${d['exchangeRate']}' : '—',
                d['amount'] != null
                    ? colones.format((d['amount'] as num).toDouble())
                    : '—',
              ]).toList(),
            ),
          ],

          // ── Card charges ───────────────────────────────────────────────
          if (cards.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionTitle(l10n.labelCobrosConTarjeta),
            const SizedBox(height: 12),
            _SimpleTable(
              columns: [l10n.labelBanco, l10n.labelMonto],
              rows: cards.map((c) => [
                '${c['bank'] ?? '—'}',
                c['amount'] != null
                    ? colones.format((c['amount'] as num).toDouble())
                    : '—',
              ]).toList(),
            ),
          ],

          // ── Invoices ───────────────────────────────────────────────────
          if (invoices.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionTitle(l10n.labelRangosFacturas),
            const SizedBox(height: 12),
            _SimpleTable(
              columns: [l10n.colRangoInicio, l10n.colRangoFin, l10n.colTotal],
              rows: invoices.map((inv) => [
                '${inv['RangeStart'] ?? '—'}',
                '${inv['RangeEnd'] ?? '—'}',
                '${inv['Total'] ?? '—'}',
              ]).toList(),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600));
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final bool error;

  const _Tile({
    required this.label,
    required this.value,
    this.highlight = false,
    this.error = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final bg = error
        ? colorScheme.errorContainer
        : highlight
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerLow;
    final fg = error
        ? colorScheme.onErrorContainer
        : highlight
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurface;
    final labelColor = error
        ? colorScheme.onErrorContainer.withOpacity(0.7)
        : highlight
            ? colorScheme.onPrimaryContainer.withOpacity(0.7)
            : colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: (!highlight && !error)
            ? Border.all(color: colorScheme.outlineVariant)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: textTheme.labelSmall?.copyWith(color: labelColor)),
          const SizedBox(height: 4),
          Text(value,
              style: textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}

class _SimpleTable extends StatelessWidget {
  final List<String> columns;
  final List<List<String>> rows;

  const _SimpleTable({required this.columns, required this.rows});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: columns
                    .map((c) => Expanded(
                          child: Text(c,
                              style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600)),
                        ))
                    .toList(),
              ),
            ),
            const Divider(height: 1),
            ...rows.asMap().entries.map((entry) {
              final i = entry.key;
              final row = entry.value;
              return Container(
                color: i.isOdd ? colorScheme.surfaceContainerLowest : null,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                child: Row(
                  children: row
                      .map((cell) => Expanded(
                            child: Text(cell,
                                style: textTheme.bodySmall),
                          ))
                      .toList(),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Edit dialog ───────────────────────────────────────────────────────────────

class _EditClosureDialog extends StatefulWidget {
  final Map<String, dynamic> closure;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _EditClosureDialog({required this.closure, required this.onSave});

  @override
  State<_EditClosureDialog> createState() => _EditClosureDialogState();
}

class _EditClosureDialogState extends State<_EditClosureDialog> {
  late final TextEditingController _invCost;
  late final TextEditingController _prevInvCost;
  late final List<_DepositCtrl> _deposits;
  late final List<_CardCtrl> _cards;
  bool _saving = false;

  double _parse(String t) =>
      double.tryParse(t.replaceAll(',', '')) ?? 0.0;

  double get _ventaNeta {
    final calc = widget.closure['calculations'] as Map? ?? {};
    return num.tryParse('${calc['ventaNeta'] ?? ''}')?.toDouble() ?? 0.0;
  }

  double get _diferencia {
    final totalCards =
        _cards.fold(0.0, (s, c) => s + _parse(c.amount.text));
    final totalDeposits = _deposits.fold(0.0, (s, d) {
      final amount = _parse(d.amount.text);
      if (d.currency == 'USD') {
        final rate = _parse(d.exchangeRate.text);
        return s + (rate > 0 ? amount * rate : amount);
      }
      return s + amount;
    });
    return _ventaNeta - totalCards - totalDeposits;
  }

  void _rebuild() => setState(() {});

  void _attachListeners(_DepositCtrl d) {
    d.amount.addListener(_rebuild);
    d.exchangeRate.addListener(_rebuild);
  }

  void _attachCardListeners(_CardCtrl c) {
    c.amount.addListener(_rebuild);
  }

  @override
  void initState() {
    super.initState();
    _invCost = TextEditingController(
        text: '${widget.closure['inventory_cost'] ?? ''}');
    _prevInvCost = TextEditingController(
        text: '${widget.closure['prev_inventory_cost'] ?? ''}');

    _deposits = ((widget.closure['deposits'] as List?) ?? [])
        .map((e) => _DepositCtrl.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    for (final d in _deposits) _attachListeners(d);

    _cards = ((widget.closure['card_charges'] as List?) ?? [])
        .map((e) => _CardCtrl.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    for (final c in _cards) _attachCardListeners(c);
  }

  @override
  void dispose() {
    _invCost.dispose();
    _prevInvCost.dispose();
    for (final d in _deposits) d.dispose();
    for (final c in _cards) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final existingCalc = Map<String, dynamic>.from(
          widget.closure['calculations'] as Map? ?? {});

      final payload = {
        'inventory_cost': _parse(_invCost.text),
        'prev_inventory_cost': _parse(_prevInvCost.text),
        'deposits': _deposits.map((d) => {
          'depositNo': d.depositNo.text,
          'bank': d.bank == 'Custom' ? d.customBank.text : d.bank,
          'currency': d.currency,
          'exchangeRate': d.currency == 'USD'
              ? double.tryParse(d.exchangeRate.text)
              : null,
          'amount': _parse(d.amount.text),
        }).toList(),
        'card_charges': _cards.map((c) => {
          'bank': c.bank == 'Custom' ? c.customBank.text : c.bank,
          'amount': _parse(c.amount.text),
        }).toList(),
        'calculations': {
          ...existingCalc,
          'diferenciaADepositar': _diferencia,
        },
      };
      await widget.onSave(payload);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
              child: Row(
                children: [
                  Text(context.l10n.editClosureTitle,
                      style: textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Inventory costs
                    _DialogSection(title: context.l10n.labelCostosInventario),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _DField(
                            label: context.l10n.labelCostoInventarioField,
                            controller: _invCost,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DField(
                            label: context.l10n.labelInventarioAnteriorField,
                            controller: _prevInvCost,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Deposits
                    Row(
                      children: [
                        _DialogSection(title: context.l10n.labelDepositosBancarios),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            final d = _DepositCtrl();
                            _attachListeners(d);
                            _deposits.add(d);
                          }),
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(context.l10n.btnAdd),
                          style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._deposits.asMap().entries.map((e) => _DepositRow(
                          key: ObjectKey(e.value),
                          ctrl: e.value,
                          onChanged: _rebuild,
                          onRemove: () =>
                              setState(() => _deposits.removeAt(e.key)),
                        )),
                    if (_deposits.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(context.l10n.msgNoDeposits,
                            style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 13)),
                      ),
                    const SizedBox(height: 20),

                    // Card charges
                    Row(
                      children: [
                        _DialogSection(title: context.l10n.labelCobrosConTarjeta),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            final c = _CardCtrl();
                            _attachCardListeners(c);
                            _cards.add(c);
                          }),
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(context.l10n.btnAdd),
                          style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._cards.asMap().entries.map((e) => _CardRow(
                          key: ObjectKey(e.value),
                          ctrl: e.value,
                          onChanged: _rebuild,
                          onRemove: () =>
                              setState(() => _cards.removeAt(e.key)),
                        )),
                    if (_cards.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(context.l10n.msgNoCardCharges,
                            style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 13)),
                      ),
                  ],
                ),
              ),
            ),
            const Divider(),
            // Live diferencia
            Builder(builder: (context) {
              final colorScheme = Theme.of(context).colorScheme;
              final textTheme = Theme.of(context).textTheme;
              final dif = _diferencia;
              final fmt = NumberFormat.currency(symbol: '₡', decimalDigits: 2);
              return Container(
                color: colorScheme.surfaceContainerLow,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Row(
                  children: [
                    Text(context.l10n.labelDifDepositar,
                        style: textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant)),
                    const Spacer(),
                    Text(
                      fmt.format(dif),
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: dif < 0 ? colorScheme.error : colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              );
            }),
            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: Text(context.l10n.btnCancel),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.l10n.btnSave),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dialog helpers ─────────────────────────────────────────────────────────────

class _DialogSection extends StatelessWidget {
  final String title;
  const _DialogSection({required this.title});

  @override
  Widget build(BuildContext context) => Text(title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant));
}

class _DField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool numeric;

  const _DField({
    required this.label,
    required this.controller,
    this.numeric = true,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        inputFormatters: numeric
            ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
            : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
      );
}

// ── Deposit controller + row ──────────────────────────────────────────────────

class _DepositCtrl {
  final TextEditingController depositNo;
  final TextEditingController amount;
  final TextEditingController customBank;
  final TextEditingController exchangeRate;
  String bank;
  String currency;

  _DepositCtrl()
      : depositNo = TextEditingController(),
        amount = TextEditingController(),
        customBank = TextEditingController(),
        exchangeRate = TextEditingController(),
        bank = 'BCR',
        currency = 'CRC';

  factory _DepositCtrl.fromMap(Map<String, dynamic> m) {
    final ctrl = _DepositCtrl();
    ctrl.depositNo.text = '${m['depositNo'] ?? ''}';
    ctrl.amount.text = '${m['amount'] ?? ''}';
    ctrl.currency = m['currency'] as String? ?? 'CRC';
    ctrl.exchangeRate.text = '${m['exchangeRate'] ?? ''}';
    final bank = m['bank'] as String? ?? 'BCR';
    if (bank == 'BCR' || bank == 'BN') {
      ctrl.bank = bank;
    } else {
      ctrl.bank = 'Custom';
      ctrl.customBank.text = bank;
    }
    return ctrl;
  }

  void dispose() {
    depositNo.dispose();
    amount.dispose();
    customBank.dispose();
    exchangeRate.dispose();
  }
}

class _DepositRow extends StatefulWidget {
  final _DepositCtrl ctrl;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _DepositRow({required this.ctrl, required this.onRemove, required this.onChanged, super.key});

  @override
  State<_DepositRow> createState() => _DepositRowState();
}

class _DepositRowState extends State<_DepositRow> {
  static const _banks = ['BCR', 'BN', 'Custom'];
  static const _currencies = ['CRC', 'USD'];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final c = widget.ctrl;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _DField(label: context.l10n.labelNumDeposito, controller: c.depositNo, numeric: false)),
              const SizedBox(width: 8),
              Expanded(child: _DField(label: context.l10n.labelMonto, controller: c.amount)),
              IconButton(
                onPressed: widget.onRemove,
                icon: Icon(Icons.remove_circle_outline,
                    size: 18, color: colorScheme.error),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _SegPicker(
                options: _banks,
                selected: c.bank,
                onSelected: (v) { setState(() => c.bank = v); widget.onChanged(); },
              ),
              if (c.bank == 'Custom') ...[
                const SizedBox(width: 8),
                Expanded(child: _DField(label: context.l10n.labelBanco, controller: c.customBank, numeric: false)),
              ],
              const Spacer(),
              _SegPicker(
                options: _currencies,
                selected: c.currency,
                onSelected: (v) { setState(() => c.currency = v); widget.onChanged(); },
              ),
              if (c.currency == 'USD') ...[
                const SizedBox(width: 8),
                SizedBox(width: 80, child: _DField(label: context.l10n.labelTC, controller: c.exchangeRate)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Card controller + row ─────────────────────────────────────────────────────

class _CardCtrl {
  final TextEditingController amount;
  final TextEditingController customBank;
  String bank;

  _CardCtrl()
      : amount = TextEditingController(),
        customBank = TextEditingController(),
        bank = 'BCR';

  factory _CardCtrl.fromMap(Map<String, dynamic> m) {
    final ctrl = _CardCtrl();
    ctrl.amount.text = '${m['amount'] ?? ''}';
    final bank = m['bank'] as String? ?? 'BCR';
    if (bank == 'BCR' || bank == 'Promerica') {
      ctrl.bank = bank;
    } else {
      ctrl.bank = 'Custom';
      ctrl.customBank.text = bank;
    }
    return ctrl;
  }

  void dispose() {
    amount.dispose();
    customBank.dispose();
  }
}

class _CardRow extends StatefulWidget {
  final _CardCtrl ctrl;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _CardRow({required this.ctrl, required this.onRemove, required this.onChanged, super.key});

  @override
  State<_CardRow> createState() => _CardRowState();
}

class _CardRowState extends State<_CardRow> {
  static const _banks = ['BCR', 'Promerica', 'Custom'];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final c = widget.ctrl;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          _SegPicker(
            options: _banks,
            selected: c.bank,
            onSelected: (v) { setState(() => c.bank = v); widget.onChanged(); },
          ),
          if (c.bank == 'Custom') ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 110,
              child: _DField(label: context.l10n.labelBanco, controller: c.customBank, numeric: false),
            ),
          ],
          const SizedBox(width: 8),
          Expanded(child: _DField(label: context.l10n.labelMonto, controller: c.amount)),
          IconButton(
            onPressed: widget.onRemove,
            icon: Icon(Icons.remove_circle_outline,
                size: 18, color: colorScheme.error),
          ),
        ],
      ),
    );
  }
}

// ── Segmented picker ──────────────────────────────────────────────────────────

class _SegPicker extends StatelessWidget {
  final List<String> options;
  final String selected;
  final void Function(String) onSelected;

  const _SegPicker({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: options.map((opt) {
        final isSel = opt == selected;
        return GestureDetector(
          onTap: () => onSelected(opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isSel ? colorScheme.primary : colorScheme.surfaceContainerLow,
              border: Border.all(
                  color: isSel ? colorScheme.primary : colorScheme.outline),
              borderRadius: BorderRadius.horizontal(
                left: opt == options.first
                    ? const Radius.circular(6)
                    : Radius.zero,
                right: opt == options.last
                    ? const Radius.circular(6)
                    : Radius.zero,
              ),
            ),
            child: Text(opt,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSel ? colorScheme.onPrimary : colorScheme.onSurface,
                )),
          ),
        );
      }).toList(),
    );
  }
}
