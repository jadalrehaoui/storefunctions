import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

class CierreCajaSitsaScreen extends StatelessWidget {
  const CierreCajaSitsaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.navCierreCajaSitsa)),
      body: const SizedBox.shrink(),
    );
  }
}
