# 법령·판례 검증 레시피

기본 경로: k-skill 법제처 프록시 (`https://k-skill-proxy.nomadamas.org`, 키 불필요).
프록시 장애(5xx 지속) 시 법제처 직접 호출로 폴백 — 하단 참조.

## 1. 법령 실존 확인

```bash
curl -fsS --get 'https://k-skill-proxy.nomadamas.org/v1/korean-law/search' \
  --data-urlencode 'target=law' \
  --data-urlencode 'query=지방재정법'
```

- 응답에서 `법령명한글` 정확 일치 항목의 `법령일련번호`(MST)를 잡는다
- 약칭(화관법 등)은 정식 명칭이 따로 잡히므로 결과의 정식 법령명을 리포트에 병기
- `제개정구분명`·`시행일자`를 바로 기록 (현행성 판단 재료)

## 2. 조문 본문 대조

```bash
curl -fsS --get 'https://k-skill-proxy.nomadamas.org/v1/korean-law/detail' \
  --data-urlencode 'target=law' \
  --data-urlencode 'MST={법령일련번호}' \
  --data-urlencode 'JO={조번호6자리}'
```

- **법령 detail은 `MST=` 파라미터** (`ID=`로 넘기면 "일치하는 법령이 없습니다" — 실측)
- **JO 인코딩**: 조번호 4자리 + 가지번호 2자리. 제38조 → `003800` / 제10조의2 → `001002`
- 응답 JSON에 제어문자가 섞여 python `json.loads`가 깨질 수 있음 — 조문 대조는 `grep -o '"조문내용":"[^"]*'` 식 문자열 추출이 안전

대조 포인트:
- 항·호 번호가 논문 인용과 실제 조문 구조가 맞는가 (개정으로 항 번호 밀림 빈발)
- 논문이 따온 문구가 현행 조문에 실제로 있는가

## 3. 현행성 (개정·시행일 체크)

```bash
# 시행일 법령 — 시행 예정·최근 개정 이력
curl -fsS --get 'https://k-skill-proxy.nomadamas.org/v1/korean-law/search' \
  --data-urlencode 'target=eflaw' \
  --data-urlencode 'query=지방재정법'
```

- `eflaw`는 MST가 버전 고유 — 같은 법이 시행일별로 여러 건 나온다 (연혁 주의)
- 논문 탈고 시점보다 늦은 시행일이 있으면 ⚠️로 올리고 "시행 예정 개정 존재" 명시
- 인용된 조문이 개정 대상인지는 detail로 신·구 본문을 각각 받아 비교

## 4. 판례 검증

```bash
# 사건번호로 검색
curl -fsS --get 'https://k-skill-proxy.nomadamas.org/v1/korean-law/search' \
  --data-urlencode 'target=prec' \
  --data-urlencode 'nb=2019두38656'

# 본문(판시사항·판결요지) — 판례 detail은 ID= (법령과 다름)
curl -fsS --get 'https://k-skill-proxy.nomadamas.org/v1/korean-law/detail' \
  --data-urlencode 'target=prec' \
  --data-urlencode 'ID={판례일련번호}'
```

대조 순서: ① 사건번호 실존 → ② 법원·선고일자가 논문 표기와 일치 → ③ 판시사항이 논문의 서술과 부합.
- 사건번호 검색이 0건이면 키워드(`query=`)로 재시도 후 판정 (nb 파라미터가 안 먹는 출처도 있음)
- 본문 미제공 출처면 목록 메타(사건번호·법원·선고일·요지)까지만 확인하고 "본문 대조 못 함" 명시
- 하급심 판결 인용 시 상급심에서 파기됐는지 키워드로 추가 확인 (파기환송 여부)

## 5. 기타 타깃

| target | 용도 |
|--------|------|
| `detc` | 헌재결정례 (헌마·헌바·헌가 사건번호) |
| `expc` | 법령해석례(유권해석) — 행정 논문 단골 |
| `admrul` | 행정규칙(훈령·예규·고시) |
| `ordin` | 자치법규(조례·규칙) |
| `trty` | 조약 |

## 폴백: 법제처 직접 호출

프록시가 죽었을 때. OC 키 필요 (open.law.go.kr 무료 발급 — 가입 이메일의 @ 앞부분).
`$LAW_OC` 환경변수로 설정해 두고 쓴다. 미설정이면 폴백 불가로 리포트에 표기.

```bash
curl -fsS --get 'https://www.law.go.kr/DRF/lawSearch.do' \
  --data-urlencode "OC=$LAW_OC" \
  --data-urlencode 'target=law' \
  --data-urlencode 'type=JSON' \
  --data-urlencode 'query=지방재정법'
# 본문: lawService.do + MST + JO, 파라미터 체계 동일
```

빈/HTML 응답이 오면 User-Agent를 브라우저로 바꿔 재시도.
