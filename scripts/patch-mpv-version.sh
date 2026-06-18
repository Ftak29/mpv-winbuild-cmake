#!/bin/bash
set -euo pipefail

: "${MPV_SOURCE_DIR:?}"
: "${TVEZ_LIB_VER:?}"

meson_file="$MPV_SOURCE_DIR/common/meson.build"

if [[ ! -f "$meson_file" ]]; then
    echo "ERROR: common/meson.build not found: $meson_file"
    exit 1
fi

python3 - "$meson_file" "$TVEZ_LIB_VER" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
suffix = sys.argv[2]

text = path.read_text()

# mpv uses git describe --dirty. Remove --dirty so local patching does not show "-dirty".
text = text.replace(', "--dirty"', '')
text = text.replace(", '--dirty'", '')

# Append suffix to the generated git version:
# v0.41.0 -> v0.41.0 TVEZLibW-1.3
wanted_fragment = f' {suffix}'
wanted_py_string = json.dumps(wanted_fragment)

if wanted_fragment not in text:
    old = 'sys.stdout.write(ver)'
    new = f'sys.stdout.write(ver.strip() + {wanted_py_string})'

    if old not in text:
        raise SystemExit(f"Could not find '{old}' in {path}")

    text = text.replace(old, new, 1)

# Also patch the fallback used when git is unavailable.
fallback_old = "fallback: 'v' + meson.project_version(),"
suffix_meson = suffix.replace("\\", "\\\\").replace("'", "\\'")
fallback_new = f"fallback: 'v' + meson.project_version() + ' {suffix_meson}',"

if fallback_new not in text and fallback_old in text:
    text = text.replace(fallback_old, fallback_new, 1)

path.write_text(text)
print(f"Patched {path}: version suffix '{suffix}', removed --dirty")
PY
