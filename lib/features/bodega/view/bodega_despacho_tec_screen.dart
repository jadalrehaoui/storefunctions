import 'package:flutter/material.dart';

import '../cubit/despacho_cubit.dart';
import 'despacho_view.dart';

class BodegaDespachoTecScreen extends StatelessWidget {
  const BodegaDespachoTecScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DespachoView(
      channel: DespachoChannel.tec,
      title: 'Despacho Tec',
    );
  }
}
