# FSD CI Checks

A GitHub Action that runs Steiger-based FSD checks plus lint/type/build in one go, and summarizes results in the Summary tab and PR comments.
It helps reviewers see FSD/type/lint/build status at a glance.

## Quick Start

1) Make sure your project has `pnpm fsd:check`, `pnpm typecheck`, and `pnpm build` scripts
2) If you do not have `.node-version`, change `setup-node` to use `node-version`
3) Add the minimal example below to your workflow

```yaml
jobs:
  checks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version-file: .node-version
      - uses: pnpm/action-setup@v4
        with:
          version: 10.27.0
          run_install: false
      - uses: ksh5324/fsd-ci-action@v2
```

## How It Works

- Runs in order: `install` (optional) -> `lint` -> `typecheck` -> `fsd` -> `build`.
- Captures each command's exit code and parses failure logs into `issues.tsv`. `ci-report.md` is always generated.
- By default, this action only summarizes results and does not fail the workflow.
  (You can customize success/failure policy using outputs in your workflow.)

## Prerequisites

- Node.js and a package manager (pnpm by default) must be available.
- The FSD tool used by `fsd-command` (for example, `steiger`) must be installed in your project.
- If you keep defaults, the `pnpm fsd:check` script must exist in your project.

## Usage

Basic usage:

```yaml
jobs:
  checks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version-file: .node-version
      - uses: pnpm/action-setup@v4
        with:
          version: 10.27.0
          run_install: false
      - uses: ksh5324/fsd-check-ci@v2
        with:
          working-directory: .
```

## Inputs

- `working-directory`: Working directory (default: `.`)
- `run-install`: Whether to run dependency install (default: `true`)
- `install-command`: Install command (default: `pnpm install --frozen-lockfile`)
- `lint-command`: Lint command (default: `pnpm exec eslint . -f unix --max-warnings=0`)
- `typecheck-command`: Typecheck command (default: `pnpm typecheck`)
- `fsd-command`: FSD check command (default: `pnpm fsd:check`)
- `run-build`: Whether to run build (default: `true`)
- `build-command`: Build command (default: `pnpm build`)
- `comment-on-pr`: Whether to create/update a PR comment (default: `false`)
- `comment-mode`: Comment update mode (`update` = append, `replace` = overwrite) (default: `replace`)
- `comment-header`: Marker used to find/update an existing comment (default: `<!-- ci-checks-summary -->`)
- `github-token`: Token used to post PR comments (default: `GITHUB_TOKEN`)
- `upload-artifacts`: Upload `ci-report.md`, `issues.tsv`, and `*.log` as artifacts (default: `false`)

## Outputs

- `lint-exit-code`: Exit code for lint (0 = success, non-zero = failure)
- `typecheck-exit-code`: Exit code for typecheck
- `fsd-exit-code`: Exit code for FSD check
- `build-exit-code`: Exit code for build
- `fsd-has-errors`: Whether FSD errors were detected (0/1). Set to 1 when log matches a specific pattern.

## Generated Files

- `issues.tsv`: Tab-separated list of lint/typecheck/fsd issues
- `ci-report.md`: Summary report in table format. Also shown in `GITHUB_STEP_SUMMARY`.
- Files are created under the `working-directory`.

## Where It Appears / How To Use

- The same summary as `ci-report.md` appears in the Actions run **Summary** tab.
- Outputs can be used for conditions or custom failure policies.
  Example: `if: ${{ steps.run-checks.outputs.lint-exit-code != '0' }}`

## Summary Output Example

`ci-report.md` is generated like this (partial example).
The same content appears in the Actions Summary tab.

```markdown
<!-- ci-checks-summary -->
# CI Checks Summary

## Lint

| File | Message |
|---|---|
| src/app.ts | no-unused-vars: 'x' is assigned a value but never used |

## Typecheck

| File | Message |
|---|---|
| src/types.ts | TS2322: Type 'string' is not assignable to type 'number'. |

## FSD

| Slice | Message |
|---|---|
| features/auth | This slice should not depend on shared/ui |
```

## Screenshots

Result shown as a PR comment

![PR comment usage](image/PR_use_source.png)

Build failure shown in Summary/PR comment

![PR comment build error](image/PR_comment_build.png)

Lint + FSD errors shown in Summary/PR comment

![PR comment lint and fsd errors](image/PR_comment_lint_fsd.png)

## Notes

- The FSD parser uses `help/fsd-awk/parse-fsd-issues.sh`.
- Add PR comment steps or failure policy in your workflow as needed.

## Use as PR Comment

To post `ci-report.md` as a PR comment, use the options below.
If you use `GITHUB_TOKEN`, make sure `permissions` includes `pull-requests: write`.
If you change `working-directory`, keep `WORKDIR` in sync.

```yaml
jobs:
  checks:
    runs-on: ubuntu-latest
    permissions:
      pull-requests: write
      contents: read
    env:
      WORKDIR: .
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version-file: .node-version
      - uses: pnpm/action-setup@v4
        with:
          version: 10.27.0
          run_install: false
      - uses: ksh5324/fsd-check-ci@v2
        with:
          working-directory: ${{ env.WORKDIR }}
          comment-on-pr: true
          comment-mode: replace
          comment-header: "<!-- ci-checks-summary -->"
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

## Fail The Workflow

By default, this action only summarizes results and does not fail the workflow.
Add a failure step based on outputs like below.

```yaml
      - name: FSD CI Checks
        id: fsd
        uses: ksh5324/fsd-ci-action@v2
        with:
          working-directory: .

      - name: Fail if checks failed
        if: ${{ always() }}
        run: |
          lint_code="${{ steps.fsd.outputs.lint-exit-code }}"
          type_code="${{ steps.fsd.outputs.typecheck-exit-code }}"
          fsd_code="${{ steps.fsd.outputs.fsd-exit-code }}"
          build_code="${{ steps.fsd.outputs.build-exit-code }}"
          fsd_has_errors="${{ steps.fsd.outputs.fsd-has-errors }}"

          if [ "${lint_code:-0}" != "0" ] || \
             [ "${type_code:-0}" != "0" ] || \
             [ "${build_code:-0}" != "0" ] || \
             [ "${fsd_has_errors:-0}" = "1" ] || \
             [ "${fsd_code:-0}" != "0" ]; then
            echo "One or more checks failed."
            exit 1
          fi
```

## Full Example You Can Copy

This is a full workflow example including PR comments. You can copy it as-is.
This example assumes a `pnpm`-based project.

Required setup:

- Node.js and `pnpm` are installed
- `.node-version` exists (or change `setup-node` to use `node-version` directly)
- Project scripts: `pnpm fsd:check`, `pnpm typecheck`, `pnpm build`
- FSD tool (for example, `steiger`) is included in dependencies

## Full Example Flow

The workflow proceeds in this order:

1) Checkout -> Node/pnpm setup -> dependency install
2) Run the action (lint/typecheck/fsd/build + summary)
3) Create or update PR comment (optional)
4) Decide final success/failure based on outputs

```yaml
name: CI

on:
  pull_request:

permissions:
  contents: read
  pull-requests: write

jobs:
  checks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version-file: .node-version
      - uses: pnpm/action-setup@v4
        with:
          version: 10.27.0
          run_install: false
      - name: FSD CI Checks
        id: fsd
        uses: ksh5324/fsd-check-ci@v2
        with:
          working-directory: .
          comment-on-pr: true
          comment-mode: replace
          comment-header: "<!-- ci-checks-summary -->"
          github-token: ${{ secrets.GITHUB_TOKEN }}
          upload-artifacts: true
      - name: Fail if checks failed
        if: ${{ always() }}
        run: |
          lint_code="${{ steps.fsd.outputs.lint-exit-code }}"
          type_code="${{ steps.fsd.outputs.typecheck-exit-code }}"
          fsd_code="${{ steps.fsd.outputs.fsd-exit-code }}"
          build_code="${{ steps.fsd.outputs.build-exit-code }}"
          fsd_has_errors="${{ steps.fsd.outputs.fsd-has-errors }}"

          if [ "${lint_code:-0}" != "0" ] || \
             [ "${type_code:-0}" != "0" ] || \
             [ "${build_code:-0}" != "0" ] || \
             [ "${fsd_has_errors:-0}" = "1" ] || \
             [ "${fsd_code:-0}" != "0" ]; then
            echo "One or more checks failed."
            exit 1
          fi
```

The FSD parser script is `help/fsd-awk/parse-fsd-issues.sh` in this action.

## Q&A

Q. PR comments are not showing up.
A. Check `comment-on-pr: true` and `permissions` includes `pull-requests: write`. For forked PRs, the default token is restricted.

Q. It says `ci-report.md` is missing.
A. If you changed `working-directory`, make sure it matches the actual working directory.

Q. FSD always fails.
A. Verify `pnpm fsd:check` exists and the FSD tool (for example, `steiger`) is installed. If log format changed, the parser may not match.

Q. I do not have `.node-version`.
A. Set `node-version` directly in `actions/setup-node`.

Q. I do not use pnpm.
A. Replace `install-command`, `lint-command`, `typecheck-command`, `fsd-command`, and `build-command` with npm/yarn commands.
