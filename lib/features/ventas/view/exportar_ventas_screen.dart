import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../di/service_locator.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../inventory/cubit/sales_by_codes_cubit.dart';
import '../../inventory/view/inventory_sales_by_codes_screen.dart';
import '../../reports/cubit/sales_report_cubit.dart';
import '../../reports/view/sales_reports_screen.dart';

enum ExportarVentasMode { ventasPorCodigos, reporteDeVentas }

/// Unified "Exportar ventas" screen — mirrors `inventory_codes_screen.dart`:
/// one title + a [SegmentedButton] mode toggle hosting multiple cubits. It
/// merges the former "Ventas por códigos" (Inventario) and "Reporte de ventas"
/// (Reportes) screens by reusing their public view widgets ([SalesByCodesView],
/// [SalesReportsView]) and providing both cubits here.
class ExportarVentasScreen extends StatelessWidget {
  const ExportarVentasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => SalesByCodesCubit(sl())),
        BlocProvider(create: (_) => SalesReportCubit(sl())),
      ],
      child: const _ExportarVentasView(),
    );
  }
}

class _ExportarVentasView extends StatefulWidget {
  const _ExportarVentasView();

  @override
  State<_ExportarVentasView> createState() => _ExportarVentasViewState();
}

class _ExportarVentasViewState extends State<_ExportarVentasView> {
  // Privileges are read once in initState — the two modes are gated by the
  // same privileges that previously guarded their standalone screens.
  late final bool _canCodes = _has('inspect_inventory');
  late final bool _canReport = _has('generate_sales_report');

  late ExportarVentasMode _mode = _canCodes
      ? ExportarVentasMode.ventasPorCodigos
      : ExportarVentasMode.reporteDeVentas;

  bool _has(String privilege) {
    final state = context.read<AuthCubit>().state;
    return state is AuthAuthenticated && state.hasPrivilege(privilege);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Guard against being stuck on a mode the user can't access.
    if (_mode == ExportarVentasMode.ventasPorCodigos && !_canCodes) {
      _mode = ExportarVentasMode.reporteDeVentas;
    } else if (_mode == ExportarVentasMode.reporteDeVentas && !_canReport) {
      _mode = ExportarVentasMode.ventasPorCodigos;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Exportar ventas', style: textTheme.headlineSmall),
          const SizedBox(height: 16),
          if (_canCodes || _canReport)
            SegmentedButton<ExportarVentasMode>(
              segments: [
                if (_canCodes)
                  const ButtonSegment(
                    value: ExportarVentasMode.ventasPorCodigos,
                    label: Text('Ventas por códigos'),
                    icon: Icon(Icons.qr_code_2, size: 18),
                  ),
                if (_canReport)
                  const ButtonSegment(
                    value: ExportarVentasMode.reporteDeVentas,
                    label: Text('Reporte de ventas'),
                    icon: Icon(Icons.receipt_long_outlined, size: 18),
                  ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
          const SizedBox(height: 4),
          Expanded(child: _buildMode()),
        ],
      ),
    );
  }

  Widget _buildMode() {
    if (!_canCodes && !_canReport) {
      return const Center(child: Text('Sin acceso'));
    }
    switch (_mode) {
      case ExportarVentasMode.ventasPorCodigos:
        return const SalesByCodesView();
      case ExportarVentasMode.reporteDeVentas:
        return const SalesReportsView();
    }
  }
}
