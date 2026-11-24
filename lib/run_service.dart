/// Everything `bin/service.dart` does, so the code hash covers what runs:
/// that file only calls [runLogbookService] and exits with what it returns.
///
/// It reads its settings from the environment it is given:
///
///     LOGBOOK_DIR=/var/lib/intersyntactic-logbook \
///       LOGBOOK_SOCKET=/run/intersyntactic-logbook/logbook.sock \
///       LOGBOOK_SENDERS=/opt/intersyntactic-logbook/current/etc/senders \
///       LOGBOOK_READ_SOCKET=/run/intersyntactic-logbook-read/logbook.sock \
///       dart run is_logbook:service
///
/// `LOGBOOK_READ_SOCKET` is optional: without it, nothing can read through
/// the service.
library;

import 'dart:async';
import 'dart:io';

import 'is_logbook.dart';
import 'service.dart';

/// The exit code when the service cannot start as configured.
const cannotStart = 78;

/// Runs a logbook's one writer (see `package:is_logbook/service.dart`) as
/// [env] configures it, until [stop] completes, and returns the exit code:
/// 0 once it has closed, [cannotStart] when it could not start, having
/// written why to [err].
///
/// Once listening, it writes to [out] where it writes and listens, then
/// `code <hash> approved` or `code <hash> NOT approved`: whether its code
/// hash is a line of the logbook's `approved` file. That is a warning,
/// never a refusal: a missing line must not stop every writer.
///
/// Without [stop], it stops on SIGTERM or SIGINT, watched from the start,
/// so a stop sent once the start lines are out closes it cleanly.
Future<int> runLogbookService(
  Map<String, String> env, {
  IOSink? out,
  IOSink? err,
  Future<void>? stop,
}) async {
  out ??= stdout;
  err ??= stderr;
  final signals = <StreamSubscription<ProcessSignal>>[];
  if (stop == null) {
    final stopped = Completer<void>();
    for (final signal in [ProcessSignal.sigterm, ProcessSignal.sigint]) {
      signals.add(
        signal.watch().listen((_) {
          if (!stopped.isCompleted) stopped.complete();
        }),
      );
    }
    stop = stopped.future;
  }
  try {
    return await _run(env, out, err, stop);
  } finally {
    for (final s in signals) {
      await s.cancel();
    }
  }
}

Future<int> _run(
  Map<String, String> env,
  IOSink out,
  IOSink err,
  Future<void> stop,
) async {
  int fail(String why) {
    err.writeln('is_logbook service: $why');
    return cannotStart;
  }

  final dir = env['LOGBOOK_DIR'];
  final socket = env['LOGBOOK_SOCKET'];
  final senders = env['LOGBOOK_SENDERS'];
  if (dir == null) return fail('LOGBOOK_DIR is not set');
  if (socket == null) return fail('LOGBOOK_SOCKET is not set');
  if (senders == null) return fail('LOGBOOK_SENDERS is not set');
  final readSocket = env['LOGBOOK_READ_SOCKET'];
  final SenderTable table;
  try {
    table = SenderTable.parse(File(senders).readAsBytesSync());
  } on Exception catch (e) {
    return fail('$senders: $e');
  }
  final logbook = Logbook.open(Directory(dir));
  if (logbook == null) {
    return fail('the logbook cannot name its own code; see the README');
  }
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
    return fail('$e');
  }
  out.writeln(
    'writing $dir, listening on $socket'
    '${readSocket == null ? '' : ', readers on $readSocket'}',
  );
  final approved = logbook.approved().contains(logbook.codeHash);
  out.writeln(
    'code ${logbook.codeHash} ${approved ? 'approved' : 'NOT approved'}',
  );
  await stop;
  await service.close();
  return 0;
}
