import 'dart:async';
import 'dart:convert';

import '../features/bodega/model/bodega_lista_item.dart';
import 'api_client.dart';

sealed class BodegaListaEvent {
  const BodegaListaEvent();
}

class BodegaItemAddedEvent extends BodegaListaEvent {
  final BodegaListaItem item;
  const BodegaItemAddedEvent(this.item);
}

class BodegaItemUpdatedEvent extends BodegaListaEvent {
  final BodegaListaItem item;
  const BodegaItemUpdatedEvent(this.item);
}

class BodegaItemsRemovedEvent extends BodegaListaEvent {
  final List<int> ids;
  const BodegaItemsRemovedEvent(this.ids);
}

class BodegaService {
  final ApiClient _client;

  BodegaService(this._client);

  Future<List<BodegaListaItem>> getList() async {
    final data = await _client.get('/api/bodega/listas');
    final items = (data is Map && data['items'] is List)
        ? data['items'] as List<dynamic>
        : <dynamic>[];
    return items
        .map((e) => BodegaListaItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BodegaListaItem> addItem(String code) async {
    final data = await _client.post('/api/bodega/listas/items', {'code': code});
    return BodegaListaItem.fromJson(data as Map<String, dynamic>);
  }

  Future<int> removeItems(List<int> ids) async {
    final data = await _client
        .deleteWithBody('/api/bodega/listas/items', {'ids': ids});
    return (data is Map && data['removed'] is num)
        ? (data['removed'] as num).toInt()
        : ids.length;
  }

  Future<void> removeItem(int id) async {
    await _client.delete('/api/bodega/listas/items/$id');
  }

  /// Subscribes to the Bodega listas SSE stream.
  ///
  /// Emits parsed events as they arrive. On network drop the caller is
  /// expected to resubscribe (the cubit handles this).
  Stream<BodegaListaEvent> subscribe() async* {
    final body = await _client.getStream('/api/bodega/listas/stream');
    final lines = body.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    String? eventName;
    final dataBuf = StringBuffer();

    await for (final line in lines) {
      if (line.isEmpty) {
        if (eventName != null && dataBuf.isNotEmpty) {
          final parsed = _parseEvent(eventName, dataBuf.toString());
          if (parsed != null) yield parsed;
        }
        eventName = null;
        dataBuf.clear();
        continue;
      }
      if (line.startsWith(':')) continue;
      if (line.startsWith('event:')) {
        eventName = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        if (dataBuf.isNotEmpty) dataBuf.write('\n');
        dataBuf.write(line.substring(5).trim());
      }
    }
  }

  BodegaListaEvent? _parseEvent(String name, String data) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) return null;
      switch (name) {
        case 'item_added':
          final item = json['item'] as Map<String, dynamic>?;
          if (item == null) return null;
          return BodegaItemAddedEvent(BodegaListaItem.fromJson(item));
        case 'item_updated':
          final item = json['item'] as Map<String, dynamic>?;
          if (item == null) return null;
          return BodegaItemUpdatedEvent(BodegaListaItem.fromJson(item));
        case 'items_removed':
          final ids = (json['ids'] as List?)
                  ?.map((e) => (e as num).toInt())
                  .toList() ??
              const <int>[];
          return BodegaItemsRemovedEvent(ids);
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
