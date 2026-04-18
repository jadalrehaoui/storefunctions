import 'package:flutter/material.dart';

class AutomaticPlScreen extends StatelessWidget {
  const AutomaticPlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Automatic PL', style: textTheme.headlineSmall),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: Text(
                'Próximamente.',
                style: textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
