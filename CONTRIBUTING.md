# Contributing

## Working on this repository

Everything here is YAML consumed by GitHub Actions, so the feedback loop is the CI itself. Before pushing:

```bash
brew install actionlint shellcheck yq
actionlint
```

The `CI` workflow runs `actionlint`, validates every `action.yml` and shellchecks each composite `run:` block.
It is the same set of checks, so a green local `actionlint` is a good proxy.

## Conventions

- Reusable workflows live in `.github/workflows/`, composite actions in `actions/<name>/action.yml`.
  GitHub only resolves reusable workflows from `.github/workflows/`; that constraint is why the two live apart.
- Every input carries a `description` and, unless it is genuinely required, a `default`.
- Shell steps start with `set -euo pipefail`.
- Values that come from inputs go through `env:`, never straight into the script body. A `${{ }}` interpolated
  into a `run:` is a shell injection waiting to happen.
- A new input is not done until the README table documents it.

## Changing a workflow that repositories already call

Callers track `@main`, so a merged change reaches every repository on its next run. For anything that changes
behaviour rather than adding an optional input, migrate the calling repositories in the same pull request, or
land the change behind a new input with the old behaviour as the default.

## Commits

Conventional Commits: `feat:`, `fix:`, `ci:`, `docs:`, `refactor:`, `chore:`. Subject line only.
