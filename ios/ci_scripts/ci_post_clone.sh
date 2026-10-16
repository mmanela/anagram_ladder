#!/bin/sh
set -eu

: "${CI_PRIMARY_REPOSITORY_PATH:?Xcode Cloud must provide the repository path}"
: "${CI_BUILD_NUMBER:?Xcode Cloud must provide the build number}"

cd "$CI_PRIMARY_REPOSITORY_PATH"

# Keep the SDK available for Xcode's later Flutter build phases.
flutter_sdk="$(mktemp -d "${TMPDIR:-/tmp}/anagram-ladder-flutter.XXXXXX")"
git clone --depth 1 --branch 3.47.7 https://github.com/flutter/flutter.git "$flutter_sdk"
export PATH="$flutter_sdk/bin:$PATH"

flutter precache --ios
flutter pub get --enforce-lockfile
flutter build ios --release --config-only --no-codesign --no-pub \
  --build-number="$CI_BUILD_NUMBER"
