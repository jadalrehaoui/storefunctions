import 'api_client.dart';

class InventoryService {
  final ApiClient _client;
  static const _sitsaBodega = 'B-01';

  InventoryService(this._client);

  Future<dynamic> searchByBarcode(String articleId) {
    return _client.post('/api/sitsa/get-item', {'code': articleId});
  }

  Future<dynamic> getTicaData(String barcode) {
    return _client.post('/api/tica/get-tica-data', {'barcode': barcode});
  }

  Future<dynamic> searchByDescripcion(String description) {
    return _client.post('/api/sitsa/search-text', {
      'text': description,
      'bodega': _sitsaBodega,
    });
  }

  Future<dynamic> getInventory({String? startingDate, String? endingDate}) {
    return _client.post('/api/sitsa/get-inventory', {
      'bodega': _sitsaBodega,
      if (startingDate != null) 'startingDate': startingDate,
      if (endingDate != null) 'endingDate': endingDate,
    });
  }

  Future<dynamic> getItemsByModelo(String modelo) {
    return _client.post('/api/sitsa/get-items-by-modelo', {
      'modelo': modelo,
      'bodega': _sitsaBodega,
    });
  }

  Future<dynamic> getItemCombined(String code) {
    return _client.post('/api/combined/get-item', {'code': code});
  }
}
