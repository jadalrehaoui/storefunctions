import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../cubit/nav_cubit.dart';
import '../../../l10n/l10n.dart';
import 'nav_config.dart';
import 'nav_sub_item_widget.dart';

class NavItemWidget extends StatelessWidget {
  final NavItemConfig config;
  final bool isCollapsed;

  const NavItemWidget({
    required this.config,
    required this.isCollapsed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isOpen = context.select(
      (NavCubit c) => c.state.openItems.contains(config.id),
    );
    final l10n = context.l10n;
    final hasSubItems = config.subItems.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: Icon(config.icon),
          title: isCollapsed ? null : Text(config.label(l10n)),
          trailing: hasSubItems && !isCollapsed
              ? Icon(
                  isOpen ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                )
              : null,
          onTap: () {
            if (hasSubItems) {
              context.read<NavCubit>().toggleItem(config.id);
            } else if (config.route != null) {
              context.go(config.route!);
            }
          },
        ),
        if (!isCollapsed && isOpen)
          ...config.subItems.map(
            (sub) => NavSubItemWidget(config: sub),
          ),
      ],
    );
  }
}
