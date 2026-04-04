import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/cubit/auth_cubit.dart';

const redacted = '••••••';

bool canSeeProfitMargins(BuildContext context) {
  final state = context.read<AuthCubit>().state;
  return state is AuthAuthenticated && state.hasPrivilege('see_profit_margins');
}
