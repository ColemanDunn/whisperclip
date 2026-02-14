#!/usr/bin/env bash
set -euo pipefail

CONFIG=${1:-Release}
APP_NAME="WhisperClip"
BUILD_APP_PATH="build/$APP_NAME.app"
SYSTEM_APPS_PATH="/Applications/$APP_NAME.app"
USER_APPS_PATH="$HOME/Applications/$APP_NAME.app"

./local_build.sh "$CONFIG"

if [[ -w "/Applications" ]]; then
  RUN_PATH="$SYSTEM_APPS_PATH"
elif [[ -w "$HOME" ]]; then
  mkdir -p "$HOME/Applications"
  RUN_PATH="$USER_APPS_PATH"
else
  RUN_PATH="$BUILD_APP_PATH"
fi

if [[ "$RUN_PATH" != "$BUILD_APP_PATH" ]]; then
  rm -rf "$RUN_PATH"
  cp -R "$BUILD_APP_PATH" "$RUN_PATH"
fi

if [[ "$RUN_PATH" == "$BUILD_APP_PATH" ]]; then
  echo "⚠️  Could not write app bundle to /Applications or ~/Applications. Opening build artifact."
fi

open "$RUN_PATH"
