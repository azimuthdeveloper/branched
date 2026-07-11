import 'package:get_it/get_it.dart';
import '../git_engine/git_service.dart';
import '../git_engine/git_service_impl.dart';
import '../git_engine/credentials_service.dart';

import 'file_picker_service.dart';

final locator = GetIt.instance;

void setupLocator() {
  locator.registerLazySingleton<CredentialsService>(() => CredentialsService());
  locator.registerLazySingleton<GitService>(() => RealGitService());
  locator.registerLazySingleton<FilePickerService>(() => RealFilePickerService());
}
