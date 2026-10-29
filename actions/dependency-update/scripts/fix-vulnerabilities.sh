#!/usr/bin/env bash
# Updates, within their constraints, the locked packages that have a security advisory (dev ones and
# transitive ones included), then writes a Markdown summary of what was fixed and what is still vulnerable.
# The summary stays empty when there is no advisory at all.
# Usage: fix-vulnerabilities.sh <summary file>
set -euo pipefail

summary="$1"
before="$(mktemp)"
after="$(mktemp)"

# composer audit exits with a non-zero code as soon as it finds an advisory. An empty list is encoded as `[]`.
audit() {
  composer audit --locked --format=json --no-interaction > "$1" || true
}

advisories='def advisories: (.advisories // {}) | if type == "array" then [] else [.[][]] end;'

audit "$before"

packages=()
while read -r package; do
  packages+=("$package")
done < <(jq -r "$advisories"' advisories | map(.packageName) | unique[]' "$before")

: > "$summary"
if [ "${#packages[@]}" -eq 0 ]; then
  exit 0
fi

# When no version within the constraints fixes an advisory, the lock file stays as it is.
composer update "${packages[@]}" --with-dependencies --no-interaction --no-progress \
  || echo "::warning::Could not update the vulnerable packages: ${packages[*]}"

audit "$after"

# Titles come from a third-party database: keep them from breaking the table or mentioning anyone.
jq -r -n --slurpfile before "$before" --slurpfile after "$after" "$advisories"'
  def row: "| `\(.packageName)` | \(.cve // "—") | \(.title | gsub("[|@`]"; " ")) |";
  def table: (["| Package | CVE | Title |", "|---|---|---|"] + (unique_by(.advisoryId) | map(row)))[];

  ($after[0] | advisories) as $left
  | ($left | map(.advisoryId)) as $remaining
  | ($before[0] | advisories | map(select(.advisoryId as $id | $remaining | index($id) | not))) as $fixed
  | (if ($fixed | length) > 0 then ("### Security fixes", "", ($fixed | table), "") else empty end),
    (if ($left | length) > 0 then
      ("### Still vulnerable", "",
       "No version within the constraints fixes these advisories: they need a manual update.", "",
       ($left | table))
    else empty end)
' > "$summary"
