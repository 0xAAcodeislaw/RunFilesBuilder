#!/usr/bin/env bash

set -euo pipefail

# The run-file installers in this repository use opkg and .ipk packages.
# Keep the default on the latest stable 24.10 patch release: ImmortalWrt
# 25.12 switched its package format to .apk/apk, which is not compatible
# with these installers yet.
IMMORTALWRT_SERIES="${IMMORTALWRT_SERIES:-24.10}"
IMMORTALWRT_MIRROR="${IMMORTALWRT_MIRROR:-https://downloads.immortalwrt.org}"

if [[ -z "${IMMORTALWRT_RELEASE:-}" ]]; then
  IMMORTALWRT_RELEASE="$({
    curl --fail --silent --show-error --location \
      "${IMMORTALWRT_MIRROR}/releases/"
  } | sed -nE 's#.*href="([0-9]+\.[0-9]+\.[0-9]+)/".*#\1#p' \
    | awk -v series="$IMMORTALWRT_SERIES" '$0 ~ "^" series "\\.[0-9]+$"' \
    | sort -V | tail -n 1)"
fi

if [[ -z "$IMMORTALWRT_RELEASE" ]]; then
  echo "Unable to resolve the latest ImmortalWrt ${IMMORTALWRT_SERIES}.x release" >&2
  exit 1
fi

IMMORTALWRT_PACKAGE_ROOT="${IMMORTALWRT_PACKAGE_ROOT:-${IMMORTALWRT_MIRROR}/releases/${IMMORTALWRT_RELEASE}/packages}"

export IMMORTALWRT_SERIES IMMORTALWRT_RELEASE IMMORTALWRT_PACKAGE_ROOT
echo "Using ImmortalWrt ${IMMORTALWRT_RELEASE}: ${IMMORTALWRT_PACKAGE_ROOT}"
