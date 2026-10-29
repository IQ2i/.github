#!/usr/bin/env bash
# Prints the locked packages of a composer.lock, one line each and sorted, with what identifies their
# code (version and source/dist references). Composer's own metadata (`published-time`, dates, content
# hash, plugin API version) is left out, so two locks that differ only by the Composer version that wrote
# them print the same thing.
# Usage: locked-packages.sh <composer.lock>
set -euo pipefail

jq -r '
  ((.packages // []) + (.["packages-dev"] // []))
  | map("\(.name) \(.version) \(.source.reference // "-") \(.dist.reference // "-")")
  | sort[]
' "$1"
