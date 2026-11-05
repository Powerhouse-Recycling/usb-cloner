#!/usr/bin/env bash
# Lint every shell script with shellcheck, in a container.
set -euo pipefail
cd "$(dirname "$0")"
docker run --rm -v "$PWD":/w:ro -w /w koalaman/shellcheck:stable -s bash bin/usb-cloner bin/usb-cloner-map install.sh lint.sh
