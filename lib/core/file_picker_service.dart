import 'package:file_picker/file_picker.dart';

abstract class FilePickerService {
  Future<String?> getDirectoryPath({String? dialogTitle});
}

class RealFilePickerService implements FilePickerService {
  @override
  Future<String?> getDirectoryPath({String? dialogTitle}) {
    return FilePicker.platform.getDirectoryPath(dialogTitle: dialogTitle);
  }
}
