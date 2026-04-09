import 'api_client.dart';

class InvoiceService {
  final ApiClient _client;

  InvoiceService(this._client);

  Future<dynamic> lookupItem(String code) {
    return _client.post('/api/sitsa/get-item-for-invoice', {'code': code});
  }

  Future<dynamic> authorizeDiscount({
    required String username,
    required String password,
    required double discount,
  }) {
    return _client.post('/api/workdb/invoices/authorize-discount', {
      'username': username,
      'password': password,
      'discount': discount,
    });
  }

  Future<dynamic> createInvoice(Map<String, dynamic> payload) {
    return _client.post('/api/workdb/invoices', payload);
  }

  Future<dynamic> updateInvoice(String id, Map<String, dynamic> payload) {
    return _client.put('/api/workdb/invoices/$id', payload);
  }

  Future<dynamic> listInvoices({
    DateTime? from,
    DateTime? to,
    String? clientName,
  }) {
    final qp = <String>[];
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    if (from != null) qp.add('start_date=${fmt(from)}');
    if (to != null) qp.add('end_date=${fmt(to)}');
    if (clientName != null && clientName.isNotEmpty) {
      qp.add('client=${Uri.encodeQueryComponent(clientName)}');
    }
    final query = qp.isEmpty ? '' : '?${qp.join('&')}';
    return _client.get('/api/workdb/invoices$query');
  }

  Future<dynamic> getInvoice(String id) {
    return _client.get('/api/workdb/invoices/$id');
  }

  Future<dynamic> voidInvoice(String id) {
    return _client.post('/api/workdb/invoices/$id/void', {});
  }

  Future<dynamic> dailySummary(DateTime date, {String? user}) {
    final d =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final qp = 'date=$d${user != null && user.isNotEmpty ? '&user=${Uri.encodeQueryComponent(user)}' : ''}';
    return _client.get('/api/workdb/invoices/daily-summary?$qp');
  }
}
