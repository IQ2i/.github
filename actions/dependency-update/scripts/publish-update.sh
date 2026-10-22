#!/usr/bin/env bash
# Commits the working tree on a dedicated branch, opens (or refreshes) its pull request and
# dispatches the CI on it, since a GITHUB_TOKEN push cannot trigger the `pull_request` event.
# Usage: publish-update.sh <branch> <base branch> <ci workflow> <commit message> <pull request title> <body file>
# Requires GH_TOKEN.
set -euo pipefail

branch="$1"
base="$2"
ci_workflow="$3"
message="$4"
title="$5"
body_file="$6"

git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'

git switch --force-create "$branch"
git add --all
git commit --message "$message"
git push --force origin "$branch"

if [ "$(gh pr view "$branch" --json state --jq '.state' 2>/dev/null || true)" = 'OPEN' ]; then
  gh pr edit "$branch" --title "$title" --body-file "$body_file"
else
  gh pr create --base "$base" --head "$branch" --title "$title" --body-file "$body_file"
fi

gh workflow run "$ci_workflow" --ref "$branch"
