#!/usr/bin/env bash
# Prints a Markdown table of the Composer packages whose locked version differs between two
# `composer show --locked --format=json` snapshots.
# Usage: versions-diff.sh <before.json> <after.json>
set -euo pipefail

jq -r -n --slurpfile before "$1" --slurpfile after "$2" '
  ($before[0].locked | map({key: .name, value: .version}) | from_entries) as $old
  | ($after[0].locked | map({key: .name, value: .version}) | from_entries) as $new
  | ([$old, $new] | map(keys) | add | unique) as $names
  | [$names[] | select($old[.] != $new[.]) | "| `\(.)` | \($old[.] // "—") | \($new[.] // "—") |"] as $rows
  | if ($rows | length) == 0 then empty else
      (["| Package | From | To |", "|---|---|---|"] + $rows)[]
    end
'
