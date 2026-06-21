#!/bin/bash
# Seed a simulator's Strumbuddy install with a realistic demo history for App Store
# screenshots: ~12-day streak, mastered + learning skills, and a clear focus.
#
#   scripts/seed_demo.sh [<simulator-udid>|booted]
#
# The app must already be installed on the target simulator. Re-run anytime.
set -euo pipefail

BUNDLE=me.colinwatson.strumbuddy
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UDID="${1:-booted}"

# 1. Build + run the seed generator (writes observations.json, prints ORDINALS).
# swiftc requires the top-level-code file to be named main.swift in a multi-file build.
TMPD=$(mktemp -d)
cp "$ROOT/scripts/seed_observations.swift" "$TMPD/main.swift"
swiftc -O \
  "$ROOT/Strumbuddy/Models/Chord.swift" \
  "$ROOT/Strumbuddy/Models/Skill.swift" \
  "$ROOT/Strumbuddy/Models/ScoreAxes.swift" \
  "$ROOT/Strumbuddy/Models/Observation.swift" \
  "$TMPD/main.swift" -o "$TMPD/sb_seed"
ORD=$("$TMPD/sb_seed" /tmp/observations.json | sed 's/ORDINALS: //')

# 2. Resolve the target simulator.
if [ "$UDID" = "booted" ]; then
  UDID=$(xcrun simctl list devices booted -j | python3 -c \
    "import json,sys; d=json.load(sys.stdin)['devices']; print(next((x['udid'] for r in d.values() for x in r), ''))")
fi
[ -z "$UDID" ] && { echo "No booted simulator. Boot one (or pass a UDID)."; exit 1; }

# 3. Drop the observation log into the app's sandbox.
CONTAINER=$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data 2>/dev/null) \
  || { echo "Strumbuddy isn't installed on $UDID — build/run it there first."; exit 1; }
APPSUP="$CONTAINER/Library/Application Support"
mkdir -p "$APPSUP"
cp /tmp/observations.json "$APPSUP/observations.json"

# 4. Set the streak + onboarding defaults (typed via plutil → defaults import).
JSON_ARR=$(echo "$ORD" | tr ' ' ',')
plutil -create xml1 /tmp/sb_prefs.plist
plutil -replace onboardingComplete -bool true /tmp/sb_prefs.plist
plutil -replace completedSessionDays -json "[$JSON_ARR]" /tmp/sb_prefs.plist
xcrun simctl spawn "$UDID" defaults import "$BUNDLE" /tmp/sb_prefs.plist

# 5. Relaunch so the coach reprojects from the seeded log.
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl launch "$UDID" "$BUNDLE" >/dev/null

echo "✓ Seeded $UDID — $(echo "$ORD" | wc -w | tr -d ' ')-day streak, 180 observations."
