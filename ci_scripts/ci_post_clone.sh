#!/bin/sh
# Xcode Cloud post-clone hook.
#
# Strumbuddy's Strumbuddy.xcodeproj is generated from project.yml via XcodeGen
# (see CLAUDE.md). Regenerate it here so Xcode Cloud always builds the current
# project rather than a possibly-stale committed copy. Runs on the Xcode Cloud
# build machine after the repo is cloned; Homebrew is available there.
set -e

brew install xcodegen

cd "$CI_PRIMARY_REPOSITORY_PATH"
xcodegen generate

echo "ci_post_clone: regenerated Strumbuddy.xcodeproj"
