import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:is_logbook/is_logbook.dart';
import 'package:test/test.dart';

/// Runs `bin/service.dart` on [dir] until it has printed its two start
/// lines, then stops it with SIGTERM and returns them.
Future<List<String>> startLines(Directory dir) async {
  final senders = File('${dir.path}.senders')..writeAsStringSync('');
  final service = await Process.start(
    Platform.resolvedExecutable,
    ['run', 'bin/service.dart'],
    environment: {
      'LOGBOOK_DIR': dir.path,
      'LOGBOOK_SOCKET': '${dir.path}.sock',
      'LOGBOOK_SENDERS': senders.path,
    },
  );
  final errors = service.stderr.transform(utf8.decoder).join();
  final lines = await service.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .take(2)
      .toList()
      .timeout(const Duration(seconds: 60));
  service.kill(ProcessSignal.sigterm);
  expect(await service.exitCode, 0, reason: await errors);
  return lines;
}

void main() {
  late Directory dir;
  late FileSetId hash;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('service_start_test');
    final logbook = Logbook.open(dir)!;
    hash = logbook.codeHash;
    logbook.close();
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('says its code is not approved when approved lacks its hash', () async {
    final lines = await startLines(dir);
    expect(lines.first, startsWith('writing ${dir.path}, listening on '));
    expect(lines.last, 'code $hash NOT approved');
  });

  test('says its code is approved when approved holds its hash', () async {
    File('${dir.path}/approved').writeAsStringSync('$hash  checked\n');
    final lines = await startLines(dir);
    expect(lines.last, 'code $hash approved');
  });
}
