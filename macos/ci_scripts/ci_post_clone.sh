#!/bin/sh
set -eu

: "${CI_PRIMARY_REPOSITORY_PATH:?Xcode Cloud must provide the repository path}"
export ANAGRAM_LADDER_PLATFORM=macos
exec /bin/sh "$CI_PRIMARY_REPOSITORY_PATH/ios/ci_scripts/ci_post_clone.sh"
