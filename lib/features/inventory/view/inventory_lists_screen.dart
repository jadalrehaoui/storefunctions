import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../di/service_locator.dart';
import '../../../services/item_lists_service.dart';
import '../../../shared/utils/privilege_helpers.dart';
import '../utils/inventory_lists_excel.dart';

class InventoryListsScreen extends StatefulWidget {
  const InventoryListsScreen({super.key});

  @override
  State<InventoryListsScreen> createState() => _InventoryListsScreenState();
}

class _InventoryListsScreenState extends State<InventoryListsScreen> {
  final _service = sl<ItemListsService>();

  List<Map<String, dynamic>>? _types;
  String? _typesError;
  bool _loadingTypes = false;

  String? _selectedType;
  List<Map<String, dynamic>>? _items;
  String? _itemsError;
  bool _loadingItems = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  Future<void> _loadTypes() async {
    setState(() {
      _loadingTypes = true;
      _typesError = null;
    });
    try {
      final data = await _service.getTypes();
      final list = (data is Map && data['types'] is List)
          ? (data['types'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _types = list;
        _loadingTypes = false;
        if (_selectedType != null &&
            !list.any((t) => t['type']?.toString() == _selectedType)) {
          _selectedType = null;
          _items = null;
        }
      });
      if (_selectedType == null && list.isNotEmpty) {
        _selectType(list.first['type']?.toString() ?? '');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _typesError = 'No se pudieron cargar las listas: $e';
        _loadingTypes = false;
      });
    }
  }

  Future<void> _selectType(String type) async {
    if (type.isEmpty) return;
    setState(() {
      _selectedType = type;
      _loadingItems = true;
      _itemsError = null;
      _selectedIds.clear();
    });
    try {
      final data = await _service.getItems(type: type);
      final items = (data is Map && data['items'] is List)
          ? (data['items'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _items = items;
        _loadingItems = false;
        final validIds =
            items.map((m) => (m['id'] as num?)?.toInt()).whereType<int>().toSet();
        _selectedIds.removeWhere((id) => !validIds.contains(id));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _itemsError = 'Error: $e';
        _loadingItems = false;
      });
    }
  }

  Future<void> _refreshAll() async {
    await _loadTypes();
    if (_selectedType != null) {
      await _selectType(_selectedType!);
    }
  }

  Future<void> _editQty(Map<String, dynamic> row) async {
    final id = (row['id'] as num?)?.toInt();
    if (id == null) return;
    final controller =
        TextEditingController(text: '${(row['qty'] as num?)?.toInt() ?? 0}');
    final newQty = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Cambiar cantidad'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Cantidad',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) {
              final v = int.tryParse(controller.text.trim());
              if (v != null && v >= 0) Navigator.of(ctx).pop(v);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final v = int.tryParse(controller.text.trim());
                if (v != null && v >= 0) Navigator.of(ctx).pop(v);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (newQty == null) return;
    await _runMutation(() => _service.updateItem(id, qty: newQty));
  }

  Future<void> _moveType(Map<String, dynamic> row) async {
    final id = (row['id'] as num?)?.toInt();
    if (id == null) return;
    final currentType = row['type']?.toString();
    final available = (_types ?? [])
        .map((t) => t['type']?.toString() ?? '')
        .where((t) => t.isNotEmpty && t != currentType)
        .toList();

    final controller = TextEditingController();
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Mover a otra lista'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (available.isNotEmpty) ...[
                  const Text('Listas existentes:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in available)
                        ActionChip(
                          label: Text(t),
                          onPressed: () => Navigator.of(ctx).pop(t),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                const Text('O nueva lista:'),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  autofocus: available.isEmpty,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (v) {
                    final t = v.trim();
                    if (t.isNotEmpty) Navigator.of(ctx).pop(t);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final t = controller.text.trim();
                if (t.isNotEmpty) Navigator.of(ctx).pop(t);
              },
              child: const Text('Mover'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (picked == null || picked.isEmpty) return;
    await _runMutation(() => _service.updateItem(id, type: picked));
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final id = (row['id'] as num?)?.toInt();
    if (id == null) return;
    final desc = row['descripcion']?.toString() ?? '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar item'),
        content: Text('¿Eliminar "$desc" de la lista?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _runMutation(() => _service.deleteItem(id));
  }

  void _toggleSelected(int id, bool? selected) {
    setState(() {
      if (selected == true) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  void _toggleSelectAll(bool? selected) {
    final ids = (_items ?? [])
        .map((m) => (m['id'] as num?)?.toInt())
        .whereType<int>()
        .toList();
    setState(() {
      _selectedIds.clear();
      if (selected == true) _selectedIds.addAll(ids);
    });
  }

  Future<void> _bulkDelete() async {
    if (_selectedIds.isEmpty) return;
    final ids = _selectedIds.toList();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar seleccionados'),
        content: Text('¿Eliminar ${ids.length} item(s) de la lista?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _runMutation(() => _service.bulkDeleteItems(ids));
  }

  Future<void> _deleteEntireList() async {
    final type = _selectedType;
    final items = _items;
    if (type == null || items == null || items.isEmpty) return;
    final ids = items
        .map((m) => (m['id'] as num?)?.toInt())
        .whereType<int>()
        .toList();
    if (ids.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar lista completa'),
        content: Text(
            '¿Eliminar la lista "$type" y sus ${ids.length} item(s)? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar todo'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _runMutation(() => _service.bulkDeleteItems(ids));
  }

  Future<void> _import() async {
    final messenger = ScaffoldMessenger.of(context);
    final existing = (_types ?? [])
        .map((t) => t['type']?.toString() ?? '')
        .where((t) => t.isNotEmpty)
        .toList();

    final result = await showDialog<_ImportResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ImportListDialog(
        existingTypes: existing,
        initialType: _selectedType,
      ),
    );
    if (result == null) return;

    setState(() {
      _selectedType = result.type;
    });
    await _loadTypes();
    await _selectType(result.type);
    messenger.showSnackBar(SnackBar(
      content: Text(
        'Importado a "${result.type}": ${result.inserted} nuevos, ${result.replaced} reemplazados (total ${result.total})',
      ),
    ));
  }

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    final type = _selectedType;
    final items = _items;
    if (type == null || items == null || items.isEmpty) return;
    try {
      final path = await exportItemListToExcel(
        type: type,
        items: items,
        showProfit: canSeeProfitMargins(context),
      );
      messenger.showSnackBar(SnackBar(content: Text('Exportado: $path')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error al exportar: $e')));
    }
  }

  Future<void> _runMutation(Future<dynamic> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      await _refreshAll();
    } on DioException catch (e) {
      final detail = e.response?.data is Map
          ? (e.response!.data as Map)['error']?.toString()
          : null;
      messenger.showSnackBar(
        SnackBar(content: Text(detail ?? e.message ?? 'Error de conexión')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Listas', style: textTheme.headlineSmall),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Recargar',
                onPressed: _refreshAll,
                icon: const Icon(Icons.refresh),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: _import,
                icon: const Icon(Icons.file_upload_outlined, size: 18),
                label: const Text('Importar lista'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 240,
                  child: _TypesPanel(
                    types: _types,
                    error: _typesError,
                    loading: _loadingTypes,
                    selectedType: _selectedType,
                    onSelect: _selectType,
                    textTheme: textTheme,
                    colorScheme: colorScheme,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _selectedType == null
                      ? Center(
                          child: Text(
                            'Selecciona una lista',
                            style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _selectedType!,
                                  style: textTheme.titleMedium,
                                ),
                                if (_items != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: colorScheme.secondaryContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text('${_items!.length}',
                                        style: textTheme.labelSmall?.copyWith(
                                            color: colorScheme
                                                .onSecondaryContainer)),
                                  ),
                                ],
                                const Spacer(),
                                if (_selectedIds.isNotEmpty) ...[
                                  TextButton.icon(
                                    onPressed: _bulkDelete,
                                    icon: Icon(Icons.delete_outline,
                                        size: 16, color: colorScheme.error),
                                    label: Text(
                                      'Eliminar (${_selectedIds.length})',
                                      style:
                                          TextStyle(color: colorScheme.error),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                TextButton.icon(
                                  onPressed: (_items == null || _items!.isEmpty)
                                      ? null
                                      : _export,
                                  icon: const Icon(
                                      Icons.file_download_outlined,
                                      size: 16),
                                  label: const Text('Exportar'),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  tooltip: 'Eliminar lista completa',
                                  onPressed: (_items == null || _items!.isEmpty)
                                      ? null
                                      : _deleteEntireList,
                                  icon: Icon(Icons.delete_sweep_outlined,
                                      color: colorScheme.error),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: _ItemsPanel(
                                items: _items,
                                error: _itemsError,
                                loading: _loadingItems,
                                showProfit: canSeeProfitMargins(context),
                                selectedIds: _selectedIds,
                                onToggleRow: _toggleSelected,
                                onToggleAll: _toggleSelectAll,
                                onEditQty: _editQty,
                                onMove: _moveType,
                                onDelete: _delete,
                                textTheme: textTheme,
                                colorScheme: colorScheme,
                              ),
                            ),
                          ],
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

class _TypesPanel extends StatelessWidget {
  final List<Map<String, dynamic>>? types;
  final String? error;
  final bool loading;
  final String? selectedType;
  final ValueChanged<String> onSelect;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  const _TypesPanel({
    required this.types,
    required this.error,
    required this.loading,
    required this.selectedType,
    required this.onSelect,
    required this.textTheme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (error != null) {
      body = Padding(
        padding: const EdgeInsets.all(12),
        child: Text(error!, style: TextStyle(color: colorScheme.error)),
      );
    } else if (loading && types == null) {
      body = const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (types == null || types!.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'No hay listas todavía.',
          style: textTheme.bodySmall
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      );
    } else {
      body = ListView.separated(
        shrinkWrap: true,
        itemCount: types!.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: colorScheme.outlineVariant),
        itemBuilder: (context, i) {
          final t = types![i];
          final name = t['type']?.toString() ?? '';
          final count = (t['count'] as num?)?.toInt() ?? 0;
          final selected = name == selectedType;
          return ListTile(
            title: Text(name),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$count',
                  style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSecondaryContainer)),
            ),
            selected: selected,
            selectedTileColor: colorScheme.primaryContainer.withValues(
              alpha: 0.4,
            ),
            onTap: () => onSelect(name),
          );
        },
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: body,
      ),
    );
  }
}

class _ItemsPanel extends StatelessWidget {
  final List<Map<String, dynamic>>? items;
  final String? error;
  final bool loading;
  final bool showProfit;
  final Set<int> selectedIds;
  final void Function(int id, bool? selected) onToggleRow;
  final void Function(bool? selected) onToggleAll;
  final void Function(Map<String, dynamic>) onEditQty;
  final void Function(Map<String, dynamic>) onMove;
  final void Function(Map<String, dynamic>) onDelete;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  const _ItemsPanel({
    required this.items,
    required this.error,
    required this.loading,
    required this.showProfit,
    required this.selectedIds,
    required this.onToggleRow,
    required this.onToggleAll,
    required this.onEditQty,
    required this.onMove,
    required this.onDelete,
    required this.textTheme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Center(
        child: Text(error!, style: TextStyle(color: colorScheme.error)),
      );
    }
    // Show the spinner whenever a load is in flight (initial load OR
    // re-selecting a list while old items are still present).
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items == null || items!.isEmpty) {
      return Center(
        child: Text(
          'Lista vacía.',
          style:
              textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    final money = NumberFormat.currency(symbol: '₡', decimalDigits: 2);
    final rows = items!;

    final allSelected = rows.isNotEmpty &&
        rows.every((r) {
          final id = (r['id'] as num?)?.toInt();
          return id != null && selectedIds.contains(id);
        });

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeaderRow(
              allSelected: allSelected,
              onToggleAll: onToggleAll,
              showProfit: showProfit,
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
            Divider(height: 1, color: colorScheme.outlineVariant),
            // Lazy list: only visible rows are built, so a large list no
            // longer blocks the UI thread on build.
            Expanded(
              child: ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: colorScheme.outlineVariant),
                itemBuilder: (context, i) {
                  final r = rows[i];
                  final id = (r['id'] as num?)?.toInt();
                  final selected = id != null && selectedIds.contains(id);
                  return _ItemRow(
                    row: r,
                    selected: selected,
                    showProfit: showProfit,
                    money: money,
                    dateFmt: dateFmt,
                    onToggle: id == null
                        ? null
                        : (sel) => onToggleRow(id, sel),
                    onEditQty: () => onEditQty(r),
                    onMove: () => onMove(r),
                    onDelete: () => onDelete(r),
                    colorScheme: colorScheme,
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

/// Fixed header for the lazy item list (mirrors the old DataTable columns).
class _HeaderRow extends StatelessWidget {
  final bool allSelected;
  final void Function(bool? selected) onToggleAll;
  final bool showProfit;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _HeaderRow({
    required this.allSelected,
    required this.onToggleAll,
    required this.showProfit,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final style = textTheme.labelMedium
        ?.copyWith(fontWeight: FontWeight.w600, color: colorScheme.onSurface);
    Widget cell(String label, int flex, {TextAlign align = TextAlign.left}) {
      return Expanded(
        flex: flex,
        child: Text(label, style: style, textAlign: align),
      );
    }

    return Container(
      color: colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Checkbox(
              value: allSelected,
              onChanged: onToggleAll,
            ),
          ),
          cell('Código', 2),
          cell('Barras', 2),
          cell('Descripción', 4),
          cell('Modelo', 2),
          cell('Costo', 2, align: TextAlign.right),
          cell('Ganancia', 2, align: TextAlign.right),
          cell('Precio', 2, align: TextAlign.right),
          cell('Qty', 1, align: TextAlign.right),
          cell('Agregado por', 2),
          cell('Fecha', 2),
          const SizedBox(width: 96),
        ],
      ),
    );
  }
}

/// A single lazily-built row.
class _ItemRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool selected;
  final bool showProfit;
  final NumberFormat money;
  final DateFormat dateFmt;
  final void Function(bool? selected)? onToggle;
  final VoidCallback onEditQty;
  final VoidCallback onMove;
  final VoidCallback onDelete;
  final ColorScheme colorScheme;

  const _ItemRow({
    required this.row,
    required this.selected,
    required this.showProfit,
    required this.money,
    required this.dateFmt,
    required this.onToggle,
    required this.onEditQty,
    required this.onMove,
    required this.onDelete,
    required this.colorScheme,
  });

  static String _fmtDate(dynamic raw, DateFormat fmt) {
    if (raw == null) return '';
    final d = DateTime.tryParse(raw.toString());
    return d == null ? raw.toString() : fmt.format(d.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    Widget cell(String text, int flex, {TextAlign align = TextAlign.left}) {
      return Expanded(
        flex: flex,
        child: Text(
          text,
          textAlign: align,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    final costo = showProfit
        ? (row['costo'] is num
            ? money.format((row['costo'] as num).toDouble())
            : '')
        : redacted;
    final ganancia = showProfit
        ? (row['ganancia'] is num
            ? money.format((row['ganancia'] as num).toDouble())
            : '')
        : redacted;
    final precio = row['precio'] is num
        ? money.format((row['precio'] as num).toDouble())
        : '';

    return Container(
      color: selected
          ? colorScheme.primaryContainer.withValues(alpha: 0.4)
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Checkbox(
              value: selected,
              onChanged: onToggle,
            ),
          ),
          cell(row['sitsa_code']?.toString() ?? '', 2),
          cell(row['barcode']?.toString() ?? '', 2),
          cell(row['descripcion']?.toString() ?? '', 4),
          cell(row['modelo']?.toString() ?? '', 2),
          cell(costo, 2, align: TextAlign.right),
          cell(ganancia, 2, align: TextAlign.right),
          cell(precio, 2, align: TextAlign.right),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: onEditQty,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    '${(row['qty'] as num?)?.toInt() ?? 0}',
                    style: TextStyle(color: colorScheme.primary),
                  ),
                ),
              ),
            ),
          ),
          cell(row['added_by_username']?.toString() ?? '', 2),
          cell(_fmtDate(row['added_at'], dateFmt), 2),
          SizedBox(
            width: 96,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Mover a otra lista',
                  icon: const Icon(Icons.drive_file_move_outlined, size: 18),
                  onPressed: onMove,
                ),
                IconButton(
                  tooltip: 'Eliminar',
                  icon: Icon(Icons.delete_outline,
                      size: 18, color: colorScheme.error),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportResult {
  final String type;
  final int total;
  final int inserted;
  final int replaced;
  const _ImportResult({
    required this.type,
    required this.total,
    required this.inserted,
    required this.replaced,
  });
}

class _ImportListDialog extends StatefulWidget {
  final List<String> existingTypes;
  final String? initialType;
  const _ImportListDialog({
    required this.existingTypes,
    this.initialType,
  });

  @override
  State<_ImportListDialog> createState() => _ImportListDialogState();
}

class _ImportListDialogState extends State<_ImportListDialog> {
  final _newTypeController = TextEditingController();
  String? _selectedType;
  bool _creatingNew = false;

  String? _filePath;
  String? _filename;

  bool _submitting = false;
  String? _error;
  List<Map<String, dynamic>>? _rowErrors;

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null &&
        widget.existingTypes.contains(widget.initialType)) {
      _selectedType = widget.initialType;
    } else if (widget.existingTypes.isEmpty) {
      _creatingNew = true;
    }
  }

  @override
  void dispose() {
    _newTypeController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv'],
      withData: false,
    );
    if (picked == null || picked.files.isEmpty) return;
    final f = picked.files.single;
    if (f.path == null) return;
    setState(() {
      _filePath = f.path;
      _filename = f.name;
    });
  }

  String? get _resolvedType {
    final t = _creatingNew
        ? _newTypeController.text.trim()
        : (_selectedType ?? '');
    return t.isEmpty ? null : t;
  }

  bool get _canSubmit =>
      !_submitting && _resolvedType != null && _filePath != null;

  Future<void> _downloadTemplate() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dir = Platform.isMacOS
          ? '/Users/${Platform.environment['USER']}/Downloads'
          : '${Platform.environment['USERPROFILE']}\\Downloads';
      await Directory(dir).create(recursive: true);
      final path =
          '$dir${Platform.pathSeparator}plantilla_lista_importar.csv';
      const content =
          '﻿code,descripcion,modelo,precio,costo,ganancia,qty\n'
          '7441234567890,,,,,,1\n'
          '12345,,,1500,,,5\n';
      await File(path).writeAsString(content);
      if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', path]);
      }
      messenger.showSnackBar(SnackBar(content: Text('Plantilla guardada: $path')));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('No se pudo crear la plantilla: $e')));
    }
  }

  Future<void> _downloadErrors() async {
    final messenger = ScaffoldMessenger.of(context);
    final errs = _rowErrors;
    if (errs == null || errs.isEmpty) return;
    try {
      final dir = Platform.isMacOS
          ? '/Users/${Platform.environment['USER']}/Downloads'
          : '${Platform.environment['USERPROFILE']}\\Downloads';
      await Directory(dir).create(recursive: true);
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final path =
          '$dir${Platform.pathSeparator}errores_importacion_$ts.csv';
      final buf = StringBuffer('﻿fila,codigo,razon\n');
      for (final e in errs) {
        final row = (e['row'] ?? '').toString();
        final code = (e['code'] ?? '').toString();
        final reason = (e['reason'] ?? '').toString();
        buf.writeln('${_csv(row)},${_csv(code)},${_csv(reason)}');
      }
      await File(path).writeAsString(buf.toString());
      if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', path]);
      }
      messenger.showSnackBar(SnackBar(content: Text('Errores guardados: $path')));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('No se pudo guardar errores: $e')));
    }
  }

  static String _csv(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  Future<void> _submit() async {
    final type = _resolvedType;
    final path = _filePath;
    final name = _filename;
    if (type == null || path == null || name == null) return;

    setState(() {
      _submitting = true;
      _error = null;
      _rowErrors = null;
    });

    try {
      final data = await sl<ItemListsService>().importList(
        type: type,
        filePath: path,
        filename: name,
      );
      if (!mounted) return;
      final m = data is Map ? data : const {};
      Navigator.of(context).pop(_ImportResult(
        type: m['type']?.toString() ?? type,
        total: (m['total'] as num?)?.toInt() ?? 0,
        inserted: (m['inserted'] as num?)?.toInt() ?? 0,
        replaced: (m['replaced'] as num?)?.toInt() ?? 0,
      ));
    } on DioException catch (e) {
      if (!mounted) return;
      final body = e.response?.data;
      if (body is Map) {
        final errs = body['errors'];
        setState(() {
          _error = body['error']?.toString() ?? 'Error de importación';
          _rowErrors = errs is List
              ? errs
                  .whereType<Map>()
                  .map((m) => Map<String, dynamic>.from(m))
                  .toList()
              : null;
          _submitting = false;
        });
      } else {
        setState(() {
          _error = e.message ?? 'Error de conexión';
          _submitting = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: const Text('Importar lista'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Lista destino',
                  style: textTheme.labelSmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              if (widget.existingTypes.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in widget.existingTypes)
                      ChoiceChip(
                        label: Text(t),
                        selected: !_creatingNew && _selectedType == t,
                        onSelected: (sel) => setState(() {
                          _creatingNew = false;
                          _selectedType = sel ? t : null;
                        }),
                      ),
                  ],
                ),
              if (widget.existingTypes.isNotEmpty) const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: _creatingNew,
                    onChanged: (v) => setState(() {
                      _creatingNew = v ?? false;
                      if (_creatingNew) _selectedType = null;
                    }),
                  ),
                  const Text('Nueva lista'),
                ],
              ),
              if (_creatingNew)
                TextField(
                  controller: _newTypeController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la lista',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              const SizedBox(height: 16),
              Text('Archivo (.xlsx o .csv)',
                  style: textTheme.labelSmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _submitting ? null : _pickFile,
                    icon: const Icon(Icons.attach_file, size: 18),
                    label: Text(_filename ?? 'Seleccionar archivo'),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: _submitting ? null : _downloadTemplate,
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: const Text('Descargar plantilla'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Columnas: code (requerida), descripcion, modelo, precio, costo, ganancia, qty.',
                style: textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _error!,
                        style: TextStyle(
                            color: colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w600),
                      ),
                      if (_rowErrors != null && _rowErrors!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _downloadErrors,
                            icon: const Icon(Icons.download, size: 16),
                            label: const Text('Descargar errores'),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columnSpacing: 16,
                              headingRowHeight: 32,
                              dataRowMinHeight: 28,
                              dataRowMaxHeight: 36,
                              columns: const [
                                DataColumn(label: Text('Fila'), numeric: true),
                                DataColumn(label: Text('Código')),
                                DataColumn(label: Text('Razón')),
                              ],
                              rows: [
                                for (final e in _rowErrors!)
                                  DataRow(cells: [
                                    DataCell(Text('${e['row'] ?? ''}')),
                                    DataCell(Text('${e['code'] ?? ''}')),
                                    DataCell(SizedBox(
                                      width: 320,
                                      child: Text(
                                        '${e['reason'] ?? ''}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    )),
                                  ]),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Importar'),
        ),
      ],
    );
  }
}
