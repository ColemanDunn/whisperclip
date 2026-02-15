#!/usr/bin/env bash
set -euo pipefail

CONFIG="${1:-Debug}"
if [[ $# -gt 0 ]]; then
  shift
fi

./local_build.sh "$CONFIG"

open "build/WhisperClip.app" --args --overlay-dev "$@"
