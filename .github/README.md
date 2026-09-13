# IQ2i/.github

Shared GitHub Actions workflows for the IQ2i, loicsapone and Mezcalito repositories.

Before this repository existed, the same job — `checkout` → `setup-php` → `composer install` → one command —
was copy-pasted roughly forty times across twelve repositories. The copies had drifted: `actions/checkout@v4`,
`@v6` and `@v7` all in use, three ways of installing dependencies, and a `${{ matrix.php_version }}` typo that
silently reduced two 5-version test matrices to a single version. Everything below exists to have one copy.

This repository is public, so these workflows can be called from any repository, including private ones.

## Quick start

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  security:
    uses: IQ2i/.github/.github/workflows/php-security.yml@main

  cs:
    uses: IQ2i/.github/.github/workflows/php-cs.yml@main

  sa:
    uses: IQ2i/.github/.github/workflows/php-stan.yml@main

  tests:
    uses: IQ2i/.github/.github/workflows/php-tests.yml@main
    with:
      php-versions: '["8.3", "8.4", "8.5"]'
```

The `permissions` and `concurrency` blocks belong in the caller, not here — a reusable workflow cannot grant
itself less than it is given, and concurrency is scoped to the calling workflow. Set both on every CI.

## Reusable workflows

All of them accept `php-extensions`, `dependency-versions` (`highest` \| `lowest` \| `locked`),
`composer-options`, `working-directory` and `runs-on`. Only what is specific to each is listed below.

### `php-cs.yml` — coding standard

| Input | Default | |
|---|---|---|
| `php-version` | `8.4` | |
| `args` | `fix --dry-run --diff --no-ansi` | Passed to php-cs-fixer |
| `ignore-env` | `false` | Sets `PHP_CS_FIXER_IGNORE_ENV`, for a PHP version the config does not support yet |

### `php-stan.yml` — static analysis

| Input | Default | |
|---|---|---|
| `php-version` | `8.4` | |
| `args` | `analyse --no-progress` | Passed to phpstan |
| `memory-limit` | `-1` | |

### `php-security.yml` — composer validate and audit

| Input | Default | |
|---|---|---|
| `php-version` | `8.4` | |
| `composer-validate` | `true` | Runs `composer validate --strict` |
| `no-check-lock` | `false` | For packages that do not commit a lock file |
| `audit-args` | — | Passed to `composer audit` |

### `php-tests.yml` — PHPUnit

| Input | Default | |
|---|---|---|
| `php-versions` | `["8.4"]` | JSON array; one job per version |
| `args` | — | Passed to phpunit |
| `coverage` | `none` | `none`, `pcov` or `xdebug` |
| `coverage-floor` | `0` | Minimum line coverage percentage; `0` disables. Requires a coverage driver |
| `fail-fast` | `false` | |

```yaml
  tests:
    uses: IQ2i/.github/.github/workflows/php-tests.yml@main
    with:
      php-versions: '["8.3", "8.4", "8.5"]'
      coverage: pcov
      coverage-floor: 95
```

There is no "fail below X%" option in PHPUnit, so the floor is enforced by reading the clover totals.
Raise it only to a number the suite already reaches.

### `bundle-ci.yml` — PHP × Symfony matrix

For bundles and libraries that must prove they work across several Symfony versions. Handles the
symfony/flex setup that pins `extra.symfony.require`.

| Input | Default | |
|---|---|---|
| `matrix` | `[{"php": "8.4"}]` | JSON array of combinations |
| `args` | — | Passed to phpunit |
| `fail-fast` | `false` | |

Each matrix entry accepts `php` (required), `symfony`, `stability`, `dependency-versions`, `pin-packages`
and `name` (the label shown in the checks list; defaults to `PHP x, Symfony y`).

```yaml
  tests:
    uses: IQ2i/.github/.github/workflows/bundle-ci.yml@main
    with:
      matrix: |
        [
          {"php": "8.4", "symfony": "8.0"},
          {"php": "8.4", "symfony": "7.4"},
          {"php": "8.3", "symfony": "6.4", "dependency-versions": "lowest"},
          {"php": "8.5", "symfony": "8.0.x-dev", "stability": "dev", "name": "PHP 8.5, Symfony dev"}
        ]
```

### `lint-actions.yml` — actionlint and shellcheck

For repositories that publish a composite action. Validates the action metadata, runs `actionlint`, and
shellchecks every `run:` block of every composite action.

| Input | Default | |
|---|---|---|
| `actionlint-version` | `1.7.7` | |
| `action-paths` | `action.yml action.yaml actions/*/action.yml .github/actions/*/action.yml` | Space-separated globs |
| `shellcheck` | `true` | |

## Composite action

### `actions/setup-php`

Sets PHP up, restores the Composer cache and installs dependencies. The reusable workflows above all go
through it; call it directly when you need a job they do not cover.

```yaml
      - uses: IQ2i/.github/actions/setup-php@main
        with:
          php-version: '8.4'
          dependency-versions: lowest
```

Inputs: `php-version`, `extensions`, `ini-values`, `coverage`, `tools`, `dependency-versions`,
`composer-options`, `working-directory`, `cache-suffix`, `install-php`.

`dependency-versions` replaces `ramsey/composer-install`: `highest` runs `composer update`, `lowest` adds
`--prefer-lowest --prefer-stable`, and `locked` runs `composer install` (falling back to `update` when there
is no lock file, which is the normal case for a bundle).

Set `install-php: 'false'` when the job already set PHP up and needs to edit `composer.json` before
installing — that is what `bundle-ci.yml` does for symfony/flex.

## What the other repositories inherit, and what they do not

GitHub calls these *default community health files*. An IQ2i repository that has no file of a given type
falls back to the one here, whatever its visibility — nothing to copy, nothing to keep in sync:

| File | Inherited |
|---|---|
| `CODE_OF_CONDUCT.md` | yes |
| `CONTRIBUTING.md` | yes |
| `SECURITY.md` | yes |
| `.github/ISSUE_TEMPLATE/` (templates and `config.yml`) | yes |
| `.github/PULL_REQUEST_TEMPLATE.md` | yes |
| `.github/dependabot.yml` | **no** — copy it into each repository |
| `.github/workflows/` | **no** — this is what `uses:` is for |
| `LICENSE` | **no** — must live in the repository so it survives a clone or a package download |
| `.github/README.md` | **no** — it is this repository's own readme |

Two limits worth knowing:

- Inheritance is per **owner**. `loicsapone/*` and `Mezcalito/*` get nothing from here; they can call the
  reusable workflows, but their health files have to live in their own `.github` repository.
- This repository must stay **public** for any of it to work, including for private IQ2i repositories.

The org profile page is driven by `profile/README.md`, not by this readme.

### dependabot.yml to copy

```yaml
version: 2

updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: monthly
    commit-message:
      prefix: ci
```

## Versioning

Callers currently track `@main`. Once the workflows have settled across a few repositories, a moving `v1`
tag will be introduced and `@main` will stop being the recommended target.

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md).
