import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../services/api_client.dart';
import '../utils/closure_email.dart' show sendClosureEmail;
import '../utils/closure_pdf.dart' show buildClosurePdfBytes;
import 'cierre_sitsa_cubit.dart' show EmailConfig;

sealed class ClosureDetailState {}

class ClosureDetailLoading extends ClosureDetailState {}

class ClosureDetailLoaded extends ClosureDetailState {
  final Map<String, dynamic> closure;
  ClosureDetailLoaded(this.closure);
}

class ClosureDetailFailure extends ClosureDetailState {
  final String error;
  ClosureDetailFailure(this.error);
}

class ClosureDetailCubit extends Cubit<ClosureDetailState> {
  final ApiClient _api;

  ClosureDetailCubit(this._api) : super(ClosureDetailLoading());

  Future<void> load(String id) async {
    emit(ClosureDetailLoading());
    try {
      final res = await _api.get('/api/workdb/closures/$id');
      final data = res['data'] ?? res;
      emit(ClosureDetailLoaded(Map<String, dynamic>.from(data as Map)));
    } catch (e) {
      emit(ClosureDetailFailure(e.toString()));
    }
  }

  Future<void> update(String id, Map<String, dynamic> payload) async {
    await _api.put('/api/workdb/closures/$id', payload);
    await load(id);
  }

  /// Regenerates the closure PDF and re-sends it by email using the current
  /// `cierre_sitsa` SMTP config. Throws on failure so the caller can surface it.
  Future<void> resendEmail(
    Map<String, dynamic> closure, {
    required bool showCosts,
  }) async {
    final res = await _api.get('/api/workdb/email-configs/cierre_sitsa');
    final configData = res is Map && res['data'] is Map
        ? Map<String, dynamic>.from(res['data'] as Map)
        : Map<String, dynamic>.from(res as Map);
    final config = EmailConfig.fromJson(configData);

    final pdfBytes = await buildClosurePdfBytes(closure, showCosts: showCosts);

    final date = DateTime.tryParse('${closure['date']}') ?? DateTime.now();
    await sendClosureEmail(config: config, pdfBytes: pdfBytes, date: date);
  }
}
