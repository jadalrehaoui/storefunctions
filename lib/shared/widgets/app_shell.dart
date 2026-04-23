import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../di/service_locator.dart';
import '../cubit/health_cubit.dart';
import '../cubit/nav_cubit.dart';
import 'side_nav/side_nav.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => NavCubit()),
        BlocProvider.value(value: sl<HealthCubit>()),
      ],
      child: Platform.isAndroid
          ? _AndroidShell(child: child)
          : _DesktopShell(child: child),
    );
  }
}

class _DesktopShell extends StatelessWidget {
  final Widget child;
  const _DesktopShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const SideNav(),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _AndroidShell extends StatelessWidget {
  final Widget child;
  const _AndroidShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final canPop = GoRouter.of(context).canPop();
    return Scaffold(
      appBar: AppBar(
        title: Text(_titleFor(location)),
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              )
            : null,
      ),
      body: child,
    );
  }

  String _titleFor(String location) {
    const titles = <String, String>{
      '/android/home': 'Menú',
      '/android/bodega': 'Bodega',
      '/android/inventory': 'Inventario',
      '/bodega/listas': 'Listas',
      '/bodega/dispatcho': 'Dispatcho',
      '/inventory/search': 'Buscar items',
      '/inventory/print-labels': 'Imprimir etiquetas',
      '/settings': 'Configuración',
    };
    return titles[location] ?? 'Sistema';
  }
}
