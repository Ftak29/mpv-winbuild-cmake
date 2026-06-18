#!/bin/bash
set -euo pipefail

cd "$MPV_SOURCE_DIR"

base_ver="$(tr -d '\r\n' < MPV_VERSION)"

# Avoid duplicating your custom prefix if the patch step runs again.
if [[ "$base_ver" == "${TVEZ_LIB_VER} "* ]]; then
    new_ver="$base_ver"
else
    new_ver="${TVEZ_LIB_VER} ${base_ver}"
fi

printf '%s\n' "$new_ver" > MPV_VERSION

echo "Patched MPV_VERSION=$(cat MPV_VERSION)"

# Only commit when the mpv source is a git checkout.
# This keeps packages/mpv-release.cmake working, because that one uses a tarball.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git config user.name "local-build"
    git config user.email "local-build@example.invalid"

    git add MPV_VERSION

    if ! git diff --cached --quiet; then
        git commit -m "Set custom mpv version"
        echo "Committed custom MPV_VERSION: $(git rev-parse --short=12 HEAD)"
    else
        echo "No MPV_VERSION change to commit"
    fi
fi
