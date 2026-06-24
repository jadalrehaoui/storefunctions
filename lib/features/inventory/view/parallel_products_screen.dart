import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../di/service_locator.dart';
import '../../../shared/utils/privilege_helpers.dart';
import '../cubit/parallel_products_cubit.dart';
import '../model/parallel_product.dart';

final _money = NumberFormat.currency(symbol: '₡', decimalDigits: 2);

class ParallelProductsScreen extends StatelessWidget {
  const ParallelProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ParallelProductsCubit(sl())..load(),
      child: const _ParallelProductsView(),
    );
  }
}

class _ParallelProductsView extends StatelessWidget {
  const _ParallelProductsView();

  @override
  Widget build(BuildContext context) {
    final canCreate = canCreateProduct(context);
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Productos Parallel',
                    style: Theme.of(context).textTheme.headlineSmall),
                const Spacer(),
                if (canCreate)
                  FilledButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nuevo producto'),
                    onPressed: () => _showDialog(context),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const Expanded(child: _ProductsTable()),
          ],
        ),
      ),
    );
  }

  void _showDialog(BuildContext context, {ParallelProduct? product}) {
    showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<ParallelProductsCubit>(),
        child: _ProductFormDialog(product: product),
      ),
    );
  }
}

class _ProductsTable extends StatelessWidget {
  const _ProductsTable();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ParallelProductsCubit, ParallelProductsState>(
      builder: (context, state) => switch (state) {
        ParallelProductsInitial() =>
          const Center(child: CircularProgressIndicator()),
        ParallelProductsLoading() =>
          const Center(child: CircularProgressIndicator()),
        ParallelProductsFailure(:final error) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.read<ParallelProductsCubit>().load(),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ParallelProductsSuccess(:final products) => products.isEmpty
            ? const Center(child: Text('No hay productos Parallel'))
            : _Table(products: products),
      },
    );
  }
}

class _Table extends StatelessWidget {
  final List<ParallelProduct> products;
  const _Table({required this.products});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final canCreate = canCreateProduct(context);

    Widget headerCell(String label, int flex,
            {TextAlign align = TextAlign.start}) =>
        Expanded(
          flex: flex,
          child: Text(label,
              textAlign: align,
              style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600)),
        );

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
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  headerCell('Código', 2),
                  headerCell('Código de barras', 2),
                  headerCell('Descripción', 4),
                  headerCell('Cant.', 1, align: TextAlign.end),
                  headerCell('Precio', 2, align: TextAlign.end),
                  const SizedBox(width: 80),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: products.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: colorScheme.outlineVariant),
                itemBuilder: (context, i) {
                  final p = products[i];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    color:
                        i.isOdd ? colorScheme.surfaceContainerLowest : null,
                    child: Row(
                      children: [
                        Expanded(
                            flex: 2,
                            child: Text(p.codigo,
                                style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500))),
                        Expanded(
                            flex: 2,
                            child: Text(p.barcode ?? '',
                                style: textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis)),
                        Expanded(
                            flex: 4,
                            child: Text(p.descripcion,
                                style: textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis)),
                        Expanded(
                            flex: 1,
                            child: Text('${p.qty}',
                                textAlign: TextAlign.end,
                                style: textTheme.bodySmall)),
                        Expanded(
                            flex: 2,
                            child: Text(_money.format(p.precio),
                                textAlign: TextAlign.end,
                                style: textTheme.bodySmall)),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: 'Editar',
                              onPressed: canCreate
                                  ? () => _showEdit(context, p)
                                  : null,
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline,
                                  size: 18,
                                  color: canCreate
                                      ? colorScheme.error
                                      : colorScheme.outlineVariant),
                              tooltip: 'Eliminar',
                              onPressed: canCreate
                                  ? () => _confirmDelete(context, p)
                                  : null,
                            ),
                          ],
                        ),
                      ],
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

  void _showEdit(BuildContext context, ParallelProduct product) {
    showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<ParallelProductsCubit>(),
        child: _ProductFormDialog(product: product),
      ),
    );
  }

  void _confirmDelete(BuildContext context, ParallelProduct product) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Eliminar "${product.descripcion}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              final id = product.id;
              if (id != null) {
                context.read<ParallelProductsCubit>().deleteProduct(id);
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

class _ProductFormDialog extends StatefulWidget {
  final ParallelProduct? product;
  const _ProductFormDialog({this.product});

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codigoCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _descripcionCtrl;
  late final TextEditingController _modeloCtrl;
  late final TextEditingController _precioCtrl;
  late final TextEditingController _costoCtrl;
  late final TextEditingController _qtyCtrl;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _codigoCtrl = TextEditingController(text: p?.codigo ?? '');
    _barcodeCtrl = TextEditingController(text: p?.barcode ?? '');
    _descripcionCtrl = TextEditingController(text: p?.descripcion ?? '');
    _modeloCtrl = TextEditingController(text: p?.modelo ?? '');
    _precioCtrl = TextEditingController(
        text: p != null ? p.precio.toString() : '');
    _costoCtrl =
        TextEditingController(text: p != null ? p.costo.toString() : '');
    _qtyCtrl = TextEditingController(text: p != null ? p.qty.toString() : '1');
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _barcodeCtrl.dispose();
    _descripcionCtrl.dispose();
    _modeloCtrl.dispose();
    _precioCtrl.dispose();
    _costoCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  double _num(String s) => double.tryParse(s.trim().replaceAll(',', '')) ?? 0;

  // Profit % derived from price and cost (precio = costo + costo*utilidad/100).
  double get _utilidad {
    final precio = _num(_precioCtrl.text);
    final costo = _num(_costoCtrl.text);
    return costo > 0 ? (precio - costo) / costo * 100 : 0;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 1;
    final product = ParallelProduct(
      codigo: _codigoCtrl.text.trim(),
      barcode: _barcodeCtrl.text.trim().isEmpty
          ? null
          : _barcodeCtrl.text.trim(),
      descripcion: _descripcionCtrl.text.trim(),
      modelo: _modeloCtrl.text.trim().isEmpty ? null : _modeloCtrl.text.trim(),
      precio: _num(_precioCtrl.text),
      costo: _num(_costoCtrl.text),
      utilidad: _utilidad,
      qty: qty < 1 ? 1 : qty,
    );
    try {
      final cubit = context.read<ParallelProductsCubit>();
      if (_isEdit) {
        await cubit.editProduct(widget.product!.id!, product);
      } else {
        await cubit.createProduct(product);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Non-blocking hint: WorkDB codes should not collide with SITSA codes.
    final codigo = _codigoCtrl.text.trim();
    final showPrefixHint = codigo.isNotEmpty && !codigo.startsWith('P-');

    return AlertDialog(
      title: Text(_isEdit ? 'Editar producto' : 'Nuevo producto'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _field(
                  controller: _codigoCtrl,
                  label: 'Código',
                  required: true,
                  onChanged: (_) => setState(() {}),
                ),
                if (showPrefixHint) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Sugerencia: use un prefijo "P-" para no chocar con códigos de SITSA',
                    style: TextStyle(
                        fontSize: 11, color: colorScheme.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 12),
                _field(controller: _barcodeCtrl, label: 'Código de barras'),
                const SizedBox(height: 12),
                _field(
                    controller: _descripcionCtrl,
                    label: 'Descripción',
                    required: true),
                const SizedBox(height: 12),
                _field(controller: _modeloCtrl, label: 'Modelo'),
                const SizedBox(height: 12),
                _field(
                    controller: _precioCtrl,
                    label: 'Precio',
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    onChanged: (_) => setState(() {})),
                const SizedBox(height: 12),
                _field(
                    controller: _costoCtrl,
                    label: 'Costo',
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    onChanged: (_) => setState(() {})),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Utilidad: ${_utilidad.toStringAsFixed(1)}%',
                    style: TextStyle(
                        fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 12),
                _field(
                    controller: _qtyCtrl,
                    label: 'Cantidad',
                    keyboardType: TextInputType.number),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style:
                          TextStyle(color: colorScheme.error, fontSize: 12)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar'),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    bool required = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      validator: validator ??
          (required
              ? (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null
              : null),
    );
  }
}
