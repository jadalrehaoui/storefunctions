import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        context.l10n.inventoryTitle,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    );
  }
}
