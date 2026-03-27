import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cubit/nav_cubit.dart';
import '../../../l10n/l10n.dart';
import 'nav_config.dart';
import 'nav_item_widget.dart';

class SideNav extends StatelessWidget {
  const SideNav({super.key});

  static const double _expandedWidth = 220;
  static const double _collapsedWidth = 64;

  @override
  Widget build(BuildContext context) {
    final isCollapsed = context.select((NavCubit c) => c.state.isCollapsed);
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: isCollapsed ? _collapsedWidth : _expandedWidth,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ToggleButton(isCollapsed: isCollapsed),
          const Divider(height: 1, indent: 0, endIndent: 0),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: navItems
                  .map((item) => NavItemWidget(
                        config: item,
                        isCollapsed: isCollapsed,
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final bool isCollapsed;

  const _ToggleButton({required this.isCollapsed});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SizedBox(
      height: 48,
      child: Align(
        alignment: isCollapsed ? Alignment.center : Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: IconButton(
            onPressed: context.read<NavCubit>().toggleCollapse,
            icon: Icon(
              isCollapsed ? Icons.chevron_right : Icons.chevron_left,
              size: 20,
            ),
            tooltip: isCollapsed ? l10n.navExpand : l10n.navCollapse,
          ),
        ),
      ),
    );
  }
}
