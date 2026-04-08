import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

class InvoiceScreen extends StatelessWidget {
  const InvoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.navInvoice)),
      body: const SizedBox.shrink(),
    );
  }
}
