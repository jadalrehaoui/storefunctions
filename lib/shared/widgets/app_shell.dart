import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
      child: Scaffold(
        body: Row(
          children: [
            const SideNav(),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
