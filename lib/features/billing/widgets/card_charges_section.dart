import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../reports/view/cierre_sitsa_screen.dart' show CardChargeEntry;

/// Reusable "Cobros con Tarjeta" section matching the cierre sitsa report UX.
class CardChargesSection extends StatelessWidget {
  final List<CardChargeEntry> entries;
  final VoidCallback onAdd;
  final void Function(int) onRemove;
  final VoidCallback onChanged;
  final String? titleOverride;
  final String? bankLabelOverride;

  const CardChargesSection({
    super.key,
    required this.entries,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
    this.titleOverride,
    this.bankLabelOverride,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return _SectionCard(
      title: titleOverride ?? l10n.labelCobrosConTarjeta,
      onAdd: onAdd,
      child: entries.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(l10n.msgNoCardChargesAdded,
                    style: TextStyle(
                        color: colorScheme.onSurfaceVariant, fontSize: 13)),
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
                  bankLabel: bankLabelOverride,
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
  final String? bankLabel;

  const _CardChargeRow({
    required this.entry,
    required this.onRemove,
    required this.onChanged,
    this.bankLabel,
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
        border:
            Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
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
                label: widget.bankLabel ?? context.l10n.labelBanco,
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
  final VoidCallback? onFocusLost;

  const _Field({
    required this.label,
    required this.controller,
    this.numeric = false,
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
      keyboardType: widget.numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
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
