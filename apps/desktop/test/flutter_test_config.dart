// Runs around every test file: date and number formats need intl's locale
// data, which the app loads in main().

import 'dart:async';

import 'package:intl/date_symbol_data_local.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await initializeDateFormatting();
  await testMain();
}
