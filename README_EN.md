# FSD CI Checks

A GitHub Action that runs Steiger-based FSD checks plus lint/type/build in one go, and summarizes results in the Summary tab and PR comments.
It helps reviewers see FSD/type/lint/build status at a glance.

## How It Works

- Runs in order: `install` (optional) -> `lint` -> `typecheck` -> `fsd` -> `build`.
- Captures each command's exit code and parses logs into `issues.tsv` and `ci-report.md` when failures occur.
- With defaults, the workflow fails if any of `lint`, `typecheck`, `fsd`, or `build` fails.
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
      - uses: ksh5324/fsd-check-ci@v1
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

To post `ci-report.md` as a PR comment, add a step to your workflow.
The example below updates the same PR comment using `GITHUB_TOKEN`.
If you change `working-directory`, keep `WORKDIR` and `body-path` in sync.

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
      - uses: ksh5324/fsd-check-ci@v1
        with:
          working-directory: ${{ env.WORKDIR }}
      - name: PR comment (ci-report.md)
        if: ${{ github.event_name == 'pull_request' }}
        uses: peter-evans/create-or-update-comment@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          issue-number: ${{ github.event.pull_request.number }}
          body-path: ${{ github.workspace }}/${{ env.WORKDIR }}/ci-report.md
          body-includes: "<!-- ci-checks-summary -->"
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
2) Run lint/typecheck/fsd/build (continue even on failure)
3) Parse logs and generate `ci-report.md`/Summary
4) Create or update PR comment
5) Decide final success/failure based on collected results

```yaml
name: CI

on:
  pull_request:

permissions:
  contents: read
  pull-requests: write
  issues: write

defaults:
  run:
    shell: bash

jobs:
  checks:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version-file: .node-version

      - name: Setup pnpm
        uses: pnpm/action-setup@v4
        with:
          version: 10.27.0
          run_install: false

      - name: Install
        run: pnpm install --frozen-lockfile

      - name: Lint
        id: lint
        continue-on-error: true
        run: |
          set -o pipefail
          set +e
          pnpm exec eslint . -f unix --max-warnings=0 2>&1 | tee lint.log
          status=${PIPESTATUS[0]}
          set -e
          echo "exit_code=${status}" >> "$GITHUB_OUTPUT"

      - name: Typecheck
        id: typecheck
        continue-on-error: true
        run: |
          set -o pipefail
          set +e
          pnpm typecheck 2>&1 | tee typecheck.log
          status=${PIPESTATUS[0]}
          set -e
          echo "exit_code=${status}" >> "$GITHUB_OUTPUT"

      - name: FSD Check
        id: fsd
        continue-on-error: true
        run: |
          set -o pipefail
          set +e
          pnpm fsd:check 2>&1 | tee fsd.log
          status=${PIPESTATUS[0]}
          set -e
          echo "exit_code=${status}" >> "$GITHUB_OUTPUT"
          if [ -s fsd.log ] && grep -qE "✗|×" fsd.log; then
            echo "has_errors=1" >> "$GITHUB_OUTPUT"
          else
            echo "has_errors=0" >> "$GITHUB_OUTPUT"
          fi

      - name: Build
        id: build
        continue-on-error: true
        run: |
          set -o pipefail
          set +e
          pnpm build 2>&1 | tee build.log
          status=${PIPESTATUS[0]}
          set -e
          echo "exit_code=${status}" >> "$GITHUB_OUTPUT"

      - name: Report Summary
        if: always()
        run: |
          lint_code="${{ steps.lint.outputs.exit_code }}"
          type_code="${{ steps.typecheck.outputs.exit_code }}"
          fsd_code="${{ steps.fsd.outputs.exit_code }}"
          build_code="${{ steps.build.outputs.exit_code }}"

          rm -f issues.tsv

          if [ "${lint_code:-0}" != "0" ] && [ -s lint.log ]; then
            grep -E "^[^ ]+:[0-9]+:[0-9]+ " lint.log | \
              awk -F: '{
                file=$1;
                msg=$4;
                for (i=5;i<=NF;i++) msg=msg ":" $i;
                print "lint\t" file "\t" msg
              }' >> issues.tsv || true
            if ! grep -q "^lint\t" issues.tsv 2>/dev/null; then
              tail -n 5 lint.log | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | \
                awk 'NF>0 {print "lint\t(see log)\t" $0}' >> issues.tsv || true
            fi
          fi

          if [ "${type_code:-0}" != "0" ] && [ -s typecheck.log ]; then
            grep -E "error TS[0-9]+:" typecheck.log | \
              awk -F: '{
                file=$1;
                msg=$2;
                for (i=3;i<=NF;i++) msg=msg ":" $i;
                sub(/^ \([0-9]+,[0-9]+\)/,"",msg);
                print "typecheck\t" file "\t" msg
              }' >> issues.tsv || true
            if ! grep -q "^typecheck\t" issues.tsv 2>/dev/null; then
              tail -n 5 typecheck.log | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | \
                awk 'NF>0 {print "typecheck\t(see log)\t" $0}' >> issues.tsv || true
            fi
          fi

          if [ "${fsd_code:-0}" = "1" ] && [ -s fsd.log ]; then
            ./help/fsd-awk/parse-fsd-issues.sh fsd.log issues.tsv || true
            if ! grep -q "^fsd\t" issues.tsv 2>/dev/null; then
              echo "fsd\t(see full log below)\tParser did not match FSD output format." >> issues.tsv
            fi
          fi

          {
            echo "<!-- ci-checks-summary -->"
            echo "# CI Checks Summary"
            echo ""
            echo "## Lint"
            echo ""
            echo "| File | Message |"
            echo "|---|---|"
            if [ -s issues.tsv ]; then
              awk -F'\t' '$1=="lint"{gsub("\\|","\\\\|",$2); gsub("\\|","\\\\|",$3); printf "| %s | %s |\n", $2, $3}' issues.tsv
            fi
            echo ""
            echo "## Typecheck"
            echo ""
            echo "| File | Message |"
            echo "|---|---|"
            if [ -s issues.tsv ]; then
              awk -F'\t' '$1=="typecheck"{gsub("\\|","\\\\|",$2); gsub("\\|","\\\\|",$3); printf "| %s | %s |\n", $2, $3}' issues.tsv
            fi
            echo ""
            echo "## FSD"
            echo ""
            echo "| Slice | Message |"
            echo "|---|---|"
            if [ -s issues.tsv ]; then
              awk -F'\t' '$1=="fsd"{gsub("\\|","\\\\|",$2); gsub("\\|","\\\\|",$3); printf "| %s | %s |\n", $2, $3}' issues.tsv
            fi
            echo ""

            if [ "${build_code:-0}" != "0" ]; then
              echo "## Build (errors)"
              echo ""
              echo '```'
              if [ -s build.log ]; then
                tail -n 200 build.log || true
              else
                echo "No build output captured."
              fi
              echo '```'
              echo ""
            fi
          } | tee ci-report.md >> "$GITHUB_STEP_SUMMARY"

          if [ ! -s issues.tsv ] && { [ "${lint_code:-0}" != "0" ] || [ "${type_code:-0}" != "0" ] || [ "${fsd_code:-0}" = "1" ]; }; then
            {
              echo ""
              echo "## Raw Logs (fallback)"
              echo ""
              echo "### Lint"
              echo '```'
              [ -s lint.log ] && tail -n 120 lint.log || echo "No lint output captured."
              echo '```'
              echo ""
              echo "### Typecheck"
              echo '```'
              [ -s typecheck.log ] && tail -n 120 typecheck.log || echo "No typecheck output captured."
              echo '```'
              echo ""
              echo "### FSD"
              echo '```'
              [ -s fsd.log ] && tail -n 120 fsd.log || echo "No FSD output captured."
              echo '```'
              echo ""
            } | tee -a ci-report.md >> "$GITHUB_STEP_SUMMARY"
          fi

      - name: Comment on PR
        if: always() && github.event_name == 'pull_request'
        id: find-comment
        uses: peter-evans/find-comment@v3
        with:
          issue-number: ${{ github.event.pull_request.number }}
          body-includes: "<!-- ci-checks-summary -->"

      - name: Create or Update PR Comment
        if: always() && github.event_name == 'pull_request'
        uses: peter-evans/create-or-update-comment@v4
        with:
          issue-number: ${{ github.event.pull_request.number }}
          comment-id: ${{ steps.find-comment.outputs.comment-id }}
          body-path: ci-report.md
          edit-mode: replace

      - name: Fail if checks failed
        if: ${{ always() }}
        run: |
          lint_code="${{ steps.lint.outputs.exit_code }}"
          type_code="${{ steps.typecheck.outputs.exit_code }}"
          fsd_code="${{ steps.fsd.outputs.exit_code }}"
          build_code="${{ steps.build.outputs.exit_code }}"
          fsd_has_errors="${{ steps.fsd.outputs.has_errors }}"

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
A. Check `permissions` includes `pull-requests: write`. For forked PRs, the default token is restricted. Also verify `body-path`.

Q. It says `ci-report.md` is missing.
A. If you changed `working-directory`, make sure `WORKDIR` and `body-path` match.

Q. FSD always fails.
A. Verify `pnpm fsd:check` exists and the FSD tool (for example, `steiger`) is installed. If log format changed, the parser may not match.

Q. I do not have `.node-version`.
A. Set `node-version` directly in `actions/setup-node`.

Q. I do not use pnpm.
A. Replace `install-command`, `lint-command`, `typecheck-command`, `fsd-command`, and `build-command` with npm/yarn commands.
