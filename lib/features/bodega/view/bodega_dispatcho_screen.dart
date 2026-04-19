import 'package:flutter/material.dart';

class BodegaDispatchoScreen extends StatelessWidget {
  const BodegaDispatchoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dispatcho', style: textTheme.headlineSmall),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_shipping_outlined,
                      size: 64, color: colorScheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text('Coming soon',
                      style: textTheme.titleMedium
                          ?.copyWith(color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
