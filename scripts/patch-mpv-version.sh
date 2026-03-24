#!/bin/bash
set -euo pipefail

cd "$MPV_SOURCE_DIR"

base_ver="$(tr -d '\r\n' < MPV_VERSION)"
printf '%s\n' "${EZTV_LIB_VER}-${base_ver}" > MPV_VERSION

git config user.email "ci@local"
git config user.name "ci"
git add MPV_VERSION
git commit -m "Set custom MPV_VERSION" || true
