# FSD CI Checks

Steiger 기반 FSD 검사와 lint/type/build를 한 번에 실행하고, 결과를 Summary/PR 코멘트로 보기 쉽게 정리해주는 CI Action입니다.
FSD/타입/린트/빌드 상태를 한눈에 확인할 수 있어 PR 리뷰와 품질 확인이 빠릅니다.

## 동작 방식

- `install`(선택) → `lint` → `typecheck` → `fsd` → `build` 순서로 실행됩니다.
- 각 명령의 종료 코드를 기록하고, 실패 시 로그를 파싱해 `issues.tsv`/`ci-report.md`로 요약합니다.
- 기본값 기준으로 `lint`, `typecheck`, `fsd`, `build` 중 하나라도 실패하면 워크플로가 실패합니다.
  (필요하면 워크플로에서 출력값을 기준으로 성공/실패 정책을 커스터마이즈할 수 있습니다.)

## 전제조건

- Node.js 및 패키지 매니저(pnpm 기준)가 설치되어 있어야 합니다.
- `fsd-command`에서 사용하는 FSD 검사 도구(예: `steiger`)가 프로젝트에 설치되어 있어야 합니다.
- 기본값을 그대로 쓸 경우 `pnpm fsd:check` 스크립트가 프로젝트에 존재해야 합니다.

## 사용법

기본 사용법:

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

## 입력값

- `working-directory`: 작업 디렉터리 (기본: `.`)
- `run-install`: 설치 실행 여부 (기본: `true`)
- `install-command`: 설치 명령어 (기본: `pnpm install --frozen-lockfile`)
- `lint-command`: lint 명령어 (기본: `pnpm exec eslint . -f unix --max-warnings=0`)
- `typecheck-command`: typecheck 명령어 (기본: `pnpm typecheck`)
- `fsd-command`: FSD 검사 명령어 (기본: `pnpm fsd:check`)
- `run-build`: build 실행 여부 (기본: `true`)
- `build-command`: build 명령어 (기본: `pnpm build`)

## 출력값

- `lint-exit-code`: lint 명령의 종료 코드 (0=성공, 그 외=실패)
- `typecheck-exit-code`: typecheck 명령의 종료 코드
- `fsd-exit-code`: FSD 검사 명령의 종료 코드
- `build-exit-code`: build 명령의 종료 코드
- `fsd-has-errors`: FSD 오류 감지 여부 (0/1). FSD 로그가 특정 패턴을 포함할 때 1로 설정됩니다.

## 생성 파일

- `issues.tsv`: lint/typecheck/fsd 이슈를 탭 구분으로 기록한 파일
- `ci-report.md`: 이슈를 표로 정리한 요약 리포트. `GITHUB_STEP_SUMMARY`에도 자동으로 표시됩니다.
- 생성 위치는 `working-directory` 기준입니다.

## 표시 위치 / 활용

- `ci-report.md`와 동일한 요약이 Actions 실행 화면의 **Summary** 탭에 표시됩니다.
- 출력값은 워크플로에서 조건 분기나 실패 처리를 위해 사용할 수 있습니다.
  예: `if: ${{ steps.run-checks.outputs.lint-exit-code != '0' }}`

## 요약 출력 예시

`ci-report.md`는 아래처럼 테이블 형태로 생성됩니다(일부 예시).
동일한 내용이 Actions Summary 탭에 표시됩니다.

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

## 예시 화면

실제 PR에 코멘트로 붙은 결과 화면

![PR comment usage](image/PR_use_source.png)

빌드 실패가 Summary/코멘트에 표시된 화면

![PR comment build error](image/PR_comment_build.png)

lint + FSD 오류가 Summary/코멘트에 표시된 화면

![PR comment lint and fsd errors](image/PR_comment_lint_fsd.png)

## 참고

- FSD 파서는 `help/fsd-awk/parse-fsd-issues.sh`를 사용합니다.
- PR 코멘트나 실패 처리 로직은 워크플로에서 추가로 구성하세요.

## PR 코멘트로 사용하기

`ci-report.md` 내용을 PR 코멘트로 남기려면 워크플로에 단계 하나를 추가하세요.
아래 예시는 `GITHUB_TOKEN`으로 동일 PR에 코멘트를 갱신합니다.
`working-directory`를 변경했다면 `WORKDIR` 값과 경로도 같이 맞춰주세요.

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

## 그대로 붙여서 사용하는 전체 예시

PR 코멘트까지 포함된 실제 워크플로 예시입니다. 그대로 복사해 사용해도 됩니다.

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

FSD 파서 스크립트는 이 액션 내 `help/fsd-awk/parse-fsd-issues.sh`를 사용합니다.
