#!/usr/bin/env bash
# Requires the latest version of the importmap packages whose update has the given status.
# Usage: update-importmap.sh <semver-safe-update|update-possible>
#   semver-safe-update: same major version, safe to merge unattended
#   update-possible:    new major version, needs a human review
set -euo pipefail

status="$1"
outdated="$(mktemp)"

# importmap:outdated exits with 1 as soon as one package is outdated.
php bin/console importmap:outdated --format=json > "$outdated" || true

requirements=()
while read -r requirement; do
  requirements+=("$requirement")
done < <(jq -r --arg status "$status" '.[] | select(."latest-status" == $status) | "\(.name)@\(.latest)"' "$outdated")

if [ "${#requirements[@]}" -gt 0 ]; then
  php bin/console importmap:require "${requirements[@]}"
fi
