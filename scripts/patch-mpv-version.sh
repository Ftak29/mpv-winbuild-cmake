#!/bin/bash
set -euo pipefail

: "${MPV_SOURCE_DIR:?}"
: "${TVEZ_LIB_VER:?}"

mpv_version_file="$MPV_SOURCE_DIR/MPV_VERSION"

if [[ ! -f "$mpv_version_file" ]]; then
    echo "ERROR: MPV_VERSION not found: $mpv_version_file"
    exit 1
fi

base_ver="$(tr -d '\r\n' < "$mpv_version_file")"
base_ver="$(printf '%s\n' "$base_ver" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"

if [[ -z "$base_ver" ]]; then
    echo "ERROR: could not parse base mpv version from $mpv_version_file"
    cat "$mpv_version_file"
    exit 1
fi

wanted_no_v="${base_ver} ${TVEZ_LIB_VER}"

printf '%s\n' "$wanted_no_v" > "$mpv_version_file"
echo "Patched MPV_VERSION=$(cat "$mpv_version_file")"
