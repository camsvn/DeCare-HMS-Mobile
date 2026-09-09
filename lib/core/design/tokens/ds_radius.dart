import 'package:flutter/material.dart';

abstract final class DsRadius {
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
  static const double sheet = 24;
  static const double full = 999;

  static BorderRadius get smallAll => BorderRadius.circular(small);
  static BorderRadius get mediumAll => BorderRadius.circular(medium);
  static BorderRadius get largeAll => BorderRadius.circular(large);
}
