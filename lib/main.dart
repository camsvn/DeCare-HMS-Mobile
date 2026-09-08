import 'package:flutter/material.dart';
import 'package:hms_uploader/core/theme/app_theme.dart';

void main() {
  runApp(MaterialApp(theme: buildAppTheme(), home: const Scaffold(body: SizedBox.shrink())));
}
