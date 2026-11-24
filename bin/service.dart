/// Runs a logbook's one writer: see `package:is_logbook/run_service.dart`,
/// which holds all of it, so the code hash covers what runs.
library;

import 'dart:io';

import 'package:is_logbook/run_service.dart';

Future<void> main() async =>
    exit(await runLogbookService(Platform.environment));
