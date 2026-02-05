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
