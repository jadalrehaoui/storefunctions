import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../cubit/nav_cubit.dart';
import '../../../l10n/l10n.dart';
import 'nav_config.dart';

class NavSubItemWidget extends StatelessWidget {
  final NavSubConfig config;

  const NavSubItemWidget({required this.config, super.key});

  @override
  Widget build(BuildContext context) {
    final activeRoute = context.select((NavCubit c) => c.state.activeRoute);
    final isActive = activeRoute == config.route;
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          context.read<NavCubit>().setActiveRoute(config.route);
          context.go(config.route);
        },
        child: Container(
          height: 36,
          padding: const EdgeInsets.only(left: 24, right: 8),
          decoration: isActive
              ? BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: Row(
            children: [
              Icon(
                config.icon,
                size: 18,
                color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  config.label(l10n),
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isActive ? colorScheme.primary : null,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.normal,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
