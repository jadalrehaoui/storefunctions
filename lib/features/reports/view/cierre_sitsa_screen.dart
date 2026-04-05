import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../di/service_locator.dart';
import '../../../features/auth/cubit/auth_cubit.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/utils/privilege_helpers.dart';
import '../cubit/cierre_sitsa_cubit.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class DepositEntry {
  final TextEditingController depositNo;
  final TextEditingController amount;
  final TextEditingController customBank;
  final TextEditingController exchangeRate;
  String bank; // 'BCR' | 'BN' | 'Custom'
  String currency; // 'CRC' | 'USD'

  DepositEntry()
      : depositNo = TextEditingController(),
        amount = TextEditingController(),
        customBank = TextEditingController(),
        exchangeRate = TextEditingController(),
        bank = 'BCR',
        currency = 'CRC';

  String get bankName => bank == 'Custom' ? customBank.text : bank;

  void dispose() {
    depositNo.dispose();
    amount.dispose();
    customBank.dispose();
    exchangeRate.dispose();
  }
}

class CardChargeEntry {
  final TextEditingController amount;
  final TextEditingController customBank;
  String bank; // 'BCR' | 'Promerica' | 'Custom'

  CardChargeEntry()
      : amount = TextEditingController(),
        customBank = TextEditingController(),
        bank = 'BCR';

  String get bankName => bank == 'Custom' ? customBank.text : bank;

  void dispose() {
    amount.dispose();
    customBank.dispose();
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class CierreSitsaScreen extends StatelessWidget {
  const CierreSitsaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CierreSitsaCubit(sl()),
      child: const _CierreSitsaView(),
    );
  }
}

class _CierreSitsaView extends StatefulWidget {
  const _CierreSitsaView();

  @override
  State<_CierreSitsaView> createState() => _CierreSitsaViewState();
}

class _CierreSitsaViewState extends State<_CierreSitsaView> {
  DateTime _date = DateTime.now();
  static final _displayFmt = DateFormat('MMM d, yyyy');

  final _deposits = <DepositEntry>[];
  final _cards = <CardChargeEntry>[];
  String? _closureId;


  double _parse(String text) =>
      double.tryParse(text.replaceAll(',', '')) ?? 0.0;

  Future<void> _savePrevInventory() async {
    final state = context.read<CierreSitsaCubit>().state;
    final data = state is CierreSitsaLoaded ? state.data : null;

    final bruto = data != null ? (data.general['BrutTotal'] as num?)?.toDouble() ?? 0.0 : 0.0;
    final bonos = data != null ? (data.general['TotalBonos'] as num?)?.toDouble() ?? 0.0 : 0.0;
    final discount = data != null ? (data.general['TotalDiscount'] as num?)?.toDouble() ?? 0.0 : 0.0;
    final ventaNeta = bruto - bonos - discount;
    final pctDesc = bruto > 0 ? (bonos + discount) / bruto * 100 : 0.0;
    final totalCards = _cards.fold(0.0, (s, c) => s + _parse(c.amount.text));
    final totalDeposits = _deposits.fold(0.0, (s, d) {
      final amount = _parse(d.amount.text);
      if (d.currency == 'USD') {
        final rate = _parse(d.exchangeRate.text);
        return s + (rate > 0 ? amount * rate : amount);
      }
      return s + amount;
    });
    final diferencia = ventaNeta - totalCards - totalDeposits;

    final payload = {
      'date': DateFormat('yyyy-MM-dd').format(_date),
      'prev_inventory_cost': data?.prevInventoryCost ?? 0.0,
      'general': data?.general,
      'inventory_cost': data?.inventoryCost,
      'invoices': data?.invoices,
      'calculations': {
        'ventaNeta': ventaNeta,
        'discountPct': pctDesc,
        'diferenciaADepositar': diferencia,
      },
      'deposits': _deposits.map((d) => {
        'depositNo': d.depositNo.text,
        'bank': d.bankName,
        'currency': d.currency,
        'exchangeRate': d.currency == 'USD' ? _parse(d.exchangeRate.text) : null,
        'amount': _parse(d.amount.text),
      }).toList(),
      'card_charges': _cards.map((c) => {
        'bank': c.bankName,
        'amount': _parse(c.amount.text),
      }).toList(),
      if (data?.tipoCambio != null) 'bccrtc': data!.tipoCambio!.ventaUsd,
    };

    try {
      final isNew = _closureId == null;
      final id = await context
          .read<CierreSitsaCubit>()
          .saveOrUpdate(payload, closureId: _closureId);
      setState(() => _closureId = id);
      if (mounted) {
        final l10n = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isNew ? l10n.msgSaved : l10n.msgUpdated)),
        );
      }
    } catch (e, st) {
      print('[CierreSitsa] save error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.msgErrorDetail(e.toString()))));
      }
    }
  }

  @override
  void dispose() {
    for (final d in _deposits) d.dispose();
    for (final c in _cards) c.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _generate() {
    context.read<CierreSitsaCubit>().load(_date);
  }

  void _addDeposit() => setState(() => _deposits.add(DepositEntry()));
  void _removeDeposit(int i) => setState(() {
        _deposits[i].dispose();
        _deposits.removeAt(i);
      });

  void _addCard() => setState(() => _cards.add(CardChargeEntry()));
  void _removeCard(int i) => setState(() {
        _cards[i].dispose();
        _cards.removeAt(i);
      });

  Future<void> _download(CierreSitsaData data) async {
    try {
      final path = await context
          .read<CierreSitsaCubit>()
          .download(data, _date, _deposits, _cards, showCosts: canSeeProfitMargins(context));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.msgSavedAt(path))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.msgErrorDetail(e.toString()))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.cierreSitsaTitle,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          // ── Top bar ──────────────────────────────────────────────────────
          Row(
            children: [
              _DateButton(
                  value: _displayFmt.format(_date), onTap: _pickDate),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.play_arrow_outlined, size: 18),
                label: Text(context.l10n.btnGenerate),
              ),
              const SizedBox(width: 12),
              BlocBuilder<CierreSitsaCubit, CierreSitsaState>(
                builder: (context, state) =>
                    state is CierreSitsaLoaded
                        ? IconButton.outlined(
                            onPressed: () => _download(state.data),
                            icon: const Icon(Icons.download_outlined,
                                size: 18),
                            tooltip: context.l10n.tooltipDownloadCsv,
                          )
                        : const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // ── Main content ─────────────────────────────────────────────────
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Report result
                Expanded(
                  flex: 3,
                  child: BlocBuilder<CierreSitsaCubit, CierreSitsaState>(
                    builder: (context, state) => switch (state) {
                      CierreSitsaInitial() => Center(
                          child:
                              Text(context.l10n.msgSelectDateGenerate)),
                      CierreSitsaLoading() => const Center(
                          child: CircularProgressIndicator()),
                      CierreSitsaFailure(:final error) => Center(
                          child: Text(error,
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .error))),
                      CierreSitsaLoaded(:final data) => _CierreLayout(
                          data: data,
                          totalCards: _cards.fold(0.0, (s, c) => s + _parse(c.amount.text)),
                          totalDeposits: _deposits.fold(0.0, (s, d) {
                            final amount = _parse(d.amount.text);
                            if (d.currency == 'USD') {
                              final rate = _parse(d.exchangeRate.text);
                              return s + (rate > 0 ? amount * rate : amount);
                            }
                            return s + amount;
                          }),
                        ),
                    },
                  ),
                ),
                const SizedBox(width: 24),
                // Input panels
                SizedBox(
                  width: 480,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _DepositsSection(
                          entries: _deposits,
                          onAdd: _addDeposit,
                          onRemove: _removeDeposit,
                          onChanged: () => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        _CardChargesSection(
                          entries: _cards,
                          onAdd: _addCard,
                          onRemove: _removeCard,
                          onChanged: () => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        Builder(builder: (context) {
                          final canSave = context.select((AuthCubit c) =>
                              c.state is AuthAuthenticated &&
                              (c.state as AuthAuthenticated)
                                  .hasPrivilege('generate_closure'));
                          return FilledButton.icon(
                            onPressed: canSave ? _savePrevInventory : null,
                            icon: const Icon(Icons.save_outlined, size: 16),
                            label: Text(context.l10n.btnSave),
                          );
                        }),
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

// ── Deposits section ──────────────────────────────────────────────────────────

class _DepositsSection extends StatelessWidget {
  final List<DepositEntry> entries;
  final VoidCallback onAdd;
  final void Function(int) onRemove;
  final VoidCallback onChanged;

  const _DepositsSection({
    required this.entries,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return _SectionCard(
      title: l10n.labelDepositosBancarios,
      onAdd: onAdd,
      child: entries.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(l10n.msgNoDepositsAdded,
                    style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13)),
              ),
            )
          : Column(
              children: List.generate(
                entries.length,
                (i) => _DepositRow(
                  key: ObjectKey(entries[i]),
                  entry: entries[i],
                  onRemove: () => onRemove(i),
                  onChanged: onChanged,
                ),
              ),
            ),
    );
  }
}

class _DepositRow extends StatefulWidget {
  final DepositEntry entry;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _DepositRow({
    required this.entry,
    required this.onRemove,
    required this.onChanged,
    super.key,
  });

  @override
  State<_DepositRow> createState() => _DepositRowState();
}

class _DepositRowState extends State<_DepositRow> {
  static const _banks = ['BCR', 'BN', 'Custom'];
  static const _currencies = ['CRC', 'USD'];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final e = widget.entry;

    return Container(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _Field(
                  label: context.l10n.labelNumDeposito,
                  controller: e.depositNo,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Field(
                  label: context.l10n.labelMonto,
                  controller: e.amount,
                  numeric: true,
                  onFocusLost: widget.onChanged,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: widget.onRemove,
                icon: Icon(Icons.remove_circle_outline,
                    size: 18, color: colorScheme.error),
                tooltip: context.l10n.tooltipRemove,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Bank selector
              _SegmentedPicker(
                options: _banks,
                selected: e.bank,
                onSelected: (v) =>
                    setState(() => e.bank = v),
              ),
              if (e.bank == 'Custom') ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _Field(
                    label: context.l10n.labelBanco,
                    controller: e.customBank,
                  ),
                ),
              ],
              const Spacer(),
              // Currency selector
              _SegmentedPicker(
                options: _currencies,
                selected: e.currency,
                onSelected: (v) =>
                    setState(() => e.currency = v),
              ),
              if (e.currency == 'USD') ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: _Field(
                    label: context.l10n.labelTC,
                    controller: e.exchangeRate,
                    numeric: true,
                    onFocusLost: widget.onChanged,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Card charges section ──────────────────────────────────────────────────────

class _CardChargesSection extends StatelessWidget {
  final List<CardChargeEntry> entries;
  final VoidCallback onAdd;
  final void Function(int) onRemove;
  final VoidCallback onChanged;

  const _CardChargesSection({
    required this.entries,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return _SectionCard(
      title: l10n.labelCobrosConTarjeta,
      onAdd: onAdd,
      child: entries.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(l10n.msgNoCardChargesAdded,
                    style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13)),
              ),
            )
          : Column(
              children: List.generate(
                entries.length,
                (i) => _CardChargeRow(
                  key: ObjectKey(entries[i]),
                  entry: entries[i],
                  onRemove: () => onRemove(i),
                  onChanged: onChanged,
                ),
              ),
            ),
    );
  }
}

class _CardChargeRow extends StatefulWidget {
  final CardChargeEntry entry;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _CardChargeRow({
    required this.entry,
    required this.onRemove,
    required this.onChanged,
    super.key,
  });

  @override
  State<_CardChargeRow> createState() => _CardChargeRowState();
}

class _CardChargeRowState extends State<_CardChargeRow> {
  static const _banks = ['BCR', 'Promerica', 'Custom'];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final e = widget.entry;

    return Container(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          _SegmentedPicker(
            options: _banks,
            selected: e.bank,
            onSelected: (v) => setState(() => e.bank = v),
          ),
          if (e.bank == 'Custom') ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 110,
              child: _Field(
                label: context.l10n.labelBanco,
                controller: e.customBank,
              ),
            ),
          ],
          const SizedBox(width: 8),
          Expanded(
            child: _Field(
              label: context.l10n.labelMonto,
              controller: e.amount,
              numeric: true,
              onFocusLost: widget.onChanged,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: widget.onRemove,
            icon: Icon(Icons.remove_circle_outline,
                size: 18, color: colorScheme.error),
            tooltip: context.l10n.tooltipRemove,
          ),
        ],
      ),
    );
  }
}

// ── Shared UI components ──────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final VoidCallback onAdd;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.onAdd,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                Text(title,
                    style: textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(context.l10n.btnAdd),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _SegmentedPicker extends StatelessWidget {
  final List<String> options;
  final String selected;
  final void Function(String) onSelected;

  const _SegmentedPicker({
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
        final isSelected = opt == selected;
        return GestureDetector(
          onTap: () => onSelected(opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerLow,
              border: Border.all(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.outline),
              borderRadius: BorderRadius.horizontal(
                left: opt == options.first
                    ? const Radius.circular(6)
                    : Radius.zero,
                right: opt == options.last
                    ? const Radius.circular(6)
                    : Radius.zero,
              ),
            ),
            child: Text(
              opt,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurface,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _Field extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final bool numeric;
  final void Function(String)? onChanged;
  final VoidCallback? onFocusLost;

  const _Field({
    required this.label,
    required this.controller,
    this.numeric = false,
    this.onChanged,
    this.onFocusLost,
  });

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
    if (widget.onFocusLost != null) {
      _focus.addListener(() {
        if (!_focus.hasFocus) widget.onFocusLost!();
      });
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: _focus,
      onChanged: widget.onChanged,
      keyboardType: widget.numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: widget.numeric
          ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
          : null,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );
  }
}

// ── Report layout ─────────────────────────────────────────────────────────────

class _CierreLayout extends StatelessWidget {
  final CierreSitsaData data;
  final double totalCards;
  final double totalDeposits;

  const _CierreLayout({
    required this.data,
    required this.totalCards,
    required this.totalDeposits,
  });

  @override
  Widget build(BuildContext context) {
    final colones = NumberFormat.currency(symbol: '₡', decimalDigits: 2);
    final pctFmt = NumberFormat('0.00');

    final bruto = (data.general['BrutTotal'] as num?)?.toDouble() ?? 0.0;
    final bonos = (data.general['TotalBonos'] as num?)?.toDouble() ?? 0.0;
    final discount = (data.general['TotalDiscount'] as num?)?.toDouble() ?? 0.0;

    final ventaNeta = bruto - bonos - discount;
    final pctDesc = bruto > 0 ? (bonos + discount) / bruto * 100 : 0.0;
    final diferencia = ventaNeta - totalCards - totalDeposits;

    final l10n = context.l10n;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SummaryTile(
                label: l10n.tileBruto,
                value: colones.format(bruto),
              ),
              _SummaryTile(
                label: l10n.tileBonos,
                value: colones.format(bonos),
              ),
              _SummaryTile(
                label: l10n.tileDescuentos,
                value: colones.format(discount),
              ),
              _SummaryTile(
                label: l10n.tileCostoInventario,
                value: canSeeProfitMargins(context) ? colones.format(data.inventoryCost) : redacted,
                highlight: true,
              ),
              _SummaryTile(
                label: l10n.labelInventarioAnterior,
                value: canSeeProfitMargins(context) ? colones.format(data.prevInventoryCost) : redacted,
                highlight: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SummaryTile(
                label: l10n.tileVentaNeta,
                value: colones.format(ventaNeta),
                highlight: true,
              ),
              _SummaryTile(
                label: l10n.tilePctDescuento,
                value: '${pctFmt.format(pctDesc)}%',
              ),
              _SummaryTile(
                label: l10n.tileDiferenciaDepositar,
                value: colones.format(diferencia),
                highlight: diferencia == 0,
              ),
              if (data.tipoCambio != null)
                _SummaryTile(
                  label: '${l10n.tileTipoCambio} (${data.tipoCambio!.date})',
                  value: '₡${data.tipoCambio!.ventaUsd.toStringAsFixed(2)}',
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(l10n.labelRangosFacturas,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          _InvoicesTable(invoices: data.invoices),
        ],
      ),
    );
  }
}

class _InvoicesTable extends StatelessWidget {
  final List<Map<String, dynamic>> invoices;
  const _InvoicesTable({required this.invoices});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final numFmt = NumberFormat.decimalPattern();

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
                children: [
                  Expanded(
                      flex: 3,
                      child: Text(context.l10n.colRangoInicio,
                          style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600))),
                  Expanded(
                      flex: 3,
                      child: Text(context.l10n.colRangoFin,
                          style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600))),
                  SizedBox(
                      width: 80,
                      child: Text(context.l10n.colTotal,
                          style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600),
                          textAlign: TextAlign.end)),
                ],
              ),
            ),
            const Divider(height: 1),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: invoices.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: colorScheme.outlineVariant),
              itemBuilder: (context, i) {
                final inv = invoices[i];
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  color: i.isOdd
                      ? colorScheme.surfaceContainerLowest
                      : null,
                  child: Row(
                    children: [
                      Expanded(
                          flex: 3,
                          child: Text('${inv['RangeStart']}',
                              style: textTheme.bodySmall)),
                      Expanded(
                          flex: 3,
                          child: Text('${inv['RangeEnd']}',
                              style: textTheme.bodySmall)),
                      SizedBox(
                        width: 80,
                        child: Text(numFmt.format(inv['Total']),
                            style: textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600),
                            textAlign: TextAlign.end),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _SummaryTile({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bg = highlight
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerLow;
    final fg =
        highlight ? colorScheme.onPrimaryContainer : colorScheme.onSurface;
    final labelColor = highlight
        ? colorScheme.onPrimaryContainer.withOpacity(0.7)
        : colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: highlight
            ? null
            : Border.all(color: colorScheme.outlineVariant),
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

class _DateButton extends StatelessWidget {
  final String value;
  final VoidCallback onTap;

  const _DateButton({required this.value, required this.onTap});

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
            Text('${context.l10n.labelDate}  ',
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
