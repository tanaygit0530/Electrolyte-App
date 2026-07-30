import 'file_saver_stub.dart'
    if (dart.library.html) 'file_saver_web.dart'
    if (dart.library.io) 'file_saver_io.dart';

Future<bool> saveReportFile(List<int> bytes, String fileName) =>
    saveAndDownloadFile(bytes, fileName);
