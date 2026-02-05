## Typecheck 파서 (tsc)

이 폴더에는 `tsc` 출력에서 TypeScript 오류만 추출하는 간단한 파서가 있습니다.

### 동작 원리

- `typecheck.log`를 한 줄씩 읽습니다.
- ANSI 컬러 코드와 제어 문자를 제거합니다.
- `: error TSxxxx:` 패턴에만 매칭하여 불필요한 로그를 제거합니다.
- 매칭된 항목은 `issues.tsv`에 아래 형식으로 기록합니다.
  - `typecheck<TAB>file<TAB>error message`

### 입력 예시

`tsc` 출력 예:

```
src/features/auth/ui/login-form.tsx(4,9): error TS2322: Type 'number' is not assignable to type 'string'.
```

출력 결과:

```
typecheck	src/features/auth/ui/login-form.tsx	error TS2322: Type 'number' is not assignable to type 'string'.
```

### 파일

- `parse-typecheck-issues.sh`: `typecheck.log`에서 오류만 추출합니다.
