/// Runs a logbook's one writer (see `package:is_logbook/service.dart`):
///
///     LOGBOOK_DIR=/var/lib/intersyntactic-logbook \
///       LOGBOOK_SOCKET=/run/intersyntactic-logbook/logbook.sock \
///       LOGBOOK_SENDERS=/opt/intersyntactic-logbook/current/etc/senders \
///       LOGBOOK_READ_SOCKET=/run/intersyntactic-logbook-read/logbook.sock \
///       dart run is_logbook:service
///
/// `LOGBOOK_READ_SOCKET` is optional: without it, nothing can read through
/// the service.
///
/// Once listening, it prints where it writes and listens, then
/// `code <hash> approved` or `code <hash> NOT approved`: whether its code
/// hash is a line of the logbook's `approved` file.
///
/// Exits 78 when it cannot start as configured, and closes cleanly on
/// SIGTERM or SIGINT.
library;

import 'dart:async';
import 'dart:io';

import 'package:is_logbook/is_logbook.dart';
import 'package:is_logbook/service.dart';

Future<void> main() async {
  final env = Platform.environment;
  final [dir, socket, senders] = [
    for (final name in ['LOGBOOK_DIR', 'LOGBOOK_SOCKET', 'LOGBOOK_SENDERS'])
      env[name] ?? _fail('$name is not set'),
  ];
  final readSocket = env['LOGBOOK_READ_SOCKET'];
  final SenderTable table;
  try {
    table = SenderTable.parse(File(senders).readAsBytesSync());
  } on Exception catch (e) {
    _fail('$senders: $e');
  }
  final logbook =
      Logbook.open(Directory(dir)) ??
      _fail('the logbook cannot name its own code; see the README');
  final LogbookService service;
  try {
    service = await LogbookService.start(
      logbook,
      table,
      File(socket),
      readSocket: readSocket == null ? null : File(readSocket),
    );
  } on Object catch (e) {
    logbook.close();
    _fail('$e');
  }
  // Watched before the start lines, so a stop sent once they are seen
  // closes the service cleanly instead of killing it.
  final stop = Completer<void>();
  for (final signal in [ProcessSignal.sigterm, ProcessSignal.sigint]) {
    signal.watch().listen((_) {
      if (!stop.isCompleted) stop.complete();
    });
  }
  stdout.writeln(
    'writing $dir, listening on $socket'
    '${readSocket == null ? '' : ', readers on $readSocket'}',
  );
  // A warning, never a refusal: a missing line must not stop every writer.
  final approved = logbook.approved().contains(logbook.codeHash);
  stdout.writeln(
    'code ${logbook.codeHash} ${approved ? 'approved' : 'NOT approved'}',
  );
  await stop.future;
  await service.close();
  exit(0);
}

Never _fail(String why) {
  stderr.writeln('is_logbook service: $why');
  exit(78);
}
