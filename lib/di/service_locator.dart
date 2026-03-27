import 'package:get_it/get_it.dart';

import '../services/api_client.dart';
import '../services/inventory_service.dart';

final sl = GetIt.instance;

Future<void> setupServiceLocator() async {
  sl.registerLazySingleton<ApiClient>(() => ApiClient());
  sl.registerLazySingleton<InventoryService>(() => InventoryService(sl()));
}
