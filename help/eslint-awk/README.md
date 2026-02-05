## Lint 파서 (eslint)

이 폴더에는 ESLint 출력에서 오류 라인만 추출하는 간단한 파서가 있습니다.

### 동작 원리

- `lint.log`를 한 줄씩 읽습니다.
- ANSI 컬러 코드와 제어 문자를 제거합니다.
- `파일:라인:컬럼: 메시지` 패턴만 매칭하여 불필요한 로그를 제거합니다.
- 매칭된 항목은 `issues.tsv`에 아래 형식으로 기록합니다.
  - `lint<TAB>file<TAB>message`

### 입력 예시

ESLint 출력 예:

```
/path/to/src/features/auth/ui/login-form.tsx:4:9: 'count' is assigned a value but never used. [Warning/@typescript-eslint/no-unused-vars]
```

출력 결과:

```
lint	/path/to/src/features/auth/ui/login-form.tsx	'count' is assigned a value but never used. [Warning/@typescript-eslint/no-unused-vars]
```

### 파일

- `parse-lint-issues.sh`: `lint.log`에서 lint 오류만 추출합니다.
