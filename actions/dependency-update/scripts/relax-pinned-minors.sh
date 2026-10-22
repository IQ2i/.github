#!/usr/bin/env bash
# Moves the production packages pinned to patch releases (`~X.Y.Z`) to the newest minor available.
# A 0.x package counts too: Composer treats 0.Y -> 0.Z as a breaking change and leaves it out of
# `--minor-only`, yet it is the minor of a package that has no stable major.
# Usage: relax-pinned-minors.sh
set -euo pipefail

minors="$(mktemp)"
all="$(mktemp)"
outdated="$(mktemp)"
composer outdated --direct --minor-only --format=json --no-interaction > "$minors"
composer outdated --direct --format=json --no-interaction > "$all"
jq -s '
  def zero: ltrimstr("v") | startswith("0.");
  {installed: ((.[0].installed // []) + ((.[1].installed // []) | map(select((.version | zero) and (.latest | zero)))))
    | unique_by(.name)}
' "$minors" "$all" > "$outdated"

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
