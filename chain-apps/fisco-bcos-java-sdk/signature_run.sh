#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -n "${GRADLE_BIN:-}" ]]; then
    GRADLE_CMD=("$GRADLE_BIN")
elif [[ -x "$APP_DIR/gradlew" ]]; then
    GRADLE_CMD=("$APP_DIR/gradlew")
else
    GRADLE_CMD=(bash "$APP_DIR/gradlew")
fi

quote_arg() {
    local value="$1"
    printf "'%s'" "$(printf "%s" "$value" | sed "s/'/'\\\\''/g")"
}

ARGS=""
for arg in "$@"; do
    ARGS+=" $(quote_arg "$arg")"
done

exec "${GRADLE_CMD[@]}" --no-daemon -q -p "$APP_DIR" signature --args="${ARGS# }"
