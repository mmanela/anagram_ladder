import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Xcode Cloud post-clone script', skip: Platform.isWindows, () {
    late Directory temporary;
    late Directory repository;
    late File log;
    late Map<String, String> environment;
    final script = File('ios/ci_scripts/ci_post_clone.sh').absolute.path;
    final macScript = File('macos/ci_scripts/ci_post_clone.sh').absolute.path;

    setUp(() async {
      temporary = await Directory.systemTemp.createTemp('xcode cloud test ');
      repository = await Directory('${temporary.path}/repository').create();
      final scripts = await Directory('${repository.path}/ios/ci_scripts')
          .create(recursive: true);
      await File(script).copy('${scripts.path}/ci_post_clone.sh');
      final bin = await Directory('${temporary.path}/bin').create();
      log = File('${temporary.path}/commands.log');
      final flutter = File('${temporary.path}/flutter');
      await flutter.writeAsString(r'''#!/bin/sh
set -eu
printf '%s|%s\n' "$PWD" "$*" >> "$TEST_LOG"
if [ "$*" = "${TEST_FAIL_COMMAND:-}" ]; then
  exit 42
fi
''');
      final git = File('${bin.path}/git');
      await git.writeAsString(r'''#!/bin/sh
set -eu
printf '%s|git %s\n' "$PWD" "$*" >> "$TEST_LOG"
if [ "${TEST_FAIL_COMMAND:-}" = git ]; then
  exit 42
fi
while [ "$#" -gt 1 ]; do shift; done
mkdir -p "$1/bin"
cp "$TEST_FLUTTER" "$1/bin/flutter"
''');
      for (final executable in [flutter, git]) {
        final result = await Process.run('chmod', ['+x', executable.path]);
        expect(result.exitCode, 0, reason: '${result.stderr}');
      }
      environment = {
        'PATH': '${bin.path}:${Platform.environment['PATH']}',
        'TMPDIR': temporary.path,
        'CI_PRIMARY_REPOSITORY_PATH': repository.path,
        'CI_BUILD_NUMBER': '123',
        'TEST_LOG': log.path,
        'TEST_FLUTTER': flutter.path,
      };
    });

    tearDown(() async {
      await temporary.delete(recursive: true);
    });

    Future<ProcessResult> runScript({bool macos = false}) => Process.run(
      '/bin/sh',
      [macos ? macScript : script],
      environment: environment,
      workingDirectory: temporary.path,
    );

    test('Mac wrapper prepares macOS without iOS codesigning flags', () async {
      final result = await runScript(macos: true);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      final commands = await log.readAsLines();
      expect(commands, hasLength(4));
      expect(commands.skip(1), [
        '${repository.path}|precache --macos',
        '${repository.path}|pub get --enforce-lockfile',
        '${repository.path}|build macos --release --config-only '
            '--no-pub --build-number=123',
      ]);
    });

    test('Mac configuration failure stops cloud preparation', () async {
      environment['TEST_FAIL_COMMAND'] =
          'build macos --release --config-only --no-pub --build-number=123';
      final result = await runScript(macos: true);
      expect(result.exitCode, 42);
      expect(
        (await log.readAsLines()).last,
        '${repository.path}|${environment['TEST_FAIL_COMMAND']}',
      );
    });

    test('unsupported platforms fail before downloading anything', () async {
      environment['ANAGRAM_LADDER_PLATFORM'] = 'windows';
      final result = await runScript();
      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('Unsupported Apple platform: windows'));
      expect(log.existsSync(), isFalse);
    });

    test(
      'prepares locked dependencies and release configuration in order',
      () async {
        final result = await runScript();
        expect(result.exitCode, 0, reason: '${result.stderr}');
        final commands = await log.readAsLines();
        expect(commands, hasLength(4));
        final clonePrefix =
            '${repository.path}|git clone --depth 1 --branch 3.47.7 '
            'https://github.com/flutter/flutter.git ';
        expect(commands.first, startsWith(clonePrefix));
        expect(commands.skip(1), [
          '${repository.path}|precache --ios',
          '${repository.path}|pub get --enforce-lockfile',
          '${repository.path}|build ios --release --config-only '
              '--no-codesign --no-pub --build-number=123',
        ]);
        final sdk = commands.first.substring(clonePrefix.length);
        expect(File('$sdk/bin/flutter').existsSync(), isTrue);
      },
    );

    for (final command in [
      'git',
      'precache --ios',
      'pub get --enforce-lockfile',
      'build ios --release --config-only --no-codesign --no-pub '
          '--build-number=123',
    ]) {
      test('stops immediately when $command fails', () async {
        environment['TEST_FAIL_COMMAND'] = command;
        final result = await runScript();
        expect(result.exitCode, 42);
        final commands = await log.readAsLines();
        if (command == 'git') {
          expect(commands, hasLength(1));
        } else {
          expect(commands.last, '${repository.path}|$command');
        }
      });
    }

    for (final variable in ['CI_PRIMARY_REPOSITORY_PATH', 'CI_BUILD_NUMBER']) {
      test('reports a missing $variable before downloading anything', () async {
        environment[variable] = '';
        final result = await runScript();
        expect(result.exitCode, isNot(0));
        expect(result.stderr, contains(variable));
        expect(log.existsSync(), isFalse);
      });
    }
  });
}
