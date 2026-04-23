import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../di/service_locator.dart';
import '../../../services/api_client.dart';
import '../../../shared/constants.dart';
import '../cubit/auth_cubit.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isRemote = ApiClient.currentBaseUrl == ApiClient.remoteBaseUrl;
  late Future<bool> _isOutdatedFuture;

  @override
  void initState() {
    super.initState();
    _isOutdatedFuture = _checkVersion();
  }

  Future<bool> _checkVersion() async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiClient.currentBaseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ));
      final response = await dio.get<dynamic>('/api/workdb/current-version');
      final data = response.data;
      if (data is Map && data['version'] != null) {
        return data['version'] != appVersion;
      }
    } catch (_) {}
    return false;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthCubit>().login(
            _usernameController.text.trim().toLowerCase(),
            _passwordController.text,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isAndroid = Platform.isAndroid;
    final cardWidth = isAndroid ? 520.0 : 360.0;
    final cardPadding = isAndroid ? 40.0 : 32.0;
    final logoSize = isAndroid ? 80.0 : 48.0;
    final fieldGap = isAndroid ? 24.0 : 16.0;
    final buttonPadding = isAndroid
        ? const EdgeInsets.symmetric(vertical: 18)
        : const EdgeInsets.symmetric(vertical: 12);
    final inputContentPadding = isAndroid
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 20)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 14);

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
          elevation: 2,
          child: Container(
            width: cardWidth,
            padding: EdgeInsets.all(cardPadding),
            child: Stack(
              children: [
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Switch(
                    value: _isRemote,
                    onChanged: (v) {
                      setState(() {
                        _isRemote = v;
                        sl<ApiClient>().setBaseUrl(v
                            ? ApiClient.remoteBaseUrl
                            : ApiClient.localBaseUrl);
                        _isOutdatedFuture = _checkVersion();
                      });
                    },
                    thumbIcon: WidgetStateProperty.resolveWith(
                      (states) => Icon(
                        states.contains(WidgetState.selected)
                            ? Icons.public
                            : Icons.storefront,
                        size: 16,
                      ),
                    ),
                  ),
                ),
                BlocConsumer<AuthCubit, AuthState>(
              listener: (context, state) {
                // Navigation is handled by the router redirect.
                // Nothing to do here.
              },
              builder: (context, state) {
                final isLoading = state is AuthLoading;

                return Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.store_rounded,
                        size: logoSize,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Storefunctions',
                        textAlign: TextAlign.center,
                        style: (isAndroid
                                ? Theme.of(context).textTheme.headlineMedium
                                : Theme.of(context).textTheme.headlineSmall)
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      FutureBuilder<bool>(
                        future: _isOutdatedFuture,
                        builder: (context, snapshot) {
                          final isOutdated = snapshot.data ?? false;
                          return Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'v$appVersion',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                                ),
                                if (isOutdated) ...[
                                  const SizedBox(width: 4),
                                  Icon(Icons.update, size: 14, color: colorScheme.error),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _usernameController,
                        enabled: !isLoading,
                        decoration: InputDecoration(
                          labelText: 'Usuario',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: const OutlineInputBorder(),
                          contentPadding: inputContentPadding,
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      ),
                      SizedBox(height: fieldGap),
                      TextFormField(
                        controller: _passwordController,
                        enabled: !isLoading,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          contentPadding: inputContentPadding,
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Requerido' : null,
                      ),
                      if (state is AuthFailure) ...[
                        const SizedBox(height: 12),
                        Text(
                          state.message,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        style: FilledButton.styleFrom(padding: buttonPadding),
                        onPressed: isLoading ? null : _submit,
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Iniciar sesión',
                                style: TextStyle(
                                    fontSize: isAndroid ? 18 : 14,
                                    fontWeight: FontWeight.w600),
                              ),
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                );
              },
            ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}
