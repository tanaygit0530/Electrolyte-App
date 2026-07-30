import 'dart:io';
import 'package:file_picker/file_picker.dart';

Future<bool> saveAndDownloadFile(List<int> bytes, String fileName) async {
  String? outputFile = await FilePicker.platform.saveFile(
    dialogTitle: 'Save Revenue Report',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: ['xlsx'],
  );
  
  if (outputFile != null) {
    final file = File(outputFile);
    await file.writeAsBytes(bytes);
    return true;
  }
  return false;
}
