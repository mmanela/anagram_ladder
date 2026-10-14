# Anagram Ladder - A mobile word game built with Flutter

[Anagram Ladder](https://matthewmanela.com/anagram-ladder/) is a challenging word game on Android and iPhone for those who love to unscramble long words. The game tasks you to solve a word ladder by unscrambling progressively longer words.
The game offers a range of difficulties with the most difficult levels requiring unscrambling 10-letter words (very hard!).

This is the full source code to the iOS and Android game. Originally written in
2021, the project now uses current Flutter and Dart tooling. Phase one modernizes
dependencies and platform compatibility. The core-experience polish adds a
clearer visual hierarchy and smoother controls while keeping the existing
puzzles, free hints, level access, and v5 saved-progress format.

## Core experience

- A warm neutral and purple theme with consistent cards, buttons, and typography.
- A compact home with Play for new players and Continue for saved ladders.
  After a completion, Continue offers the next unfinished ladder. Older saves
  without last-played metadata are supported.
- Difficulty cards show word length and completion counts. Ladder selection
  distinguishes new, in-progress, and completed games.
- A scrolling board highlights the active rung, shows overall progress, and
  brings the active row into view. Solved and upcoming rows have distinct,
  higher-contrast styles.
- Active tiles use the current word length and available board width, with
  tighter tile gaps, at least 8 logical pixels of clearance from the active
  card's outer border, and at least 64 logical pixels of touch height. The whole word
  stays visible without horizontal scrolling, including ten-letter words on
  narrow phones. Auto-scrolling prioritizes the letters, even when large text
  makes the active card taller than the screen.
- Drag letters horizontally, or tap a letter and then its destination. Vertical
  swipes scroll the board instead of starting a drag. Screen readers expose
  letter positions and Move left / Move right actions.
- Instructions disappear after the first successful move and stay hidden on
  later visits. How to play remains available in the app bar; selecting a letter
  still shows its contextual destination prompt. Resetting progress preserves
  this learned-controls preference.
- Solves confirm for 320 ms, then the existing letters move up and resize into
  the next rung while new letters drop onto the end with a small bounce.
  The transition lasts 420 ms; multiple added letters are slightly staggered.
  Rearranging, Shuffle, and Hint pause during the transition. Progress saves
  before the motion finishes, and automatic cascades wait until after landing,
  followed by a 180 ms pause. The final rung goes straight to completion.
  The system reduced-motion setting disables these delays, animated scrolling,
  and confetti.
- Hints appear only when requested, in a compact popup for one possible answer.
  Its first and last letters are shown immediately, with the middle hidden.
  Selection prefers the existing SCOWL dictionary's smaller vocabulary tiers
  (10, then 20, then 35), with stable ties and a stable fallback for unlisted
  answers. These are familiarity tiers, not exact word-frequency scores.
  Hints and completion controls scroll and support large text. Letter glyphs
  retain a scaling cap so ten-letter words still fit narrow phones.
- Settings includes optional haptic feedback, email feedback, a confirmed
  progress reset, and version information. Resetting progress preserves the
  haptic preference.
- Free gameplay no longer waits for the store. The store shows connection and
  purchase failures, supports retry and explicit Restore Purchases, and
  prevents duplicate purchase requests.

## Daily ladder

The home screen has a separate daily ladder with a simple completed-today status.
Daily selection varies across Normal, Hard, Daunting, Expert, and Genius.
The home card shows the difficulty and maximum word length before play.
Tapping it opens the puzzle directly, resuming saved progress or showing the
completed result. Back returns directly home, with no intermediate daily screen.
The completion card and shared result also identify the difficulty.
Everyone gets the same scheduled puzzle for a given calendar date. The date changes
at local midnight, including while the app stays open, and refreshes after
returning from the background. A ladder already in progress stays on its
original date, so crossing midnight does not replace its letters or give credit
to the wrong day.

Selection uses a deterministic shuffled schedule of 250 existing ladders: the
first 50 from each difficulty. All 250 appear once before the schedule repeats,
with no generation or changes to purchased-level access. The shuffle uses
explicit integer arithmetic so the schedule matches across native and web builds.
Date selection uses calendar-day arithmetic rather than elapsed hours,
so daylight-saving changes do not shift the schedule. There is no backend,
account, new puzzle generator, timer, or streak penalty. Purchase access does not
change the selection.

Daily arrangements and completion dates use separate `daily_v2_` preferences.
Already-started Normal dailies retain their original puzzle, progress, and
completion in `daily_v1_` preferences rather than changing difficulty mid-game.
They never change regular ladder progress, difficulty completion, or Continue.
Replay preserves the completed date. Reset progress clears both regular progress
and daily results, but preserves haptics and the learned-controls preference.
Malformed or future daily links cannot open new challenges; previously started
daily ladders can be resumed by their dated route.

Completion offers native Share and Copy result. Results contain the date and
green rung shapes, not answers or letter arrangements. Sharing uses `share_plus`,
anchors its sheet to the button on iPad, and reports failures with Copy available
as an alternative. Daily completion is local to this installation.

Purchase access remains based on the existing store transaction flow. This
phase does not add a persistent offline entitlement cache or change pricing,
the number of free levels, or Android's disabled purchase support.

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
selection, reveals and dismissal, and saved progress when leaving during an
animation. Small-phone, landscape, and large-text tests verify that gameplay and
dialog controls remain usable without layout overflows. Additional regressions
cover Continue, real horizontal dragging, vertical scrolling over tiles,
tap-to-move, screen-reader move actions, haptic preferences, reduced motion,
ten-letter boards on narrow phones, Settings reset confirmation, and large-text
home, selector, and store layouts.
Daily regressions cover all five difficulties, a fixed schedule fixture,
visibility of difficulty before play and in results, legacy Normal saves,
direct daily entry and return home, deterministic selection, midnight and resume rollover,
isolated saves, completion credit after replay, reset, malformed saves and routes,
spoiler-free sharing, copy and failure feedback, and small-screen/large-text
daily and completion layouts. Active-tile regressions verify that letter text is
rendered and visible, not only stored in game state. Transition tests cover
movement and shrinking, duplicate and multiple added letters, input blocking,
mid-flight navigation, rotation, automatic cascades, and reduced motion.
Instruction tests cover learning and Help on later visits.

Model tests cover saved progress, completion counts, reset, next-level selection
across difficulties, the 50-to-100-level unlock, trie entries, and restored
purchases. Route tests cover deep-link round-trips, Settings, malformed links,
and unavailable levels. Store tests cover pending purchases, cancellation,
transaction and stream errors, product-query errors, and unavailable stores.
They also cover concurrent connection retries, failed purchase starts,
explicit restoration, completion failures, disposal during loading, and free
gameplay while the store is still loading.
All use isolated in-memory preferences and test purchase providers,
so they do not alter your simulator's progress or contact the store.

Run just the game-state and UI regressions during gameplay changes:

```sh
flutter test test/game_state_test.dart test/widget_test.dart test/level_page_test.dart
flutter test test/polish_test.dart test/game_store_test.dart test/pay_page_test.dart
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
