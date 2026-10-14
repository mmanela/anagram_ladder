# Anagram Ladder - A mobile word game built with Flutter

[Anagram Ladder](https://matthewmanela.com/anagram-ladder/) is a challenging word game on Android and iPhone for those who love to unscramble long words. The game tasks you to solve a word ladder by unscrambling progressively longer words.
The game offers a range of difficulties with the most difficult levels requiring unscrambling 10-letter words (very hard!).

This is the full source code to the iOS and Android game. Originally written in
2021, the project now uses current Flutter and Dart tooling. Phase one modernizes
dependencies and platform compatibility while keeping the existing game design,
levels, and saved-progress format.

## Development

Use **Flutter 3.47.7 stable** with its bundled **Dart 3.13.5**. CI pins this Flutter
version, and `pubspec.lock` pins the resolved package versions.

```sh
flutter doctor
flutter pub get --enforce-lockfile
flutter run
```

Android requires Android SDK 36, a compatible JDK (21 recommended), and Android
7.0 / API 24 or later on the device. The project uses Android Gradle Plugin 9.1,
Gradle 9.3.1, built-in Kotlin, and Java 17 bytecode. Keep `android.newDsl=false`
until Flutter supports the new Android Gradle DSL.

iOS requires macOS, a compatible Xcode installation, and iOS 15 or later. Plugins
use Swift Package Manager, so `pod install` is no longer needed. Flutter generates
the Swift package integration during a build. Leave Flutter's Swift Package
Manager support enabled.

The existing application IDs and Android release signing configuration are
unchanged. Android release builds still require your private `android/key.properties`
and keystore. iOS device and App Store builds require your Apple signing setup.
Neither is needed for the debug APK or iOS simulator build below.

## Checks and builds

```sh
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator
flutter build web
```

GitHub Actions runs analysis, regression tests, and Android, iOS simulator, and web
builds. Widget tests check that completion appears after the final-rung animation,
restart dismisses the popup immediately, reset progress survives reopening, and
Next Level opens a playable board. They also cover full-ladder play, automatic
cascades (including edits during the cascade delay), replay after restart, hint
reveals and dismissal, long hint lists, and saved progress when leaving during an
animation. Small-phone, landscape, and large-text tests verify that gameplay and
dialog controls remain usable without layout overflows.

Model tests cover saved progress, completion counts, reset, next-level selection
across difficulties, the 50-to-100-level unlock, trie entries, and restored
purchases. Route tests cover deep-link round-trips, Settings, malformed links,
and unavailable levels. Store tests cover pending purchases, cancellation,
transaction and stream errors, product-query errors, and unavailable stores.
All use isolated in-memory preferences and test purchase providers,
so they do not alter your simulator's progress or contact the store.

Run just the game-state and UI regressions during gameplay changes:

```sh
flutter test test/game_state_test.dart test/widget_test.dart test/level_page_test.dart
```

Actual App Store purchases still need device or StoreKit testing. Android
purchases remain disabled, matching the existing game behavior.

For future dependency updates, run `flutter pub outdated`, then
`flutter pub upgrade --major-versions` and repeat the checks above. Commit
`pubspec.yaml` and `pubspec.lock` together. SDK-pinned transitive dependencies
should not be forced forward using dependency overrides.

## Source
- The main game is stored in the lib folder
- The tools for pre-processing word files is stored in the tools folder

## Try it out

[<img src="https://matthewmanela.com/wp-content/uploads/2021/06/download-on-the-app-store-1.png" alt="ios" style="width:200px;"/>](https://apps.apple.com/us/app/anagram-ladder/id1566804631)

[<img src="https://matthewmanela.com/wp-content/uploads/2021/06/google-play-badge-1-1-300x89.png" alt="ios" style="width:200px;"/>](https://play.google.com/store/apps/details?id=com.farblondzshet.anagramladder) 

## Screenshots

<img src="https://is5-ssl.mzstatic.com/image/thumb/PurpleSource115/v4/e7/08/46/e7084625-d2b2-610a-f318-6ec3b07ceb08/0ec68b51-b9de-4427-a927-d51cfad47678_MainScreen.png/1242x2688bb.png" alt="home" style="width:250px;"/>

<img src="https://is3-ssl.mzstatic.com/image/thumb/PurpleSource125/v4/d8/11/e9/d811e901-250a-3c19-1728-df40b98b38da/0f009bde-1baa-4ae8-97ff-ea55bf1680f1_NormalLadder.png/1242x2688bb.png" alt="game" style="width:250px;"/> 
