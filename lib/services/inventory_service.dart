import 'api_client.dart';

class InventoryService {
  final ApiClient _client;

  InventoryService(this._client);

  // --- SITSA credentials ---
  static const _sitsaServer = r'10.10.0.191\MSSQLSERVER2017';
  static const _sitsaDatabase = 'Punto_Venta_Sucursal';
  static const _sitsaUsername = 'sa';
  static const _sitsaPassword = 'Sql2020';
  static const _sitsaBodega = 'B-01';

  // --- Mikail credentials ---
  static const _mikailServer = '10.10.0.191';
  static const _mikailDatabase = 'Mikail';
  static const _mikailUsername = 'JAD_LCTR';
  static const _mikailPassword = 'ContraseñaSegura123!';

  Future<dynamic> searchByBarcode(String articleId) {
    return _client.post('/api/sql/search-by-barcode', {
      'articleId': articleId,
      'bodega': _sitsaBodega,
      'database': _sitsaDatabase,
      'password': _sitsaPassword,
      'server': _sitsaServer,
      'username': _sitsaUsername,
    });
  }

  Future<dynamic> getTicaData(String barcode) {
    return _client.post('/api/tica/get-tica-data', {'barcode': barcode});
  }

  Future<dynamic> searchByDescripcion(String description) {
    return _client.post('/api/sql/search-by-descripcion', {
      'server': _sitsaServer,
      'database': _sitsaDatabase,
      'username': _sitsaUsername,
      'password': _sitsaPassword,
      'bodega': _sitsaBodega,
      'description': description,
    });
  }

  Future<dynamic> getInventory({String? startingDate, String? endingDate}) {
    return _client.post('/api/sql/get-inventory', {
      'server': _sitsaServer,
      'database': _sitsaDatabase,
      'username': _sitsaUsername,
      'password': _sitsaPassword,
      'bodega': _sitsaBodega,
      if (startingDate != null) 'startingDate': startingDate,
      if (endingDate != null) 'endingDate': endingDate,
    });
  }

  Future<dynamic> getItemsByModelo(String modelo) {
    return _client.post('/api/sql/get-items-by-modelo', {
      'server': _sitsaServer,
      'database': _sitsaDatabase,
      'username': _sitsaUsername,
      'password': _sitsaPassword,
      'bodega': _sitsaBodega,
      'modelo': modelo,
    });
  }

  Future<dynamic> getItemCombined(String code) {
    return _client.post('/api/sql/get-item-combined', {
      'code': code,
      'sitsaServer': _sitsaServer,
      'sitsaDatabase': _sitsaDatabase,
      'sitsaUsername': _sitsaUsername,
      'sitsaPassword': _sitsaPassword,
      'mikailServer': _mikailServer,
      'mikailDatabase': _mikailDatabase,
      'mikailUsername': _mikailUsername,
      'mikailPassword': _mikailPassword,
    });
  }
}
