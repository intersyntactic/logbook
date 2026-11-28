import 'dart:io';

import 'package:is_logbook/service.dart';
import 'package:test/test.dart';

void main() {
  test(
    'bin/ownership_kinds prints every ownership kind, one per line',
    () async {
      final run = await Process.run(Platform.resolvedExecutable, [
        'run',
        'bin/ownership_kinds.dart',
      ]);
      expect(run.exitCode, 0, reason: '${run.stderr}');
      // cast-ok: Process.run decodes stdout to a String by default.
      final stdout = run.stdout as String;
      expect(stdout.trim().split('\n'), [
        'users-assigned-to-trajectory',
        'mission-ended',
        'trajectory-closed',
      ]);
    },
  );

  test('of reads back each ownership kind and no plain kind', () {
    for (final ownership in OwnershipKind.values) {
      expect(OwnershipKind.of(ownership.kind), ownership);
    }
    expect(OwnershipKind.of(Kind.parse('chat-message')!), isNull);
    expect(OwnershipKind.of(Kind.started), isNull);
  });

  // A kind the service reads past OwnershipKind would own chains without
  // bin/ownership_kinds printing it, and a deploy would not see it.
  test('lib/ names an ownership kind only inside OwnershipKind.kind', () {
    final named = RegExp(
      r'(?<!\[)\bKind\.(usersAssignedToTrajectory|missionEnded|trajectoryClosed)\b',
    );
    final uses = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var n = 0; n < lines.length; n++) {
        if (named.hasMatch(lines[n])) uses.add('${file.path}:${n + 1}');
      }
    }
    expect(uses, hasLength(OwnershipKind.values.length), reason: '$uses');
  });
}
