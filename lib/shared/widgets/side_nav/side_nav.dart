import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../di/service_locator.dart';
import '../../../features/auth/cubit/auth_cubit.dart';
import '../../../services/api_client.dart';
import '../../constants.dart';
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
            child: Builder(
              builder: (context) {
                final authState = context.watch<AuthCubit>().state;
                final privileges = authState is AuthAuthenticated
                    ? authState.privileges
                    : <String>[];

                bool hasAccess(String? privilege) =>
                    privilege == null || privileges.contains(privilege);

                final visibleItems = navItemsForPlatform()
                    .where((item) => hasAccess(item.privilege))
                    .map((item) {
                      final visibleSubs = item.subItems
                          .where((s) => hasAccess(s.privilege))
                          .toList();
                      // hide parent if it only exists for its sub-items and none are visible
                      if (item.subItems.isNotEmpty && visibleSubs.isEmpty) {
                        return null;
                      }
                      return (item: item, subs: visibleSubs);
                    })
                    .whereType<({NavItemConfig item, List<NavSubConfig> subs})>()
                    .toList();

                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: visibleItems
                      .map((e) => NavItemWidget(
                            config: e.item,
                            visibleSubItems: e.subs,
                            isCollapsed: isCollapsed,
                          ))
                      .toList(),
                );
              },
            ),
          ),
          const Divider(height: 1),
          _BottomBar(isCollapsed: isCollapsed),
        ],
      ),
    );
  }
}

class _BottomBar extends StatefulWidget {
  final bool isCollapsed;

  const _BottomBar({required this.isCollapsed});

  @override
  State<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<_BottomBar> {
  late final Future<_VersionInfo> _versionFuture;

  @override
  void initState() {
    super.initState();
    _versionFuture = _fetchVersion();
  }

  Future<_VersionInfo> _fetchVersion() async {
    try {
      final data = await sl<ApiClient>().get('/api/workdb/current-version');
      if (data is Map && data['version'] != null) {
        final serverVersion = data['version'] as String;
        return _VersionInfo(
          serverVersion: serverVersion,
          isOutdated: serverVersion != appVersion,
        );
      }
    } catch (_) {}
    return _VersionInfo(serverVersion: null, isOutdated: false);
  }

  Widget _versionLabel(TextTheme textTheme, ColorScheme colorScheme) {
    return FutureBuilder<_VersionInfo>(
      future: _versionFuture,
      builder: (context, snapshot) {
        final info = snapshot.data;
        final isOutdated = info?.isOutdated ?? false;
        return Tooltip(
          message: isOutdated
              ? 'Update available: v${info!.serverVersion}'
              : 'Up to date',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'v$appVersion',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (isOutdated) ...[
                const SizedBox(width: 4),
                Icon(Icons.update, size: 14, color: colorScheme.error),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (widget.isCollapsed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 48,
            child: Center(
              child: IconButton(
                onPressed: () => context.go('/settings'),
                icon: Icon(Icons.settings_outlined,
                    size: 20, color: colorScheme.onSurfaceVariant),
                tooltip: 'Settings',
              ),
            ),
          ),
          _versionLabel(textTheme, colorScheme),
          SizedBox(
            height: 48,
            child: Center(
              child: IconButton(
                onPressed: () => context.read<AuthCubit>().logout(),
                icon: Icon(Icons.logout, size: 20, color: colorScheme.error),
                tooltip: 'Cerrar sesión',
              ),
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.go('/settings'),
            icon: Icon(Icons.settings_outlined,
                size: 18, color: colorScheme.onSurfaceVariant),
            tooltip: 'Settings',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          Expanded(
            child: Center(
              child: _versionLabel(textTheme, colorScheme),
            ),
          ),
          IconButton(
            onPressed: () => context.read<AuthCubit>().logout(),
            icon: Icon(Icons.logout, size: 18, color: colorScheme.error),
            tooltip: 'Cerrar sesión',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

class _VersionInfo {
  final String? serverVersion;
  final bool isOutdated;
  const _VersionInfo({required this.serverVersion, required this.isOutdated});
}

class _ToggleButton extends StatelessWidget {
  final bool isCollapsed;

  const _ToggleButton({required this.isCollapsed});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final authState = context.watch<AuthCubit>().state;
    final username = authState is AuthAuthenticated ? authState.username : '';
    final colorScheme = Theme.of(context).colorScheme;

    final toggleBtn = IconButton(
      onPressed: context.read<NavCubit>().toggleCollapse,
      icon: Icon(
        isCollapsed ? Icons.chevron_right : Icons.chevron_left,
        size: 20,
      ),
      tooltip: isCollapsed ? l10n.navExpand : l10n.navCollapse,
    );

    if (isCollapsed) {
      return SizedBox(height: 48, child: Center(child: toggleBtn));
    }

    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 4),
        child: Row(
          children: [
            Icon(Icons.person, size: 16, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                username,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            toggleBtn,
          ],
        ),
      ),
    );
  }
}
