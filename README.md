# FSD CI Checks

Steiger 기반 FSD 검사와 lint/type/build 요약을 생성하는 GitHub Action입니다.

## 사용법

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

- `lint-exit-code`
- `typecheck-exit-code`
- `fsd-exit-code`
- `build-exit-code`
- `fsd-has-errors`

## 생성 파일

- `issues.tsv`
- `ci-report.md`

## 참고

- FSD 파서는 `help/fsd-awk/parse-fsd-issues.sh`를 사용합니다.
- PR 코멘트나 실패 처리 로직은 워크플로에서 추가로 구성하세요.
