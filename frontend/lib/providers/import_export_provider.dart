import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/services/import_export_service.dart';

final importExportServiceProvider = Provider<ImportExportService>((ref) {
  return ImportExportService();
});
