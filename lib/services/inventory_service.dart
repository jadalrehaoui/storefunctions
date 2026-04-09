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

  Future<dynamic> searchByDescripcion(String description, {bool includeZero = false}) {
    return _client.post('/api/sitsa/search-text', {
      'text': description,
      'bodega': _sitsaBodega,
      'includeZero': includeZero,
    });
  }

  Future<dynamic> getInventory({
    String? startingDate,
    String? endingDate,
    String? clasificacion,
  }) {
    return _client.post('/api/sitsa/get-inventory', {
      'bodega': _sitsaBodega,
      if (startingDate != null) 'startingDate': startingDate,
      if (endingDate != null) 'endingDate': endingDate,
      if (clasificacion != null) 'clasificacion': clasificacion,
    });
  }

  Future<dynamic> getClasificaciones() {
    return _client.get('/api/sitsa/get-clasificaciones');
  }

  Future<dynamic> getItemsByModelo(String modelo, {bool includeZero = false}) {
    return _client.post('/api/sitsa/get-items-by-modelo', {
      'modelo': modelo,
      'bodega': _sitsaBodega,
      'includeZero': includeZero,
    });
  }

  Future<dynamic> getItemCombined(String code) {
    return _client.post('/api/combined/get-item', {'code': code});
  }

  Future<dynamic> getActiveCashiers(DateTime date) {
    final d =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return _client.get('/api/sitsa/active-cashiers?date=$d');
  }

  Future<dynamic> getDailyReportByCashier(DateTime date, String usuario) {
    final d =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return _client.post('/api/sitsa/get-daily-report-by-cashier', {
      'date': d,
      'usuario': usuario,
    });
  }

  Future<dynamic> getInvoicesByCashier(DateTime date, String usuario) {
    final d =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return _client.get(
        '/api/sitsa/invoices-by-cashier?date=$d&usuario=${Uri.encodeQueryComponent(usuario)}');
  }
}
