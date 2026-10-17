# Anagram Ladder - A word game built with Flutter

[Anagram Ladder](https://matthewmanela.com/anagram-ladder/) is a challenging word game with Android, iPhone, and Mac targets for those who love to unscramble long words. The game tasks you to solve a word ladder by unscrambling progressively longer words.
The game offers a range of difficulties with the most difficult levels requiring unscrambling 10-letter words (very hard!).

This is the full source code to the iOS, Android, and macOS game. Originally written in
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
- Keyboard users can Tab to a letter and press Left or Right to move it.
  Focus follows the moved letter. Enter or Space selects a letter, then the
  same key on another tile moves it there; Escape clears the selection.
  These controls respect the same solve and transition locks as touch input.
- Instructions disappear after the first successful move and stay hidden on
  later visits. How to play remains available in the app bar; selecting a letter
  still shows its contextual destination prompt. Resetting progress preserves
  this learned-controls preference.
- Solves confirm for 380 ms, then the existing letters move up and resize into
  the next rung while new letters drop onto the end with a small bounce.
  The transition lasts 560 ms; multiple added letters are slightly staggered.
  Rearranging, Shuffle, and Hint pause during the transition. Progress saves
  before the motion finishes, and automatic cascades wait until after landing,
  followed by a 240 ms pause. The final solved word stays visible for 600 ms
  before showing completion, without a climb or letter drop.
  The system reduced-motion setting disables these delays, animated scrolling,
  and confetti.
- Hints appear only when requested, in a compact popup for one possible answer.
  Its first and last letters are shown immediately, with the middle hidden.
  Selection prefers the existing SCOWL dictionary's smaller vocabulary tiers
  (10, then 20, then 35), with stable ties and a stable fallback for unlisted
  answers. These are familiarity tiers, not exact word-frequency scores.
  Hints and completion controls scroll and support large text. Letter glyphs
  retain a scaling cap so ten-letter words still fit narrow phones.
- Level completion dims and blocks the board behind a rounded summary card,
  shows difficulty progress, and gives Next Level the primary action.
  Restart and Level Screen remain available, with trophy styling for newly
  completed difficulties and the full game.
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

### Opening iOS in Xcode

Before opening a fresh checkout or worktree in Xcode, run these commands from
that checkout's repository root:

```sh
flutter pub get --enforce-lockfile
flutter build ios --simulator --config-only --no-pub
open ios/Runner.xcworkspace
```

The configuration step generates `ios/Flutter/Generated.xcconfig` and the local
Swift package integration. These machine-specific files are intentionally not
committed. Open `Runner.xcworkspace` from the same checkout, not just the `ios`
folder or a project from a different checkout.

If Xcode reports a missing `Generated.xcconfig`, repeat the preparation commands.
Errors mentioning `Pods-Runner` file lists or an iOS 9 deployment target indicate
an older project configuration: the current project uses Swift Package Manager
and targets iOS 15. Close the older project and reopen this checkout's workspace.

The existing application IDs and Android release signing configuration are
unchanged. Android release builds still require your private `android/key.properties`
and keystore. iOS device and App Store builds require your Apple signing setup.
Neither is needed for the debug APK or iOS simulator build below.

### macOS

The native Flutter Mac app requires macOS 12 or later and a compatible Xcode
installation. It uses Swift Package Manager, the existing puzzle assets, and
the same `com.farblondzshet.anagramladder` bundle identifier as iOS. Its sandbox
allows outgoing connections for StoreKit; debug/profile builds additionally
allow the Flutter debugging connection. No broad file access is required.

```sh
flutter pub get --enforce-lockfile
flutter run -d macos
flutter build macos --release --no-pub
```

The release app is `build/macos/Build/Products/Release/Anagram Ladder.app`.
Local release builds use the development team and certificate configured in
Xcode. GitHub Actions supplies `macos/Runner/Configs/CI.xcconfig` through
`XCODE_XCCONFIG_FILE` to use ad-hoc signing for its build and native tests without
Apple credentials. This CI-only override does not change Xcode or Xcode Cloud
archive signing. The window starts at 900 by 760 logical pixels, remembers its frame,
and can resize down to 480 by 480. Mouse dragging, trackpad scrolling, click-to-move,
and keyboard controls use the shared gameplay implementation. The native
Anagram Ladder > Settings menu and Command-comma open the in-app Settings page.
Standard About, Hide, Quit, and window menus remain native.

Before opening a fresh checkout in Xcode:

```sh
flutter pub get --enforce-lockfile
flutter build macos --release --config-only --no-pub
open macos/Runner.xcworkspace
```

**Mac App Store setup:** add macOS to the existing app record in App Store
Connect, retaining the shared bundle ID for universal purchase. In Xcode,
select your Apple development team and configure Mac App Store signing for
Runner. The target already enables App Sandbox and In-App Purchase. Keep the
existing non-consumable product ID
`anagramladder.levels_51to100.difficulty_all`, and ensure that product is
available to the macOS platform on the same app record. Do not create an
unrelated Mac app/product if existing iOS purchasers should retain access.

For local StoreKit testing, select the existing
`ios/Runner/Configuration.storekit` in the Mac Runner scheme's Run > Options >
StoreKit Configuration. Exercise purchase, cancellation, and Restore Purchases.
Then test with Apple's sandbox/TestFlight, including restoring a purchase made
on iOS. Local StoreKit transactions do not establish cross-platform ownership.
Archive Runner with a Mac destination and use Xcode Organizer to validate and
upload. App Store Connect metadata, Mac screenshots, signing/provisioning, and
Apple review remain account-side setup, not automated by this repository.

Purchases use the existing StoreKit flow and do not block free gameplay.
Progress and daily results remain local to each installation; adding a Mac
target does not sync them with an iPhone or iPad.

### Xcode Cloud

Use `ios/Runner.xcworkspace` and the shared `Runner` scheme in the Xcode Cloud
workflow. Xcode Cloud automatically runs `ios/ci_scripts/ci_post_clone.sh` after
checking out the repository, before resolving Swift packages. The script installs
Flutter 3.47.7, downloads the iOS artifacts, restores locked dependencies, and
generates the release configuration and `FlutterGeneratedPluginSwiftPackage`.
Keep its Flutter version aligned with the GitHub Actions workflow.

The SDK stays available for Xcode's Flutter build phases. Xcode Cloud handles
archiving and signing; the preparation step does not build or sign the app.
It uses `CI_BUILD_NUMBER` for the app's build number. When distributing builds,
ensure the workflow's next build number exceeds any previously uploaded build
for the same app version.

A missing `Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage` error
means package resolution ran without Flutter preparation. Run a new cloud build
from a branch containing the post-clone script. Do not commit the generated
package, `Generated.xcconfig`, or a local Flutter SDK to fix this error.

For Mac, create a separate Xcode Cloud workflow using
`macos/Runner.xcworkspace`, the shared `Runner` scheme, and a macOS archive
destination. Its `macos/ci_scripts/ci_post_clone.sh` selects macOS preparation
through the shared iOS-hosted setup script. It downloads Mac artifacts and
generates the Mac release configuration and Swift package integration, retaining
the cloud build number. Xcode Cloud handles signing and archiving as on iOS.

## Checks and builds

```sh
flutter analyze
flutter test --coverage
flutter build apk --debug
flutter build ios --simulator
flutter build macos --release
flutter build web
```

GitHub Actions runs on pull requests, pushes to `main`, and manual runs from the
Actions tab. The `checks` job validates workflow syntax with actionlint, runs
analysis, and runs regression tests with coverage. Coverage totals appear in the
job summary, with the full `lcov.info` available as the `dart-coverage` artifact.
Coverage is reported without imposing an arbitrary minimum percentage.

Android/web, iOS, and macOS builds run in parallel after checks pass. Existing
`android-and-web` and `ios` check names are retained; they fail rather than
silently passing as skipped when prerequisite checks fail. Superseded runs are
cancelled, jobs have time limits, and all jobs use read-only repository
permissions. Locked dependencies and the pinned Flutter version are used in
every job. Flutter, Pub, and Gradle downloads are cached between runs.

Successful builds upload `android-debug-apk`, `web-build`, `ios-simulator-app`,
and `macos-app` artifacts, retained for seven days. Download them from the workflow run's
Artifacts section. The simulator app is a tar archive to preserve executable
permissions and symlinks; extract it before installing on a simulator compatible
with the build's architecture. It is not an iPhone or App Store distribution.
Web artifacts must be served over HTTP. These workflows do not publish releases,
deploy a website, or require signing credentials.
The Mac artifact also uses a tar archive to preserve permissions and symlinks.
It is an ad-hoc-signed build for development, not a Mac App Store submission or
a notarized direct-download release. Gatekeeper may block downloaded CI builds.

Dependabot opens weekly Monday pull requests for Dart packages and GitHub
Actions. Dart minor/patch updates are grouped; major updates stay
separate. Updates still require review and CI. Flutter SDK and native build-tool
upgrades remain manual so they can be coordinated together.

Widget tests check that completion appears after the final-rung animation,
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
Mac regressions cover keyboard focus and movement, selection/cancellation,
modifier keys, input locks, mouse dragging, resizing, native Settings routing,
and the existing purchase/restore flow on macOS. Xcode Cloud script tests cover
both Apple targets and preparation failures. The Mac Runner scheme also includes
native tests for app metadata, the minimum window size, and Settings menu wiring.
The macOS CI job runs these native tests against the release app before
uploading its artifact.

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

## App icon

The launcher icon is a warm-white ladder on a purple gradient, with no letters.
`assets/app_icon.svg` is the source for the iOS and macOS catalogs, Android legacy
launcher sizes, web icons and favicon, and the Google Play listing icon.
iOS artwork is full-bleed with platform-applied corners. Mac icons use an
inset rounded square on a transparent canvas because macOS does not apply
the iOS icon mask.
In-game logos and the Google Play feature graphic are separate and unchanged.
Startup uses the same artwork in a compact rounded badge on the warm neutral
background, with the game title, "Rearrange. Solve. Climb." tagline, and an
accessible loading indicator. Reduced motion keeps the indicator static, and
startup has no artificial delay. The layout scrolls on short screens and with
large text. Native iOS and Android launch screens use matching artwork and
backgrounds, including the Android 12 system splash screen.

Regenerate the PNGs with Node.js 20 or later:

```sh
npm ci --prefix tools/icons
npm run generate --prefix tools/icons
```

The generator checks dimensions and opacity, including the 1024px App Store
icon, and verifies the Mac icon sizes, transparent corners, and opaque centers.
It also generates `assets/app_icon.png` for Flutter and the rounded native
launch badges, whose transparent corners are checked separately.
Android 8 and later use the matching adaptive vector layers in
`android/app/src/main/res/drawable/ic_launcher_*.xml`; Android 13 and later also
have a monochrome layer for themed icons. Keep these vectors in sync when
editing the SVG. Adaptive foreground artwork is scaled into the safe zone so
launcher masks do not clip the ladder.

## Try it out

[<img src="https://matthewmanela.com/wp-content/uploads/2021/06/download-on-the-app-store-1.png" alt="ios" style="width:200px;"/>](https://apps.apple.com/us/app/anagram-ladder/id1566804631)

[<img src="https://matthewmanela.com/wp-content/uploads/2021/06/google-play-badge-1-1-300x89.png" alt="ios" style="width:200px;"/>](https://play.google.com/store/apps/details?id=com.farblondzshet.anagramladder) 

## Screenshots

<img src="https://is5-ssl.mzstatic.com/image/thumb/PurpleSource115/v4/e7/08/46/e7084625-d2b2-610a-f318-6ec3b07ceb08/0ec68b51-b9de-4427-a927-d51cfad47678_MainScreen.png/1242x2688bb.png" alt="home" style="width:250px;"/>

<img src="https://is3-ssl.mzstatic.com/image/thumb/PurpleSource125/v4/d8/11/e9/d811e901-250a-3c19-1728-df40b98b38da/0f009bde-1baa-4ae8-97ff-ea55bf1680f1_NormalLadder.png/1242x2688bb.png" alt="game" style="width:250px;"/> 
