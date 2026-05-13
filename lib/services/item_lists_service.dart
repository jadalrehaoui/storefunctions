import 'package:dio/dio.dart';

import '../models/item_list_membership.dart';
import 'api_client.dart';

class ItemListsService {
  final ApiClient _client;

  ItemListsService(this._client);

  Future<dynamic> getTypes() => _client.get('/api/workdb/item-lists/types');

  Future<List<ItemListMembership>> fetchListsForCode(String code) async {
    final data = await _client.get(
      '/api/workdb/item-lists/by-code?code=${Uri.encodeQueryComponent(code)}',
    );
    final lists = (data is Map && data['lists'] is List)
        ? data['lists'] as List
        : const [];
    return lists
        .whereType<Map>()
        .map((m) => ItemListMembership.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<dynamic> getItems({String? type}) {
    if (type != null && type.isNotEmpty) {
      return _client
          .get('/api/workdb/item-lists?type=${Uri.encodeQueryComponent(type)}');
    }
    return _client.get('/api/workdb/item-lists');
  }

  Future<dynamic> addItem({required String type, required String code}) {
    return _client.post('/api/workdb/item-lists', {
      'type': type,
      'code': code,
    });
  }

  Future<dynamic> updateItem(int id, {String? type, int? qty}) {
    return _client.put('/api/workdb/item-lists/$id', {
      if (type != null) 'type': type,
      if (qty != null) 'qty': qty,
    });
  }

  Future<dynamic> deleteItem(int id) =>
      _client.delete('/api/workdb/item-lists/$id');

  Future<dynamic> bulkDeleteItems(List<int> ids) =>
      _client.deleteWithBody('/api/workdb/item-lists', {'ids': ids});

  Future<dynamic> importList({
    required String type,
    required String filePath,
    required String filename,
  }) async {
    final fd = FormData.fromMap({
      'type': type,
      'file': await MultipartFile.fromFile(filePath, filename: filename),
    });
    return _client.postMultipart('/api/workdb/item-lists/import', fd);
  }
}
