import 'package:hms_uploader/core/modules/app_module.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';

/// Registered workflow modules, in dashboard order. Add new modules here.
///
/// Note: the Tomogram module's entry screen is the patient lookup, which lives
/// in `features/patient_lookup`; `features/tomogram` owns only the detail and
/// permission screens nested under it.
final List<AppModule> appModules = [tomogramModule];
