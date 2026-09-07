import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:knightmarket/config/app_theme.dart';

void main() {
  test('brand theme is black & gold', () {
    expect(AppTheme.bgDark, const Color(0xFF0A0A0B));
    expect(AppTheme.primary, const Color(0xFFD4AF37));
  });
}
