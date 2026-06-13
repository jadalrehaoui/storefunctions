import 'package:dio/dio.dart';

import 'api_client.dart';

class InventoryService {
  final ApiClient _client;
  static const _sitsaBodega = 'B-01';

  InventoryService(this._client);

  Future<dynamic> searchByBarcode(String articleId) {
    return _client.post('/api/sitsa/get-item', {'code': articleId});
  }

  Future<dynamic> checkBarcodesFile({
    required String filePath,
    required String filename,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: filename),
    });
    return _client.postMultipart('/api/sitsa/check-barcodes', formData);
  }

  Future<dynamic> enrichCodesFile({
    required String filePath,
    required String filename,
    bool tica = true,
    int? concurrency,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: filename),
    });
    final qp = <String, String>{};
    if (!tica) qp['tica'] = 'false';
    if (concurrency != null) qp['concurrency'] = concurrency.toString();
    final query = qp.isEmpty
        ? ''
        : '?${qp.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
    return _client.postMultipart('/api/sitsa/enrich-codes$query', formData);
  }

  Future<dynamic> checkCabys({String? bodega}) {
    return _client.post('/api/sitsa/check-cabys', {
      'bodega': bodega ?? _sitsaBodega,
    });
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
    List<String>? clasificaciones,
    bool tica = false,
    int? concurrency,
  }) {
    return _client.post('/api/sitsa/get-inventory', {
      'bodega': _sitsaBodega,
      if (startingDate != null) 'startingDate': startingDate,
      if (endingDate != null) 'endingDate': endingDate,
      if (clasificaciones != null && clasificaciones.isNotEmpty)
        'clasificaciones': clasificaciones,
      if (tica) 'tica': true,
      if (tica && concurrency != null) 'concurrency': concurrency,
    });
  }

  Future<dynamic> getClasificaciones() {
    return _client.get('/api/sitsa/get-clasificaciones');
  }

  Future<dynamic> getProveedores() {
    return _client.get('/api/sitsa/get-proveedores');
  }

  Future<dynamic> getStagnantItems({
    int? days,
    int? clasificacion,
    int? limit,
  }) {
    return _client.post('/api/sitsa/get-stagnant-items', {
      if (days != null) 'days': days,
      if (clasificacion != null) 'clasificacion': clasificacion,
      if (limit != null) 'limit': limit,
    });
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
