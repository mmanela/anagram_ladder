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

## Level access

Each difficulty includes 50 free ladders. The one-time purchase unlocks 200 more,
levels 51 through 250, for 1,250 playable ladders across all five difficulties.
The bundled sets already contain 250 unique ladders per difficulty, so the
expanded unlock uses the existing puzzle sets. Every ladder has at least three
rungs. Normal levels 145 through 250 have been repaired to meet that minimum;
all other puzzles and their ordering are unchanged.
Completed short ladders retain their completion. In-progress short ladders restart
with the repaired three-rung puzzle; other saved progress is unchanged.

Keep the existing product ID, `anagramladder.levels_51to100.difficulty_all`,
despite its legacy name so existing purchases and restored purchases unlock
all 250 levels without another payment. The app and local StoreKit configuration
show the expanded range. Update the existing product's customer-facing name
and description in App Store Connect to advertise levels 51 through 250.
In-app purchase copy derives its range and count from the gameplay limits rather
than the store's potentially outdated product description. Keep paid-level counts
in editable text, not baked into logos, screenshots, or other promotional images.

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

Selection uses a deterministic shuffled schedule of all 1,250 existing ladders,
250 from each difficulty. All appear once before the schedule repeats.
Daily play can select paid ladders even without a purchase, without unlocking
them in regular difficulty selection. The shuffle uses
explicit integer arithmetic so the schedule matches across native and web builds.
Date selection uses calendar-day arithmetic rather than elapsed hours,
so daylight-saving changes do not shift the schedule. There is no backend,
account, new puzzle generator, timer, or streak penalty. Purchase access does not
change the selection.

Daily arrangements and completion dates use separate `daily_v3_` preferences.
Already-started dailies retain their original puzzle, progress, and completion
in `daily_v1_` or `daily_v2_` preferences rather than changing puzzle mid-game.
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
Local and GitHub Actions builds use ad-hoc signing, not App Store distribution
credentials. GitHub Actions sets `XCODE_XCCONFIG_FILE` to
`.github/ci/macos-ci.xcconfig` for both the release build and native tests,
overriding developer signing settings without changing App Store configuration.
The window starts at 900 by 760 logical pixels, remembers its frame,
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
across difficulties, the 50-to-250-level unlock, trie entries, and restored
purchases. Route tests cover deep-link round-trips, Settings, malformed links,
and unavailable levels. Store tests cover pending purchases, cancellation,
transaction and stream errors, product-query errors, and unavailable stores.
They also cover concurrent connection retries, failed purchase starts,
explicit restoration, completion failures, disposal during loading, and free
gameplay while the store is still loading. Puzzle-data tests check that all
250 ladders in each difficulty are distinct and solvable, with valid dictionary
words and consistent letter additions between rungs.
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

Ladder generation prioritizes longer paths before word variety and requires
at least three rungs and 250 puzzles per difficulty. Length is maximized within
the generation vocabulary rules: Normal and Hard start at four letters or longer;
new Daunting, Expert, and Genius puzzles start at five letters or longer.
Published puzzles with shorter starting words are retained.
The generator caches deterministic path scores, including the minimum word length,
then selects a path using per-request seeded randomness. Repeated letters do not
weight equivalent branches, and tied catalog scores use a stable letter-set order.
Regression tests independently check the longest possible path for all 1,250
bundled seeds, dictionary-order independence, call-order independence, and
repeatability across builder instances.

Normal 98 is a targeted exception: its corrupted final word was replaced with
`script`, retaining the `rips` and `crisp`/`scrip` rungs. Existing regular and daily
saves retain lower-rung progress and completion; the corrupted tile becomes `t`.
Puzzle-data tests reject non-ASCII letters and malformed answers in every puzzle.
### Published catalog compatibility

`tools/langs/en/catalog.lock.json` records SHA-256 fingerprints of all 1,250
published puzzles after the Normal 98 repair. It locks order, letters, rungs,
letter additions, accepted answers, and metadata independently of generation.
**Levels 1-50 in every difficulty are immutable.** Do not regenerate the lock to
make a failing check pass.

Other published puzzles also remain unchanged by default because regular saves
and dated daily puzzles reference their existing positions. A targeted repair
above level 50 requires a reviewed entry in `catalog-exceptions.json`, containing
`world`, `level`, exact `before` and `after` fingerprints from the candidate report,
and nonempty `reason` and `migration` notes. An approval cannot authorize changes
to levels 1-50, duplicate an existing exception, or match a different candidate.
Implement and test the actual regular/daily save migration before approving a
layout change; the notes do not perform a migration.

### Vocabulary sources and processing

The imported [SCOWL](https://wordlist.aspell.net/) lists supply familiar words and
seed candidates at tiers 10/20/35, with tiers 40-70 expanding accepted answers.
[Desi Quintans' public-domain noun list](https://www.desiquintans.com/nounlist),
`extra_words.txt`, and `blacklist.txt` supplement them.
`sources.lock.json` records source URLs, roles, licenses, normalization, and
checksums of every local input. The original SCOWL release was not recorded, so
the manifest pins the actual imported bytes rather than inventing a version.
Its component license notices are retained in `raw/Scowl/Copyright`.

Processing uses strict UTF-8 decoding, trims and lowercases entries, and excludes
replacement characters, punctuation, non-ASCII letters, and lengths outside 4-10.
Every excluded or normalized input is recorded in `report.json`, along with
source checksums, duplicates, vocabulary differences, and published-answer
conflicts. Seeds are unique sorted letter multisets from familiar SCOWL words,
not disjoint subsets. This replaces the old prefix-based filter, which did not
enforce its claimed subset exclusion. No accented spelling is guessed from a
corrupted replacement character.

The cleaned legacy vocabulary preserves every published answer. Hint selection
continues using the original bundled SCOWL 10/20/35 tier files, so the cleanup
does not change existing hint ranks.

### Safe tooling workflow

Run from the repository root. Every generation command requires a **new output
directory** and never writes published files. Candidate dictionaries use
canonical sorted ordering; publication retains the order of surviving dictionary
entries to avoid unnecessary diffs. Unknown commands, malformed options, invalid
inputs, source checksum mismatches, and write failures exit nonzero.

For a vocabulary-only cleanup, which retains every published ladder:

```sh
dart run tools/main.dart verify_sources
dart run tools/main.dart process_raw --output .dart_tool/ladder_candidates/local-1
dart run tools/main.dart validate --candidate .dart_tool/ladder_candidates/local-1
# Review report.json and evaluation-summary.json before explicitly publishing.
dart run tools/main.dart publish --candidate .dart_tool/ladder_candidates/local-1
```

To experiment with regeneration or prepare only short-ladder repairs:

```sh
dart run tools/main.dart build_ladders --vocabulary .dart_tool/ladder_candidates/local-1 --output .dart_tool/ladder_candidates/generated-1
dart run tools/main.dart repair_ladders --vocabulary .dart_tool/ladder_candidates/local-1 --output .dart_tool/ladder_candidates/repair-1
```

Review each candidate's `report.json` for changed puzzle positions, before/after
layouts and answers, rung counts, fingerprints, and compatibility violations.
A full regenerated catalog is an experiment, not a publishable replacement:
publication refuses any changed protected level and any unapproved paid change.
Repairing a short protected level is also refused.

Publication validates all dictionaries and puzzles before staging a replacement
directory on the same filesystem. It preserves auxiliary processed files and
restores the previous directory if installation fails. Run publication offline,
not concurrently with another publisher or asset build. If the process is
terminated between directory renames, `processed.publish-backup` retains the
old directory and blocks further publication. Inspect both directories, restore
the backup if installation did not complete, then validate before retrying.
Do not delete a recovery copy without confirming which catalog is installed.

```sh
dart run tools/main.dart validate
flutter test test/ladder_data_test.dart test/ladder_builder_test.dart test/ladder_pipeline_test.dart
```

### Pinned ESDB evaluation

SCOWL has evolved into the English Speller Database (ESDB), whose minimum tier
is now 35 and whose schema and CLI are still evolving. The manifest pins revision
`1e5b7d3a72f47a71da5d28686c1dd4b397178485`, the source archive checksum, and exact
export commands and output checksums. The noun list is retained.
`tools/langs/en/esdb-evaluation.json` records the measured comparison.

The evaluated American English tier-35/tier-70 exports conflict with 143 existing
puzzles, including 36 protected puzzles, and omit 55 distinct accepted answers.
**The ESDB refresh is not adopted.** It is unsuitable as a drop-in replacement for
published puzzles or the existing 10/20/35 hint ranking. Using it for future content
needs a separate content/versioning decision; existing definitions remain frozen.

To reproduce the evaluation, download and verify the archive from the manifest,
extract it under `.dart_tool/ladder_sources`, run `make` in the extracted root,
then run the manifest's export commands there:

```sh
./scowl word-list 35 A 1 --deaccent --wo-poses=abbr --categories= > ../required-unsorted.txt
./scowl word-list 70 A 1 --deaccent --wo-poses=abbr --categories= > ../allowed-unsorted.txt
LC_ALL=C sort -u ../required-unsorted.txt > ../esdb-required.txt
LC_ALL=C sort -u ../allowed-unsorted.txt > ../esdb-allowed.txt
```

Back in this repository root:

```sh
dart run tools/main.dart evaluate_esdb --required .dart_tool/ladder_sources/esdb-required.txt --allowed .dart_tool/ladder_sources/esdb-allowed.txt --output .dart_tool/ladder_candidates/esdb-1
```

The evaluation checks the export hashes, stages its own dictionaries and reports
every published vocabulary conflict without altering the app.

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

Regenerate the PNGs with Node.js 20.9.0 or later:

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
