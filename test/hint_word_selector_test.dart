import 'package:anagram_ladder/anagram/anagramBuilder.dart';
import 'package:anagram_ladder/anagram/hintWordSelector.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class HintTestAssets extends CachingAssetBundle {
  final contents = <String, String>{
    for (final file in AnagramLadderBuilder.scowlEasyFileNames)
      AnagramLadderBuilder.getScowlFile(file): '',
    AnagramLadderBuilder.getScowlFile('english-words.10'): 'star\r\n',
    AnagramLadderBuilder.getScowlFile('english-words.20'): 'star\nrats\n',
    AnagramLadderBuilder.getScowlFile('english-words.35'): 'tars\n',
  };
  int loads = 0;
  bool fail = false;

  @override
  Future<ByteData> load(String key) async =>
      throw UnsupportedError('Use loadString');

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    loads++;
    if (fail) throw StateError('Dictionary unavailable');
    final value = contents[key];
    if (value == null) throw StateError('Missing test asset: $key');
    return value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'prefers the smallest vocabulary tier and keeps the input unchanged',
    () async {
      final selector = HintWordSelector(assets: HintTestAssets());
      final words = ['tars', 'rats', 'star'];
      expect(await selector.select(words), 'star');
      expect(words, ['tars', 'rats', 'star']);
      expect(await selector.select(['tars', 'rats']), 'rats');
    },
  );

  test('ties and unknown answers use stable input order', () async {
    final assets = HintTestAssets();
    assets.contents[AnagramLadderBuilder.getScowlFile('american-words.10')] =
        'rats\n';
    final selector = HintWordSelector(assets: assets);
    expect(await selector.select(['rats', 'star']), 'rats');
    expect(await selector.select(['star', 'rats']), 'star');
    expect(await selector.select(['mystery', 'unknown']), 'mystery');
  });

  test('prefers lusts over sluts without changing accepted answers', () async {
    final assets = HintTestAssets();
    final selector = HintWordSelector(assets: assets);
    final words = ['sluts', 'lusts'];
    expect(await selector.select(words), 'lusts');
    expect(await selector.select(words.reversed.toList()), 'lusts');
    expect(words, ['sluts', 'lusts']);
    expect(assets.loads, 0);
  });

  test('excludes sensitive answers before vocabulary ranking', () async {
    final assets = HintTestAssets();
    assets.contents[AnagramLadderBuilder.getScowlFile('english-words.10')] =
        'raped\nrape\nraping\nsluts\n';
    assets.contents[AnagramLadderBuilder.getScowlFile('english-words.35')] =
        'drape\npear\nparing\nlusts\n';
    final selector = HintWordSelector(assets: assets);
    for (final (blocked, alternative) in [
      ('raped', 'drape'),
      ('rape', 'pear'),
      ('raping', 'paring'),
      ('sluts', 'lusts'),
    ]) {
      expect(await selector.select([blocked, alternative]), alternative);
    }
    expect(await selector.select(['raped', 'tars', 'rats']), 'rats');
  });

  test('excluded-only answers fail explicitly without a fallback', () async {
    final selector = HintWordSelector(assets: HintTestAssets());
    for (final word in HintWordSelector.excludedHintWords) {
      await expectLater(selector.select([word]), throwsStateError);
    }
    await expectLater(
      selector.select(['rape', 'raped', 'raping']),
      throwsStateError,
    );
    expect(await selector.select(['lusts']), 'lusts');
  });

  test('caches dictionary data across hint requests', () async {
    final assets = HintTestAssets();
    final selector = HintWordSelector(assets: assets);
    await Future.wait([
      selector.select(['tars', 'star']),
      selector.select(['rats', 'star']),
    ]);
    expect(assets.loads, AnagramLadderBuilder.scowlEasyFileNames.length);
    await selector.select(['star', 'rats']);
    expect(assets.loads, AnagramLadderBuilder.scowlEasyFileNames.length);
  });

  test('dictionary failures propagate and can be retried', () async {
    final assets = HintTestAssets()..fail = true;
    final selector = HintWordSelector(assets: assets);
    await expectLater(selector.select(['rats', 'star']), throwsStateError);
    assets.fail = false;
    expect(await selector.select(['rats', 'star']), 'star');
  });

  test(
    'a sole answer needs no dictionary and empty input is rejected',
    () async {
      final assets = HintTestAssets();
      final selector = HintWordSelector(assets: assets);
      expect(await selector.select(['star']), 'star');
      expect(assets.loads, 0);
      await expectLater(selector.select([]), throwsArgumentError);
    },
  );

  test('bundled dictionary tiers prefer rates over stare and tars', () async {
    expect(
      await HintWordSelector().select(['tars', 'stare', 'rates']),
      'rates',
    );
  });
}
