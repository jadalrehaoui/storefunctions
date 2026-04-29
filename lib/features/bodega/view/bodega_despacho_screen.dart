import 'package:flutter/material.dart';

import '../cubit/despacho_cubit.dart';
import 'despacho_view.dart';

class BodegaDespachoScreen extends StatelessWidget {
  const BodegaDespachoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DespachoView(
      channel: DespachoChannel.bodega,
      title: 'Despacho Bod',
    );
  }
}
