#!/bin/bash
set -euo pipefail

: "${MPV_SOURCE_DIR:?}"
: "${TVEZ_LIB_VER:?}"

base_ver="$(tr -d '\r\n' < "$MPV_SOURCE_DIR/MPV_VERSION")"
base_ver="$(printf '%s\n' "$base_ver" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"

wanted_no_v="${base_ver} ${TVEZ_LIB_VER}"
wanted="v${wanted_no_v}"

# Post-Meson mode: patch generated version.h.
# This is the mode you want for the git mpv build.
if [[ -n "${MPV_BUILD_DIR:-}" ]]; then
    header="${MPV_BUILD_DIR}/common/version.h"

    if [[ ! -f "$header" ]]; then
        echo "ERROR: version.h not found: $header"
        find "$MPV_BUILD_DIR" -name version.h -print || true
        exit 1
    fi

    python3 - "$header" "$wanted" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
wanted = sys.argv[2]
escaped = wanted.replace("\\", "\\\\").replace('"', '\\"')

text = path.read_text()
new = re.sub(
    r'#define VERSION\s+"[^"]*"',
    f'#define VERSION "{escaped}"',
    text,
    count=1,
)

if new == text:
    raise SystemExit(f"VERSION define not found in {path}")

path.write_text(new)
print(f'Patched {path}: VERSION="{wanted}"')
PY

    exit 0
fi

# Pre-configure fallback mode.
# Useful only for mpv-release tarball builds without .git.
printf '%s\n' "$wanted_no_v" > "$MPV_SOURCE_DIR/MPV_VERSION"
echo "Patched MPV_VERSION=$(cat "$MPV_SOURCE_DIR/MPV_VERSION")"
