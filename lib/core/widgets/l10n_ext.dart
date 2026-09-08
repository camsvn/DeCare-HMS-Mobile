import 'package:flutter/widgets.dart';
import 'package:hms_uploader/core/l10n/generated/app_localizations.dart';

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
