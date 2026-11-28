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
        'users-assigned-uids',
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
  test('lib/ names an ownership kind only inside OwnershipKind', () {
    final named = RegExp(
      r'(?<!\[)\bKind\.(usersAssignedToTrajectory|missionEnded|trajectoryClosed)\b'
      r"|'(users-assigned-to-trajectory|users-assigned-uids|mission-ended|trajectory-closed)'",
    );
    final outside = <String>[];
    var inside = 0;
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      var inEnum = false;
      final lines = file.readAsLinesSync();
      for (var n = 0; n < lines.length; n++) {
        if (lines[n].startsWith('enum OwnershipKind ')) inEnum = true;
        if (named.hasMatch(lines[n])) {
          inEnum ? inside++ : outside.add('${file.path}:${n + 1}');
        }
        if (inEnum && lines[n] == '}') inEnum = false;
      }
    }
    expect(outside, isEmpty);
    expect(inside, OwnershipKind.values.length);
  });
}
