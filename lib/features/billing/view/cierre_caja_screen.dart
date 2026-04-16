import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../di/service_locator.dart';
import '../../../services/api_client.dart';
import '../../../services/inventory_service.dart';
import '../../../services/receipt_printer_service.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../reports/view/cierre_parallel_screen.dart';
import '../../reports/view/cierre_sitsa_screen.dart' show CardChargeEntry;
import '../utils/cierre_personal_receipt_pdf.dart';
import '../widgets/card_charges_section.dart';

class CierreCajaScreen extends StatelessWidget {
  const CierreCajaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final divider = VerticalDivider(
      width: 1,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Expanded(child: _CierreSitsaPanel()),
        divider,
        const Expanded(
          child: CierreParallelScreen(
            titleOverride: 'Cierre Parallel Personal',
            personalOnly: true,
          ),
        ),
      ],
    );
  }
}

class _CierreSitsaPanel extends StatefulWidget {
  const _CierreSitsaPanel();

  @override
  State<_CierreSitsaPanel> createState() => _CierreSitsaPanelState();
}

class _CierreSitsaPanelState extends State<_CierreSitsaPanel> {
  static final _displayFmt = DateFormat('MMM d, yyyy');
  DateTime _date = DateTime.now();
  bool _loading = false;
  String? _error;
  List<String> _cashiers = const [];
  String? _selectedPkCaja;

  bool _reportLoading = false;
  String? _reportError;
  Map<String, dynamic>? _general;

  final List<CardChargeEntry> _cards = [];

  @override
  void dispose() {
    for (final c in _cards) c.dispose();
    super.dispose();
  }

  double _parse(String s) => double.tryParse(s.replaceAll(',', '')) ?? 0.0;

  double get _cardsTotal =>
      _cards.fold(0.0, (s, c) => s + _parse(c.amount.text));

  void _addCard() => setState(() => _cards.add(CardChargeEntry()));
  void _removeCard(int i) => setState(() {
        _cards[i].dispose();
        _cards.removeAt(i);
      });

  String? _closureId;
  bool _saving = false;

  Future<void> _save() async {
    final g = _general;
    final caja = _selectedPkCaja;
    if (g == null || caja == null) return;
    final auth = context.read<AuthCubit>().state;
    final createdBy = auth is AuthAuthenticated ? auth.username : null;
    final dateStr = DateFormat('yyyy-MM-dd').format(_date);

    final cardsTotal = _cardsTotal;
    double gn(String k) => (g[k] as num?)?.toDouble() ?? 0.0;
    final totalAPagar = gn('SUM_TOTAL_A_PAGAR');
    final apartadosCobrados = gn('APARTADOS_COBRADOS');
    final apartadosOtro = gn('APARTADOS_FACTURADOS_POR_OTRO_USUARIO');
    final diferencia =
        totalAPagar - cardsTotal + apartadosCobrados - apartadosOtro;

    final payload = {
      'date': dateStr,
      'usuario': caja,
      'created_by': createdBy,
      'general': g,
      'card_charges': _cards
          .map((c) => {'bank': c.bankName, 'amount': _parse(c.amount.text)})
          .toList(),
      'calculations': {
        'cards_total': cardsTotal,
        'diferencia_a_depositar': diferencia,
      },
    };

    setState(() => _saving = true);
    final api = sl<ApiClient>();
    try {
      if (_closureId != null) {
        await api.put('/api/workdb/cierre-personal/$_closureId', payload);
      } else {
        try {
          final res = await api.post('/api/workdb/cierre-personal', payload);
          _closureId = res['data']?['id']?.toString();
        } on DioException catch (e) {
          if (e.response?.statusCode == 409) {
            // Find existing and PUT
            final existing = await api.get(
                '/api/workdb/cierre-personal?date=$dateStr&usuario=${Uri.encodeQueryComponent(caja)}');
            final id = (existing is Map)
                ? (existing['data']?['id'] ??
                        existing['data']?[0]?['id'] ??
                        existing['id'])
                    ?.toString()
                : null;
            if (id == null) rethrow;
            await api.put('/api/workdb/cierre-personal/$id', payload);
            _closureId = id;
          } else {
            rethrow;
          }
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Cierre guardado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _printReceipt() async {
    final g = _general;
    final caja = _selectedPkCaja;
    if (g == null || caja == null) return;
    final auth = context.read<AuthCubit>().state;
    final createdBy = auth is AuthAuthenticated ? auth.username : null;
    try {
      final bytes = await buildCierrePersonalReceiptPdf(
        date: _date,
        cashier: caja,
        createdBy: createdBy,
        general: g,
        cards: _cards,
      );
      final printer = sl<ReceiptPrinterService>();
      final printed = await printer.printPdf(bytes,
          name: 'cierre_personal_${caja}_${_date.toIso8601String()}');
      if (!printed) {
        await openCierrePersonalReceiptPdf(bytes, caja);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Print error: $e')));
    }
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await sl<InventoryService>().getActiveCashiers(_date);
      final list = (data is Map && data['data'] is List)
          ? (data['data'] as List).map((e) => e.toString()).toList()
          : <String>[];
      if (!mounted) return;
      setState(() {
        _cashiers = list;
        _selectedPkCaja = null;
        _general = null;
        _reportError = null;
        _loading = false;
        _closureId = null;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'HTTP ${e.response?.statusCode}: ${e.response?.data ?? e.message}';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _fetchReport() async {
    final caja = _selectedPkCaja;
    if (caja == null || caja.isEmpty) {
      setState(() {
        _general = null;
        _reportError = null;
      });
      return;
    }
    setState(() {
      _reportLoading = true;
      _reportError = null;
    });
    try {
      final data =
          await sl<InventoryService>().getDailyReportByCashier(_date, caja);
      final general = (data is Map && data['general'] is Map)
          ? Map<String, dynamic>.from(data['general'] as Map)
          : null;
      if (!mounted) return;
      setState(() {
        _general = general;
        _reportLoading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _reportError =
            'HTTP ${e.response?.statusCode}: ${e.response?.data ?? e.message}';
        _reportLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reportError = e.toString();
        _reportLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = picked);
      _fetch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cierre Sitsa Personal',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Fecha  ',
                      style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant)),
                  Text(_displayFmt.format(_date),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  Icon(Icons.calendar_today_outlined,
                      size: 14, color: colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(child: _buildResults(context)),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(_error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      );
    }
    if (_cashiers.isEmpty) {
      return Center(
        child: Text('Sin datos',
            style: TextStyle(color: Theme.of(context).colorScheme.outline)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String?>(
          initialValue: _selectedPkCaja,
          decoration: const InputDecoration(
            labelText: 'Caja',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          hint: const Text(''),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('')),
            for (final name in _cashiers)
              DropdownMenuItem<String?>(
                value: name,
                child: Text(name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) {
            setState(() {
              _selectedPkCaja = v;
              _closureId = null;
            });
            _fetchReport();
          },
        ),
        const SizedBox(height: 16),
        Expanded(child: _buildReport(context)),
      ],
    );
  }

  Widget _buildReport(BuildContext context) {
    if (_selectedPkCaja == null) return const SizedBox.shrink();
    if (_reportLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_reportError != null) {
      return Center(
        child: Text(_reportError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      );
    }
    final g = _general;
    if (g == null) {
      return Center(
        child: Text('Sin datos',
            style: TextStyle(color: Theme.of(context).colorScheme.outline)),
      );
    }
    final colones = NumberFormat.currency(symbol: '₡', decimalDigits: 2);
    double n(String k) => (g[k] as num?)?.toDouble() ?? 0.0;
    final totalAPagar = n('SUM_TOTAL_A_PAGAR');
    final diferencia = totalAPagar - _cardsTotal + n('APARTADOS_COBRADOS') - n('APARTADOS_FACTURADOS_POR_OTRO_USUARIO');
    final tiles = <(String, String)>[
      ('Venta Bruta', colones.format(n('BrutTotal'))),
      ('Bonos', colones.format(n('TotalBonos'))),
      ('Descuentos', colones.format(n('TotalDiscount'))),
      ('Total a Pagar', colones.format(totalAPagar)),
      ('Facturas Anuladas', '${(g['TotalVoided'] as num?)?.toInt() ?? 0}'),
      ('Venta Licor', colones.format(n('Venta_Licor'))),
      ('Apartados Facturados por Otro', colones.format(n('APARTADOS_FACTURADOS_POR_OTRO_USUARIO'))),
      ('Apartados Cobrados', colones.format(n('APARTADOS_COBRADOS'))),
    ];
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final t in tiles) _SummaryTile(label: t.$1, value: t.$2),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          CardChargesSection(
            entries: _cards,
            onAdd: _addCard,
            onRemove: _removeCard,
            onChanged: () => setState(() {}),
            titleOverride: 'Cobros por Tarjeta / Gastos',
            bankLabelOverride: 'Banco/Gasto',
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: _printReceipt,
                icon: const Icon(Icons.print_outlined, size: 18),
                label: const Text('Imprimir Recibo'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(_closureId == null ? 'Guardar' : 'Actualizar'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SummaryTile(
                  label: 'Diferencia a Depositar',
                  value: colones.format(diferencia)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: textTheme.labelSmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(value,
              style: textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
