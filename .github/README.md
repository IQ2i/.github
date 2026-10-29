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
`composer-options`, `working-directory` and `runs-on`. The QA workflows (`php-cs`, `php-stan`, `php-security`,
`php-tests`) and `symfony-app` also accept `ref`, the Git ref to check out: it defaults to the ref that triggered
the workflow, and lets a caller test another branch. Only what is specific to each is listed below.

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
| `before-script` | — | Shell script run after the install and before PHPUnit, e.g. `bin/console tailwind:build` |
| `mariadb-version` | — | Starts a MariaDB service (e.g. `11.4`) and exports `DATABASE_URL` (user `root`, database `app`) before the `before-script`. The test database is up to the caller, e.g. `doctrine:database:create --env=test` in `before-script` |
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

### `symfony-app.yml` — Symfony application checks

For applications rather than libraries: it checks what a dependency update can break without failing a
unit test. Each step is skipped when the tool or the file it needs is missing.

| Input | Default | |
|---|---|---|
| `php-version` | `8.4` | |
| `dependency-versions` | `locked` | An application tests what it deploys, not the highest versions |
| `before-script` | — | Shell script run after the install, e.g. `bin/console tailwind:build` |

It runs `lint:container`, `lint:twig`, `lint:yaml`, `twig-cs-fixer`, `tailwind-cs-fixer` (the job fails when
it would rewrite a template) and, when there is an `importmap.php`, `asset-map:compile` and `importmap:audit`.

```yaml
  app:
    uses: IQ2i/.github/.github/workflows/symfony-app.yml@main
    with:
      php-version: '8.5'
      before-script: bin/console tailwind:build
```

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
shellchecks every `run:` block of every composite action and the scripts shipped next to them.

| Input | Default | |
|---|---|---|
| `actionlint-version` | `1.7.7` | |
| `action-paths` | `action.yml action.yaml actions/*/action.yml .github/actions/*/action.yml` | Space-separated globs |
| `script-paths` | `actions/*/scripts/*.sh .github/actions/*/scripts/*.sh` | Space-separated globs |
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

## Dependency updates

For Composer **applications** (a `composer.lock` is required; bundles and libraries are not covered). Two
workflows open a pull request from a dedicated branch, and the CI runs on it like on any pull request:

| Mode | Branch | Updates | Merge |
|---|---|---|---|
| `nightly` | `chore/nightly-dependencies` | The production dependencies (`require`) within their constraints, the importmap packages that stay on the same major version, and any package with a security advisory, dev ones included | Automatic, once the CI has passed |
| `review` | `chore/dependencies-review` | Everything else: dev dependencies, the new minor versions of the packages pinned to patch releases (`~X.Y.Z`) and the new importmap major versions | Never, a human reviews it |

Pin the packages whose minor versions deserve a look (an API client, anything whose output is rendered as
HTML) with `~X.Y.Z`: the nightly run only brings their patches, the weekly review proposes the new minors.
A `~0.Y.Z` package is handled the same way, since Composer does not count 0.Y to 0.Z as a minor update.
New major versions of the Composer packages are left to Dependabot.

Dev dependencies are kept out of the automatic merge on purpose: a new php-cs-fixer ruleset turns the CI red
and needs a human, and they never reach production when the deployment runs `composer install --no-dev`. The
exception is a dev dependency with a security advisory: it is patched within its constraints as soon as the
nightly run sees it. The pull request lists the advisories it fixes and those no version within the
constraints can fix (those need a manual update, or Dependabot).

A dev-only advisory must not hold back the production updates, so the nightly pull request audits the
production dependencies only (`audit-args: --no-dev` in the CI below). `main` and the review pull request keep
the full audit and stay red until a human fixes it.

### Why a GitHub App

A push made with the `GITHUB_TOKEN` triggers no workflow, and the `pull_request` runs of a pull request it opens
wait for a manual approval. The update therefore pushes the branch and opens the pull request with the token of
a GitHub App, which makes the CI start on its own. The pull request is also assigned to someone: a bot's pull
request notifies nobody else, and neither does its failed CI.

### Setting a repository up

Create a GitHub App once, for every repository (*Settings → Developer settings → GitHub Apps*):

- no webhook;
- repository permissions: *Contents* and *Pull requests* read and write (*Metadata* read-only is implied);
- installable by any account if it has to serve several owners, then installed on each of them, on the
  repositories concerned.

Generate a private key, and store the App's client ID and the private key as the secrets
`DEPENDENCY_APP_CLIENT_ID` and `DEPENDENCY_APP_PRIVATE_KEY`: at the organization level for IQ2i, and in each
repository for a personal account. Then add three files.

`.github/workflows/update-dependencies.yml`

```yaml
name: Update dependencies

on:
  schedule:
    - cron: '23 */2 * * *'
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: update-dependencies

jobs:
  update:
    uses: IQ2i/.github/.github/workflows/dependency-update.yml@main
    with:
      mode: nightly
      php-version: '8.5'
      php-extensions: gd, intl
      assignees: your-login
    secrets:
      app-client-id: ${{ secrets.DEPENDENCY_APP_CLIENT_ID }}
      app-private-key: ${{ secrets.DEPENDENCY_APP_PRIVATE_KEY }}
```

`.github/workflows/dependencies-review.yml` is the same file with `mode: review`, another `group`, and a
weekly `cron` (for example `'41 5 * * 1'`). Pick a minute off the top of the hour: GitHub delays the scheduled
runs it receives at peak times.

In `.github/workflows/ci.yml`, make the `security` job skip the dev dependencies on the nightly branch, and add
two last jobs. The permissions must be granted by the caller: without them the whole workflow is rejected, even
on pull requests.

```yaml
  security:
    uses: IQ2i/.github/.github/workflows/php-security.yml@main
    with:
      audit-args: ${{ github.head_ref == 'chore/nightly-dependencies' && '--no-dev' || '' }}

  automerge:
    needs: [security, cs, sa, tests]
    permissions:
      contents: write
      pull-requests: write
    uses: IQ2i/.github/.github/workflows/automerge.yml@main

  automerge-report:
    if: failure()
    needs: [security, cs, sa, tests]
    permissions:
      contents: write
      pull-requests: write
    uses: IQ2i/.github/.github/workflows/automerge.yml@main
    with:
      report-failure: true
```

`automerge` merges the pull request when every job has passed. It refuses to run on anything but a
`pull_request` coming from the update branch of the same repository, and merges with `--match-head-commit`, so
only the commit the CI has just tested can land. `automerge-report` runs when a job has failed and comments the
pull request with the link of the run, which notifies its assignees.

`dependency-update.yml` takes `mode`, `php-version`, `php-extensions`, `branch`, `base-branch`, `assignees`,
`working-directory` and `runs-on`, plus the secrets `app-client-id` and `app-private-key`; `automerge.yml`
takes `branch`, `report-failure` and `runs-on`. For an application, call the QA workflows with
`dependency-versions: locked` so the CI tests exactly what is deployed.

A `dependabot.yml` for such an application only needs to cover what the workflows leave out:

```yaml
version: 2

updates:
  - package-ecosystem: composer
    directory: /
    schedule:
      interval: weekly
    ignore:
      - dependency-name: '*'
        update-types: ['version-update:semver-minor', 'version-update:semver-patch']
    commit-message:
      prefix: chore

  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: monthly
    commit-message:
      prefix: ci
```

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
