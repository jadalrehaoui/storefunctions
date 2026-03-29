import 'package:get_it/get_it.dart';

import '../features/auth/cubit/auth_cubit.dart';
import '../features/auth/service/auth_service.dart';
import '../services/api_client.dart';
import '../services/inventory_service.dart';
import '../shared/cubit/health_cubit.dart';

final sl = GetIt.instance;

Future<void> setupServiceLocator() async {
  sl.registerLazySingleton<ApiClient>(() => ApiClient());

  sl.registerLazySingleton<AuthService>(() => AuthService());
  sl.registerLazySingleton<AuthCubit>(() => AuthCubit(sl(), sl()));
  sl.registerLazySingleton<InventoryService>(() => InventoryService(sl()));
  sl.registerLazySingleton<HealthCubit>(() => HealthCubit(sl()));
}
