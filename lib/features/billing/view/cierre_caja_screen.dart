import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

class CierreCajaScreen extends StatelessWidget {
  const CierreCajaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.navCierreCaja)),
      body: const SizedBox.shrink(),
    );
  }
}
