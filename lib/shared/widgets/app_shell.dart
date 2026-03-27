import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/nav_cubit.dart';
import 'side_nav/side_nav.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NavCubit(),
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
