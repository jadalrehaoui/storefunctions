import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../services/despacho_mode_service.dart';
import '../../../services/dispatch_stream_service.dart';
import '../../../services/receipt_printer_service.dart';
import '../model/ferreteria_invoice.dart';
import '../utils/despacho_receipt_pdf.dart';

enum DespachoChannel { bodega, tec }

class DespachoChannelState {
  final bool connected;
  final String? error;
  final List<FerreteriaInvoice> invoices;

  const DespachoChannelState({
    this.connected = false,
    this.error,
    this.invoices = const [],
  });

  DespachoChannelState copyWith({
    bool? connected,
    String? error,
    bool clearError = false,
    List<FerreteriaInvoice>? invoices,
  }) {
    return DespachoChannelState(
      connected: connected ?? this.connected,
      error: clearError ? null : (error ?? this.error),
      invoices: invoices ?? this.invoices,
    );
  }
}

class DespachoState {
  final bool bodegaEnabled;
  final bool tecnologiaEnabled;
  final DespachoChannelState bodega;
  final DespachoChannelState tec;

  const DespachoState({
    this.bodegaEnabled = false,
    this.tecnologiaEnabled = false,
    this.bodega = const DespachoChannelState(),
    this.tec = const DespachoChannelState(),
  });

  DespachoState copyWith({
    bool? bodegaEnabled,
    bool? tecnologiaEnabled,
    DespachoChannelState? bodega,
    DespachoChannelState? tec,
  }) {
    return DespachoState(
      bodegaEnabled: bodegaEnabled ?? this.bodegaEnabled,
      tecnologiaEnabled: tecnologiaEnabled ?? this.tecnologiaEnabled,
      bodega: bodega ?? this.bodega,
      tec: tec ?? this.tec,
    );
  }
}

/// Owns two independent SSE pipelines (bodega and tec dispatch), enforces
/// mutual exclusion on the two "this is a despacho machine" flags, and
/// auto-prints incoming invoices on the channel whose flag is on. A
/// channel stays connected as long as its flag is on OR at least one
/// screen has called [requestActive] for that channel.
class DespachoCubit extends Cubit<DespachoState> {
  static const _maxInvoices = 100;
  static const _maxSeen = 1000;

  final DispatchStreamService _stream;
  final ReceiptPrinterService _printer;
  final DespachoModeService _mode;

  final _Pipeline _bodega;
  final _Pipeline _tec;

  DespachoCubit(this._stream, this._printer, this._mode)
      : _bodega = _Pipeline(DespachoChannel.bodega),
        _tec = _Pipeline(DespachoChannel.tec),
        super(const DespachoState()) {
    _init();
  }

  Future<void> _init() async {
    final bodega = await _mode.isEnabled();
    final tec = await _mode.isTecnologiaEnabled();
    final tecResolved = bodega ? false : tec;
    if (tec && bodega) {
      await _mode.setTecnologiaEnabled(false);
    }
    emit(state.copyWith(
        bodegaEnabled: bodega, tecnologiaEnabled: tecResolved));
    _evaluateAll();
  }

  Future<void> setBodegaEnabled(bool value) async {
    if (state.bodegaEnabled == value && (!value || !state.tecnologiaEnabled)) {
      return;
    }
    await _mode.setEnabled(value);
    if (value && state.tecnologiaEnabled) {
      await _mode.setTecnologiaEnabled(false);
    }
    emit(state.copyWith(
      bodegaEnabled: value,
      tecnologiaEnabled: value ? false : state.tecnologiaEnabled,
    ));
    _evaluateAll();
  }

  Future<void> setTecnologiaEnabled(bool value) async {
    if (state.tecnologiaEnabled == value && (!value || !state.bodegaEnabled)) {
      return;
    }
    await _mode.setTecnologiaEnabled(value);
    if (value && state.bodegaEnabled) {
      await _mode.setEnabled(false);
    }
    emit(state.copyWith(
      tecnologiaEnabled: value,
      bodegaEnabled: value ? false : state.bodegaEnabled,
    ));
    _evaluateAll();
  }

  void requestActive(DespachoChannel channel) {
    _pipeline(channel).active++;
    _evaluate(channel);
  }

  void releaseActive(DespachoChannel channel) {
    final p = _pipeline(channel);
    if (p.active > 0) p.active--;
    _evaluate(channel);
  }

  void reconnect(DespachoChannel channel) {
    if (_shouldRun(channel)) _connect(channel);
  }

  void markEntregado(DespachoChannel channel, FerreteriaInvoice invoice) {
    final cs = _channelState(channel);
    final updated =
        List<FerreteriaInvoice>.from(cs.invoices)..remove(invoice);
    _emitChannel(channel, cs.copyWith(invoices: updated));
  }

  /// Despacho is desktop-only. On Android tablets the cubit stays inert.
  static final bool _platformSupported = !kIsWeb && !Platform.isAndroid;

  bool _flagFor(DespachoChannel c) => switch (c) {
        DespachoChannel.bodega => state.bodegaEnabled,
        DespachoChannel.tec => state.tecnologiaEnabled,
      };

  String _pathFor(DespachoChannel c) => switch (c) {
        DespachoChannel.bodega => DispatchStreamService.bodegaPath,
        DespachoChannel.tec => DispatchStreamService.techPath,
      };

  String _printNameFor(DespachoChannel c) => switch (c) {
        DespachoChannel.bodega => 'despacho_bodega',
        DespachoChannel.tec => 'despacho_tec',
      };

  String _printTitleFor(DespachoChannel c) => switch (c) {
        DespachoChannel.bodega => 'DESPACHO BODEGA',
        DespachoChannel.tec => 'DESPACHO TECNOLOGÍA',
      };

  _Pipeline _pipeline(DespachoChannel c) =>
      c == DespachoChannel.bodega ? _bodega : _tec;

  DespachoChannelState _channelState(DespachoChannel c) =>
      c == DespachoChannel.bodega ? state.bodega : state.tec;

  void _emitChannel(DespachoChannel c, DespachoChannelState next) {
    if (c == DespachoChannel.bodega) {
      emit(state.copyWith(bodega: next));
    } else {
      emit(state.copyWith(tec: next));
    }
  }

  bool _shouldRun(DespachoChannel c) =>
      _platformSupported && (_flagFor(c) || _pipeline(c).active > 0);

  void _evaluateAll() {
    _evaluate(DespachoChannel.bodega);
    _evaluate(DespachoChannel.tec);
  }

  void _evaluate(DespachoChannel c) {
    if (_shouldRun(c)) {
      if (_pipeline(c).sub == null) _connect(c);
    } else {
      _disconnect(c);
    }
  }

  void _connect(DespachoChannel channel) {
    final p = _pipeline(channel);
    p.sub?.cancel();
    p.retry?.cancel();
    p.retry = null;
    _emitChannel(channel, _channelState(channel)
        .copyWith(connected: false, clearError: true));
    p.sub = _stream.subscribe(_pathFor(channel)).listen(
      (invoice) {
        final key = invoice.dedupKey;
        if (key.isEmpty || !p.seen.add(key)) return;
        p.seenOrder.add(key);
        if (p.seenOrder.length > _maxSeen) {
          p.seen.remove(p.seenOrder.removeAt(0));
        }
        final cs = _channelState(channel);
        final updated = [invoice, ...cs.invoices];
        if (updated.length > _maxInvoices) {
          updated.removeRange(_maxInvoices, updated.length);
        }
        _emitChannel(
            channel, cs.copyWith(connected: true, invoices: updated));
        if (_flagFor(channel)) {
          unawaited(_autoPrint(channel, invoice));
        }
      },
      onError: (Object e) {
        _emitChannel(channel,
            _channelState(channel).copyWith(
                connected: false, error: e.toString()));
        _scheduleReconnect(channel);
      },
      onDone: () {
        _emitChannel(channel,
            _channelState(channel).copyWith(connected: false));
        _scheduleReconnect(channel);
      },
      cancelOnError: true,
    );
    _emitChannel(channel, _channelState(channel).copyWith(connected: true));
  }

  void _scheduleReconnect(DespachoChannel channel) {
    final p = _pipeline(channel);
    p.retry?.cancel();
    p.retry = Timer(const Duration(seconds: 5), () {
      if (_shouldRun(channel)) _connect(channel);
    });
  }

  void _disconnect(DespachoChannel channel) {
    final p = _pipeline(channel);
    p.sub?.cancel();
    p.sub = null;
    p.retry?.cancel();
    p.retry = null;
    p.seen.clear();
    p.seenOrder.clear();
    _emitChannel(channel, const DespachoChannelState());
  }

  Future<void> _autoPrint(
      DespachoChannel channel, FerreteriaInvoice invoice) async {
    try {
      final bytes = await buildDespachoReceiptPdf(
        invoice: invoice,
        now: DateTime.now(),
        title: _printTitleFor(channel),
      );
      final ok = await _printer.printPdf(
        bytes,
        kind: PrinterKind.receipt,
        name: _printNameFor(channel),
      );
      if (!ok) {
        await openDespachoPdf(bytes, channel: channel);
      }
    } catch (e) {
      debugPrint('Despacho auto-print failed (${channel.name}): $e');
    }
  }

  @override
  Future<void> close() {
    _bodega.dispose();
    _tec.dispose();
    return super.close();
  }
}

class _Pipeline {
  final DespachoChannel channel;
  StreamSubscription<FerreteriaInvoice>? sub;
  Timer? retry;
  int active = 0;
  final Set<String> seen = {};
  final List<String> seenOrder = [];

  _Pipeline(this.channel);

  void dispose() {
    sub?.cancel();
    retry?.cancel();
  }
}
