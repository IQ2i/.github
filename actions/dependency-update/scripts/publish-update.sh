#!/usr/bin/env bash
# Commits the working tree on a dedicated branch and opens (or refreshes) its pull request. The CI runs
# on the pull_request event, provided GH_TOKEN is not the GITHUB_TOKEN.
# Usage: publish-update.sh <branch> <base branch> <commit message> <pull request title> <body file> [assignees]
# Requires GH_TOKEN.
set -euo pipefail

branch="$1"
base="$2"
message="$3"
title="$4"
body_file="$5"
assignees="${6:-}"

git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'

git switch --force-create "$branch"
git add --all
git commit --message "$message"

# Pushing an identical tree would restart the CI for nothing.
if git fetch --quiet origin "$branch" 2>/dev/null && git diff --quiet "origin/$branch" HEAD; then
  echo "The branch $branch is already up to date."
else
  git push --force origin "$branch"
fi

if [ "$(gh pr view "$branch" --json state --jq '.state' 2>/dev/null || true)" = 'OPEN' ]; then
  assignee_args=()
  if [ -n "$assignees" ]; then
    assignee_args=(--add-assignee "$assignees")
  fi
  gh pr edit "$branch" --title "$title" --body-file "$body_file" ${assignee_args[@]+"${assignee_args[@]}"}
else
  assignee_args=()
  if [ -n "$assignees" ]; then
    assignee_args=(--assignee "$assignees")
  fi
  gh pr create --base "$base" --head "$branch" --title "$title" --body-file "$body_file" ${assignee_args[@]+"${assignee_args[@]}"}
fi
