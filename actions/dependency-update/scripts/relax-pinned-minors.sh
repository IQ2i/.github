#!/usr/bin/env bash
# Moves the production packages pinned to patch releases (`~X.Y.Z`) to the newest minor available.
# Usage: relax-pinned-minors.sh
set -euo pipefail

outdated="$(mktemp)"
composer outdated --direct --minor-only --format=json --no-interaction > "$outdated"

packages=()
while read -r name latest; do
  constraint="$(jq -r --arg name "$name" '.require[$name] // ""' composer.json)"
  if [[ "$constraint" == "~"* ]]; then
    composer require "$name:~${latest%.*}.0" --no-update --no-interaction
    packages+=("$name")
  fi
done < <(jq -r '.installed[] | "\(.name) \(.latest | ltrimstr("v"))"' "$outdated")

if [ "${#packages[@]}" -gt 0 ]; then
  composer update "${packages[@]}" --with-dependencies --no-interaction --no-progress
fi
