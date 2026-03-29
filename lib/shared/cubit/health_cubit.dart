import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/api_client.dart';

enum DbHealth { checking, connected, disconnected }

class HealthState {
  final DbHealth mikail;
  final DbHealth sitsa;
  final DbHealth workdb;

  const HealthState({
    this.mikail = DbHealth.checking,
    this.sitsa = DbHealth.checking,
    this.workdb = DbHealth.checking,
  });

  HealthState copyWith({DbHealth? mikail, DbHealth? sitsa, DbHealth? workdb}) {
    return HealthState(
      mikail: mikail ?? this.mikail,
      sitsa: sitsa ?? this.sitsa,
      workdb: workdb ?? this.workdb,
    );
  }
}

class HealthCubit extends Cubit<HealthState> {
  final ApiClient _api;
  Timer? _timer;

  HealthCubit(this._api) : super(const HealthState()) {
    _checkAll();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _checkAll());
  }

  Future<void> _checkAll() async {
    await Future.wait([
      _check('/api/mikail/health', (s) => copyWith(mikail: s)),
      _check('/api/sitsa/health', (s) => copyWith(sitsa: s)),
      _check('/api/workdb/health', (s) => copyWith(workdb: s)),
    ]);
  }

  Future<void> _check(
    String path,
    void Function(DbHealth) updater,
  ) async {
    try {
      final data = await _api.get(path) as Map<String, dynamic>;
      updater(
        data['status'] == 'connected'
            ? DbHealth.connected
            : DbHealth.disconnected,
      );
    } catch (_) {
      updater(DbHealth.disconnected);
    }
  }

  void copyWith({DbHealth? mikail, DbHealth? sitsa, DbHealth? workdb}) {
    emit(state.copyWith(mikail: mikail, sitsa: sitsa, workdb: workdb));
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
