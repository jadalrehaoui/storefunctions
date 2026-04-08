import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../di/service_locator.dart';
import '../../../features/auth/cubit/auth_cubit.dart';
import '../../../l10n/l10n.dart';
import '../cubit/users_cubit.dart';

const _validPrivileges = [
  'see_dashboard',
  'see_profit_margins',
  'inspect_inventory',
  'print_labels',
  'generate_inventory',
  'generate_sales_report',
  'create_users',
  'edit_user',
  'delete_user',
  'generate_closure',
  'edit_closure',
  'inspect_closures',
  'delete_closure',
  'generate_restock_list',
  'create_invoice',
  'view_invoices',
  'edit_invoice',
  'void_invoice',
  'reprint_invoice',
  'approve_discount',
];

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => UsersCubit(sl())..load(),
      child: const _UsersView(),
    );
  }
}

class _UsersView extends StatelessWidget {
  const _UsersView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(context.l10n.usersTitle, style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: Text(context.l10n.btnAddUser),
                onPressed: () => _showAddDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: BlocListener<UsersCubit, UsersState>(
              listener: (context, state) {
                if (state is UsersDeleteError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.msgDeleteForbidden),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              },
              child: const _UsersTable(),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<UsersCubit>(),
        child: const _AddUserDialog(),
      ),
    );
  }
}

class _UsersTable extends StatelessWidget {
  const _UsersTable();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UsersCubit, UsersState>(
      builder: (context, state) => switch (state) {
        UsersLoading() => const Center(child: CircularProgressIndicator()),
        UsersFailure(:final error) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.read<UsersCubit>().load(),
                  child: Text(context.l10n.btnRetry),
                ),
              ],
            ),
          ),
        UsersLoaded(:final users) => users.isEmpty
            ? Center(child: Text(context.l10n.msgNoUsersFound))
            : _Table(users: users),
        UsersDeleteError() => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Table extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  const _Table({required this.users});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final authState = context.watch<AuthCubit>().state;
    final myUsername =
        authState is AuthAuthenticated ? authState.username : '';

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            // Header
            Container(
              color: colorScheme.surfaceContainerLow,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(context.l10n.colUsername,
                        style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(context.l10n.colPrivileges,
                        style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 80),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: users.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: colorScheme.outlineVariant),
                itemBuilder: (context, i) {
                  final user = users[i];
                  final id = user['id'] as int? ?? 0;
                  final username = user['username'] as String? ?? '';
                  final rawPrivileges = user['privileges'];
                  final privileges = rawPrivileges is List
                      ? rawPrivileges.map((e) => e.toString()).toList()
                      : <String>[];
                  final isSelf = username == myUsername;

                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    color: i.isOdd
                        ? colorScheme.surfaceContainerLowest
                        : null,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(username,
                              style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500)),
                        ),
                        Expanded(
                          flex: 3,
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: privileges
                                .map((p) => _PrivilegeBadge(privilege: p))
                                .toList(),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: context.l10n.tooltipEdit,
                              onPressed: () => _showEditDialog(
                                context,
                                id: id,
                                username: username,
                                privileges: privileges,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: isSelf
                                    ? colorScheme.outlineVariant
                                    : colorScheme.error,
                              ),
                              tooltip: isSelf
                                  ? context.l10n.tooltipCannotDeleteSelf
                                  : context.l10n.tooltipDelete,
                              onPressed: isSelf
                                  ? null
                                  : () =>
                                      _confirmDelete(context, id, username),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(
    BuildContext context, {
    required int id,
    required String username,
    required List<String> privileges,
  }) {
    showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<UsersCubit>(),
        child: _EditUserDialog(
          id: id,
          initialUsername: username,
          initialPrivileges: privileges,
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, int id, String username) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.deleteUserTitle),
        content: Text(context.l10n.deleteUserConfirm(username)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.btnCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<UsersCubit>().deleteUser(id);
            },
            child: Text(context.l10n.btnDelete),
          ),
        ],
      ),
    );
  }
}

class _PrivilegeBadge extends StatelessWidget {
  final String privilege;
  const _PrivilegeBadge({required this.privilege});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        privilege,
        style: TextStyle(
          fontSize: 11,
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _AddUserDialog extends StatefulWidget {
  const _AddUserDialog();

  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _selectedPrivileges = <String>[];
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      await context.read<UsersCubit>().createUser(
            username: _usernameCtrl.text.trim(),
            password: _passwordCtrl.text.trim(),
            privileges: _selectedPrivileges,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _UserFormDialog(
      title: context.l10n.btnAddUser,
      usernameCtrl: _usernameCtrl,
      passwordCtrl: _passwordCtrl,
      usernameRequired: true,
      passwordRequired: true,
      selectedPrivileges: _selectedPrivileges,
      onPrivilegeToggled: (p, v) => setState(() {
        v ? _selectedPrivileges.add(p) : _selectedPrivileges.remove(p);
      }),
      saving: _saving,
      error: _error,
      formKey: _formKey,
      onSave: _save,
    );
  }
}

class _EditUserDialog extends StatefulWidget {
  final int id;
  final String initialUsername;
  final List<String> initialPrivileges;

  const _EditUserDialog({
    required this.id,
    required this.initialUsername,
    required this.initialPrivileges,
  });

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  late List<String> _selectedPrivileges;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedPrivileges = List.from(widget.initialPrivileges);
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final username = _usernameCtrl.text.trim().isEmpty
        ? widget.initialUsername
        : _usernameCtrl.text.trim();
    final password = _passwordCtrl.text.trim().isEmpty
        ? null
        : _passwordCtrl.text.trim();
    final privilegesChanged =
        _selectedPrivileges.toSet() != widget.initialPrivileges.toSet();

    if (username == widget.initialUsername &&
        password == null &&
        !privilegesChanged) {
      setState(() => _error = context.l10n.msgNoChangesToSave);
      return;
    }

    setState(() { _saving = true; _error = null; });
    try {
      await context.read<UsersCubit>().editUser(
            widget.id,
            username: username,
            password: password,
            privileges: _selectedPrivileges,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _UserFormDialog(
      title: context.l10n.editUserTitle(widget.initialUsername),
      usernameCtrl: _usernameCtrl,
      passwordCtrl: _passwordCtrl,
      usernameRequired: false,
      passwordRequired: false,
      selectedPrivileges: _selectedPrivileges,
      onPrivilegeToggled: (p, v) => setState(() {
        v ? _selectedPrivileges.add(p) : _selectedPrivileges.remove(p);
      }),
      saving: _saving,
      error: _error,
      formKey: _formKey,
      onSave: _save,
    );
  }
}

class _UserFormDialog extends StatelessWidget {
  final String title;
  final TextEditingController usernameCtrl;
  final TextEditingController passwordCtrl;
  final bool usernameRequired;
  final bool passwordRequired;
  final List<String> selectedPrivileges;
  final void Function(String, bool) onPrivilegeToggled;
  final bool saving;
  final String? error;
  final GlobalKey<FormState> formKey;
  final VoidCallback onSave;

  const _UserFormDialog({
    required this.title,
    required this.usernameCtrl,
    required this.passwordCtrl,
    required this.usernameRequired,
    required this.passwordRequired,
    required this.selectedPrivileges,
    required this.onPrivilegeToggled,
    required this.saving,
    required this.error,
    required this.formKey,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 360,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: usernameCtrl,
                decoration: InputDecoration(
                  labelText: usernameRequired
                      ? context.l10n.labelUsername
                      : context.l10n.labelNewUsername,
                  hintText:
                      usernameRequired ? null : context.l10n.hintLeaveBlankCurrent,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                validator: usernameRequired
                    ? (v) => (v == null || v.trim().isEmpty)
                        ? context.l10n.labelRequired
                        : null
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: passwordRequired
                      ? context.l10n.labelPassword
                      : context.l10n.labelNewPassword,
                  hintText:
                      passwordRequired ? null : context.l10n.hintLeaveBlankCurrent,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                validator: passwordRequired
                    ? (v) => (v == null || v.trim().isEmpty)
                        ? context.l10n.labelRequired
                        : null
                    : null,
              ),
              const SizedBox(height: 16),
              Text(context.l10n.labelPrivileges,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _validPrivileges.map((p) {
                  return FilterChip(
                    label: Text(p, style: const TextStyle(fontSize: 12)),
                    selected: selectedPrivileges.contains(p),
                    onSelected: (v) => onPrivilegeToggled(p, v),
                  );
                }).toList(),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!,
                    style: TextStyle(
                        color: colorScheme.error, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.of(context).pop(),
          child: Text(context.l10n.btnCancel),
        ),
        FilledButton(
          onPressed: saving ? null : onSave,
          child: saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(context.l10n.btnSave),
        ),
      ],
    );
  }
}
