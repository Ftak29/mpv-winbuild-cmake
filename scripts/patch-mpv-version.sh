#!/bin/bash
set -euo pipefail

cd "$MPV_SOURCE_DIR"

base_ver="$(tr -d '\r\n' < MPV_VERSION)"
printf '%s\n' "${TVEZ_LIB_VER} ${base_ver}" > MPV_VERSION

echo "Patched MPV_VERSION=$(cat MPV_VERSION)"
