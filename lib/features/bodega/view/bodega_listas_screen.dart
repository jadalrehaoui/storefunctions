import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../di/service_locator.dart';
import '../../../services/receipt_printer_service.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../cubit/bodega_listas_cubit.dart';
import '../model/bodega_lista_item.dart';
import '../utils/bodega_lista_receipt_pdf.dart';

class BodegaListasScreen extends StatelessWidget {
  const BodegaListasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BodegaListasCubit(sl())..init(),
      child: const _BodegaListasView(),
    );
  }
}

class _BodegaListasView extends StatefulWidget {
  const _BodegaListasView();

  @override
  State<_BodegaListasView> createState() => _BodegaListasViewState();
}

class _BodegaListasViewState extends State<_BodegaListasView> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Keep focus on the input so a USB / Bluetooth HID scanner can keep
    // firing characters hands-free. On Android we additionally suppress the
    // software keyboard — the user toggles it on demand via the keyboard
    // button next to the input.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      if (Platform.isAndroid) _hideSoftKeyboard();
    });
  }

  void _hideSoftKeyboard() {
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }

  void _toggleSoftKeyboard() {
    final visible = MediaQuery.of(context).viewInsets.bottom > 0;
    if (visible) {
      _hideSoftKeyboard();
    } else {
      // Re-establish an input connection so Android shows the keyboard.
      _focusNode.unfocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.read<BodegaListasCubit>().addByCode(text);
    _controller.clear();
    _focusNode.requestFocus();
    if (Platform.isAndroid) _hideSoftKeyboard();
  }

  String? _currentUsername(BuildContext context) {
    final auth = context.read<AuthCubit>().state;
    return auth is AuthAuthenticated ? auth.username : null;
  }

  Future<void> _print(BodegaListasReady s) async {
    final filter = s.creatorFilter;
    if (filter == null) return;
    final itemsToPrint =
        s.items.where((i) => i.addedByUsername == filter).toList();
    if (itemsToPrint.isEmpty) return;

    final cubit = context.read<BodegaListasCubit>();
    cubit.setPrintInFlight(true);

    try {
      final bytes = await buildBodegaListaReceiptPdf(
        items: itemsToPrint,
        creator: filter,
        now: DateTime.now(),
      );

      final printer = sl<ReceiptPrinterService>();
      final printed = await printer.printPdf(
        bytes,
        kind: PrinterKind.receipt,
        name: 'bodega_lista_$filter',
      );

      if (!printed) {
        final path = await openBodegaListaPdf(bytes);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'No hay impresora de recibos configurada. PDF guardado: $path')),
        );
        cubit.setPrintInFlight(false);
        return;
      }

      final ids = itemsToPrint.map((i) => i.id).toList();
      final ok = await cubit.removeItems(ids);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ids.length} líneas impresas y removidas')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al imprimir: $e')),
      );
    } finally {
      if (mounted) cubit.setPrintInFlight(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return BlocListener<BodegaListasCubit, BodegaListasState>(
      listenWhen: (prev, curr) =>
          curr is BodegaListasReady &&
          curr.transientError != null &&
          (prev is! BodegaListasReady ||
              prev.transientError != curr.transientError),
      listener: (context, state) {
        final err = (state as BodegaListasReady).transientError!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Listas', style: textTheme.headlineSmall),
                const SizedBox(width: 12),
                BlocBuilder<BodegaListasCubit, BodegaListasState>(
                  buildWhen: (p, c) =>
                      c is BodegaListasReady &&
                      (p is! BodegaListasReady ||
                          p.liveConnected != c.liveConnected),
                  builder: (context, state) {
                    if (state is! BodegaListasReady) return const SizedBox.shrink();
                    return _LiveBadge(connected: state.liveConnected);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            BlocBuilder<BodegaListasCubit, BodegaListasState>(
              builder: (context, state) {
                if (state is BodegaListasInitial ||
                    state is BodegaListasLoading) {
                  return const Expanded(
                      child: Center(child: CircularProgressIndicator()));
                }
                if (state is BodegaListasFailure) {
                  return Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 48),
                          const SizedBox(height: 8),
                          Text(state.error),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () =>
                                context.read<BodegaListasCubit>().init(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (state is BodegaListasReady) {
                  return Expanded(child: _ReadyView(
                    state: state,
                    controller: _controller,
                    focusNode: _focusNode,
                    currentUsername: _currentUsername(context),
                    onSubmit: _submit,
                    onPrint: () => _print(state),
                    onToggleKeyboard: _toggleSoftKeyboard,
                  ));
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  final bool connected;
  const _LiveBadge({required this.connected});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = connected ? Colors.green : colorScheme.error;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          connected ? 'En vivo' : 'Reconectando...',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _ReadyView extends StatelessWidget {
  final BodegaListasReady state;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? currentUsername;
  final VoidCallback onSubmit;
  final VoidCallback onPrint;
  final VoidCallback onToggleKeyboard;

  const _ReadyView({
    required this.state,
    required this.controller,
    required this.focusNode,
    required this.currentUsername,
    required this.onSubmit,
    required this.onPrint,
    required this.onToggleKeyboard,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BodegaListasCubit>();
    final visible = state.visibleItems;
    final canPrint = state.creatorFilter != null && visible.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: 'Escanear código o escribir',
                  prefixIcon: const Icon(Icons.qr_code_scanner),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: Platform.isAndroid
                      ? IconButton(
                          tooltip:
                              MediaQuery.of(context).viewInsets.bottom > 0
                                  ? 'Ocultar teclado'
                                  : 'Mostrar teclado',
                          icon: Icon(
                            MediaQuery.of(context).viewInsets.bottom > 0
                                ? Icons.keyboard_hide
                                : Icons.keyboard,
                          ),
                          onPressed: onToggleKeyboard,
                        )
                      : null,
                ),
                onSubmitted: (_) => onSubmit(),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: state.addInFlight ? null : onSubmit,
              icon: state.addInFlight
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add, size: 18),
              label: const Text('Agregar'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _FilterDropdown(state: state)),
            const SizedBox(width: 12),
            if (currentUsername != null)
              FilterChip(
                selected: state.creatorFilter == currentUsername,
                label: const Text('Mis items'),
                onSelected: (sel) =>
                    cubit.setCreatorFilter(sel ? currentUsername : null),
              ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed:
                  (state.printInFlight || !canPrint) ? null : onPrint,
              icon: state.printInFlight
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.print, size: 18),
              label: Text(canPrint
                  ? 'Imprimir (${visible.length})'
                  : 'Imprimir'),
            ),
          ],
        ),
        if (state.creatorFilter == null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Selecciona un creador para imprimir su lista.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        const SizedBox(height: 16),
        Expanded(child: _ListTable(items: visible, cubit: cubit)),
      ],
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final BodegaListasReady state;
  const _FilterDropdown({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BodegaListasCubit>();
    final creators = state.creatorsInList;
    return DropdownButtonFormField<String?>(
      initialValue: state.creatorFilter,
      decoration: const InputDecoration(
        labelText: 'Filtrar por creador',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Todos (no se puede imprimir)'),
        ),
        ...creators.map((c) => DropdownMenuItem<String?>(
              value: c,
              child: Text(c),
            )),
      ],
      onChanged: cubit.setCreatorFilter,
    );
  }
}

class _ListTable extends StatelessWidget {
  final List<BodegaListaItem> items;
  final BodegaListasCubit cubit;
  const _ListTable({required this.items, required this.cubit});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (items.isEmpty) {
      return Center(
        child: Text(
          'La lista está vacía.',
          style: textTheme.bodyMedium
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    final timeFmt = DateFormat('HH:mm');

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
                children: [
                  _hCell('Descripción', textTheme, colorScheme, flex: 3),
                  _hCell('Código', textTheme, colorScheme, flex: 2),
                  _hCell('Modelo', textTheme, colorScheme, flex: 2),
                  _hCell('Cant', textTheme, colorScheme,
                      width: 60, align: TextAlign.right),
                  _hCell('Creador', textTheme, colorScheme, flex: 2),
                  _hCell('Hora', textTheme, colorScheme, width: 60),
                  const SizedBox(width: 36),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: colorScheme.outlineVariant),
                itemBuilder: (context, i) {
                  final item = items[i];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    color: i.isOdd ? colorScheme.surfaceContainerLowest : null,
                    child: Row(
                      children: [
                        _cell(item.descripcion, textTheme, flex: 3),
                        _cell(item.sitsaCode, textTheme, flex: 2),
                        _cell(item.modelo ?? '', textTheme, flex: 2),
                        _cell('${item.qty}', textTheme,
                            width: 60, align: TextAlign.right),
                        _cell(item.addedByUsername, textTheme, flex: 2),
                        _cell(timeFmt.format(item.addedAt.toLocal()), textTheme,
                            width: 60),
                        SizedBox(
                          width: 36,
                          child: IconButton(
                            icon: Icon(Icons.delete_outline,
                                size: 16, color: colorScheme.onSurfaceVariant),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 28, minHeight: 28),
                            tooltip: 'Eliminar',
                            onPressed: () => cubit.removeItem(item.id),
                          ),
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

  Widget _hCell(String label, TextTheme t, ColorScheme c,
      {int? flex, double? width, TextAlign align = TextAlign.left}) {
    final child = Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Text(
        label,
        textAlign: align,
        style: t.labelSmall?.copyWith(
            color: c.onSurfaceVariant, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ),
    );
    if (width != null) return SizedBox(width: width, child: child);
    return Expanded(flex: flex ?? 1, child: child);
  }

  Widget _cell(String value, TextTheme t,
      {int? flex, double? width, TextAlign align = TextAlign.left}) {
    final child = Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Text(
        value,
        textAlign: align,
        style: t.bodySmall,
        overflow: TextOverflow.ellipsis,
      ),
    );
    if (width != null) return SizedBox(width: width, child: child);
    return Expanded(flex: flex ?? 1, child: child);
  }
}
