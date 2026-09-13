# Security Policy

## Reporting a vulnerability

Do not open a public issue for a security problem.

Report it through [GitHub's private vulnerability reporting](https://github.com/IQ2i/.github/security/advisories/new),
or by email to <contact@iq2i.com>. You will get an acknowledgement within a few working days.

## Scope

This repository holds reusable workflows and composite actions. The problems that matter most here are the
ones that could compromise a repository that calls them: an unpinned or hijackable third-party action, a
script that interpolates untrusted input into a shell command, or a workflow requesting more permissions
than it needs.

For a vulnerability in one of the applications or libraries that consume these workflows, report it on that
repository instead.
