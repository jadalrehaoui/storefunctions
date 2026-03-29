import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/cubit/health_cubit.dart';
import '../../../shared/cubit/locale_cubit.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.settingsTitle, style: textTheme.headlineSmall),
          const SizedBox(height: 32),

          // ── Language ───────────────────────────────────────────────────
          Text(context.l10n.labelLanguage,
              style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _LanguageToggle(),
          const SizedBox(height: 32),
          Divider(color: colorScheme.outlineVariant),
          const SizedBox(height: 24),

          // ── Database connections ───────────────────────────────────────
          Text(context.l10n.labelDatabaseConnections,
              style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _DatabaseStatus(),
        ],
      ),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleCubit>().state;
    final isSpanish = locale.languageCode == 'es';
    final colorScheme = Theme.of(context).colorScheme;
    final cubit = context.read<LocaleCubit>();

    return Row(
      children: [
        _LangChip(
          label: 'English',
          selected: !isSpanish,
          onTap: cubit.setEnglish,
          colorScheme: colorScheme,
        ),
        const SizedBox(width: 8),
        _LangChip(
          label: 'Español',
          selected: isSpanish,
          onTap: cubit.setSpanish,
          colorScheme: colorScheme,
        ),
      ],
    );
  }
}

class _LangChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _LangChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? colorScheme.primary
                : colorScheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _DatabaseStatus extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final health = context.watch<HealthCubit>().state;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        _DbRow(label: 'Mikail', status: health.mikail, colorScheme: colorScheme),
        const SizedBox(height: 8),
        _DbRow(label: 'SITSA', status: health.sitsa, colorScheme: colorScheme),
        const SizedBox(height: 8),
        _DbRow(label: 'WorkDB', status: health.workdb, colorScheme: colorScheme),
      ],
    );
  }
}

class _DbRow extends StatelessWidget {
  final String label;
  final DbHealth status;
  final ColorScheme colorScheme;

  const _DbRow({
    required this.label,
    required this.status,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final color = switch (status) {
      DbHealth.connected => const Color(0xFF4CAF50),
      DbHealth.disconnected => colorScheme.error,
      DbHealth.checking => colorScheme.outlineVariant,
    };

    final l10n = context.l10n;
    final statusLabel = switch (status) {
      DbHealth.connected => l10n.statusConnected,
      DbHealth.disconnected => l10n.statusDisconnected,
      DbHealth.checking => l10n.statusChecking,
    };

    final bgColor = switch (status) {
      DbHealth.connected => const Color(0xFF4CAF50).withOpacity(0.08),
      DbHealth.disconnected => colorScheme.errorContainer,
      DbHealth.checking => colorScheme.surfaceContainerLow,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Text(label,
              style: textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(statusLabel,
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
