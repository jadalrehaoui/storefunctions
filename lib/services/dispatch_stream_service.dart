import 'dart:async';
import 'dart:convert';

import '../features/bodega/model/ferreteria_invoice.dart';
import 'api_client.dart';

class DispatchStreamService {
  static const String bodegaPath = '/api/dispatch/bodega/stream';
  static const String techPath = '/api/dispatch/tech/stream';

  final ApiClient _client;

  DispatchStreamService(this._client);

  /// Subscribes to a dispatch SSE stream. Emits one [FerreteriaInvoice]
  /// per `data:` event. Comment lines (`:`) and pings are ignored. The
  /// stream closes when the underlying HTTP connection ends — callers
  /// should resubscribe to recover from drops.
  Stream<FerreteriaInvoice> subscribe(String path) async* {
    final body = await _client.getStream(path);
    final lines = body.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    final dataBuf = StringBuffer();

    await for (final line in lines) {
      if (line.isEmpty) {
        if (dataBuf.isNotEmpty) {
          final parsed = _parse(dataBuf.toString());
          if (parsed != null) yield parsed;
        }
        dataBuf.clear();
        continue;
      }
      if (line.startsWith(':')) continue;
      if (line.startsWith('data:')) {
        if (dataBuf.isNotEmpty) dataBuf.write('\n');
        dataBuf.write(line.substring(5).trim());
      }
    }
  }

  FerreteriaInvoice? _parse(String data) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) return null;
      return FerreteriaInvoice.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}
