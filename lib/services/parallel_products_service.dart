import 'api_client.dart';

/// Talks to the WorkDB `parallel_products` CRUD endpoints
/// (`/api/workdb/parallel-products`). Mirrors [ItemListsService].
class ParallelProductsService {
  final ApiClient _client;

  ParallelProductsService(this._client);

  Future<dynamic> getProducts() =>
      _client.get('/api/workdb/parallel-products');

  Future<dynamic> lookup(String code) => _client.get(
      '/api/workdb/parallel-products/lookup?code=${Uri.encodeQueryComponent(code)}');

  Future<dynamic> addProduct(Map<String, dynamic> payload) =>
      _client.post('/api/workdb/parallel-products', payload);

  Future<dynamic> updateProduct(int id, Map<String, dynamic> payload) =>
      _client.put('/api/workdb/parallel-products/$id', payload);

  Future<dynamic> deleteProduct(int id) =>
      _client.delete('/api/workdb/parallel-products/$id');
}
