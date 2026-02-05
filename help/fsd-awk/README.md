# FSD AWK 파서 (테스트용 도움말)

이 스크립트는 `fsd.log`에서 슬라이스 위치와 FSD 에러 메시지만 추출합니다.
플러그인 링크나 불필요한 라인은 무시합니다.

## 출력 형식

각 이슈는 한 줄의 TSV로 출력됩니다:

```
fsd\t<슬라이스>\t<메시지>
```

예시:

```
fsd\tentities\tThis slice has no references. Consider removing it.
```

## 사용법

```
./help/fsd-awk/parse-fsd-issues.sh fsd.log issues.tsv
```

기본값:
- 로그 파일: `fsd.log`
- 출력 파일: `issues.tsv`

## 참고

- `┌`, `✘` 같은 유니코드 트리/박스 문자에 의존하지 않습니다.
- ANSI 색상 코드(예: `\x1b[31m`)와 제어 문자를 제거한 뒤 파싱합니다.
- `This ...`가 포함된 줄만 메시지로 인식합니다.
- 줄 앞에 붙는 비알파뉴메릭 문자는 제거하고 파싱합니다.
