import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/cubit/auth_cubit.dart';

const redacted = '••••••';

bool canSeeProfitMargins(BuildContext context) {
  final state = context.read<AuthCubit>().state;
  return state is AuthAuthenticated && state.hasPrivilege('see_profit_margins');
}

bool _hasPrivilege(BuildContext context, String p) {
  final state = context.read<AuthCubit>().state;
  return state is AuthAuthenticated && state.hasPrivilege(p);
}

bool canCreateInvoice(BuildContext context) =>
    _hasPrivilege(context, 'create_invoice');
bool canViewInvoices(BuildContext context) =>
    _hasPrivilege(context, 'view_invoices');
bool canEditInvoice(BuildContext context) =>
    _hasPrivilege(context, 'edit_invoice');
bool canVoidInvoice(BuildContext context) =>
    _hasPrivilege(context, 'void_invoice');
bool canApproveDiscount(BuildContext context) =>
    _hasPrivilege(context, 'approve_discount');
