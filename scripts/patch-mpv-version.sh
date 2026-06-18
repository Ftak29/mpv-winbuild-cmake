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
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
suffix = sys.argv[2]

text = path.read_text()

# Do not let git describe add "-dirty".
text = text.replace(', "--dirty"', '')
text = text.replace(", '--dirty'", '')

old = 'sys.stdout.write(ver)'
new = f'ver = ver.strip()\nsys.stdout.write(ver + " {suffix}")'

if f'ver + " {suffix}"' in text:
    print(f"Already patched {path}")
    path.write_text(text)
    sys.exit(0)

if old not in text:
    raise SystemExit(f"Could not find '{old}' in {path}")

text = text.replace(old, new, 1)
path.write_text(text)

print(f"Patched {path}: append '{suffix}' and removed --dirty")
PY
