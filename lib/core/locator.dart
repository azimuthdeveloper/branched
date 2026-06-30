import 'package:get_it/get_it.dart';
import '../git_engine/git_service.dart';
import '../git_engine/git_service_impl.dart';

final locator = GetIt.instance;

void setupLocator() {
  locator.registerLazySingleton<GitService>(() => MockGitService());
}
