# 학술 문헌 검증 레시피

라우팅 순서 — **DOI가 있으면 무조건 CrossRef 단건 조회부터** (가장 확실).
없으면: 영문 → CrossRef 검색 → OpenAlex → Semantic Scholar / **국문 → KCI 제목검색(학술지논문)** → RISS(학위논문·미발견 보강).
❌(환각) 판정은 최소 2개 소스 미발견 + 검색어 변형(제목 일부·저자명·영문 제목) 시도 후.

공통 원칙 (실측):
- **응답은 `-o 파일`로 받아서 파싱** — 파이프 직결(`curl | python3`)은 이 환경에서 잘림/제어문자로 깨짐
- **검색은 fuzzy** — total-results 건수로 판정하지 말 것. 상위 결과의 제목·저자를 인용 표기와 직접 대조해서 "일치 항목 존재 여부"로 판정

## CrossRef (키 불필요)

```bash
# DOI 단건 — 저자·연도·저널을 인용 표기와 대조
curl -sL "https://api.crossref.org/works/{DOI}"

# 제목 검색
curl -sL --get "https://api.crossref.org/works" \
  --data-urlencode "query.bibliographic={제목 저자}" \
  --data-urlencode "rows=5"
```

- 응답 `message.title`, `message.author[].family/given`, `message.issued`, `message.container-title` 대조
- DOI가 404면 그 자체가 강한 환각 신호 (단, 국문 논문은 DOI 없어도 정상 — KCI로)

## OpenAlex (키 불필요, mailto 필수)

```bash
curl -sL --get "https://api.openalex.org/works" \
  --data-urlencode "search={제목}" \
  --data-urlencode "per-page=5" \
  --data-urlencode "mailto=${OPENALEX_MAILTO:-anon@example.com}"
```

- `mailto` 없으면 익명 풀이라 부하 시 차단됨 — 반드시 붙인다 (본인 이메일이면 됨, 별도 발급 불필요)
- 한국 학술지도 DOI 등록분은 잡힘. `results[].display_name`, `publication_year`, `authorships[].author.display_name` 대조

## Semantic Scholar (키 불필요, 429 잦음)

```bash
curl -sL --get "https://api.semanticscholar.org/graph/v1/paper/search" \
  --data-urlencode "query={제목}" \
  --data-urlencode "limit=5" \
  --data-urlencode "fields=title,year,authors,externalIds,venue"
```

- 429 응답이면 `sleep 3` 후 1회 재시도, 계속 429면 이 소스는 건너뛰고 다른 소스로 판정

## KCI — 국내 학술지

두 경로를 **article-id로 연결**해서 쓴다: **(a) open.kci.go.kr** 로 제목검색→서지대조(주력), 필요하면 얻은 `article-id`로 **(b) 공공데이터포털** 에서 참고문헌까지 확장.

### (a) open.kci.go.kr articleSearch — 제목검색 O (국문 주력, 실측 2026-07-08)
```bash
# ⚠️ 한글은 UTF-8이어야 함. mac/linux(UTF-8 로케일)는 --data-urlencode로 바로:
curl -sL --ssl-no-revoke --get "https://open.kci.go.kr/po/openapi/openApiSearch.kci" \
  --data-urlencode "apiCode=articleSearch" \
  --data-urlencode "key=$KCI_API_KEY" \
  --data-urlencode "title={논문제목}" \
  --data-urlencode "displayCount=10" -o kci.xml
# Windows Git bash 등 CP949 콘솔에선 한글 리터럴이 깨짐 → title을 UTF-8 percent-encoding으로:
#   지방재정 → title=%EC%A7%80%EB%B0%A9%EC%9E%AC%EC%A0%95  (-G --data 로 raw 전달)
```
- 응답 구조(실측): `<record>` 반복. 각 record 안에서 대조 —
  - `journalInfo/journal-name`·`publisher-name`·`pub-year`·`volume`·`issue`
  - `articleInfo` `@article-id`(예 `ART002912911`), `title-group/article-title`(lang=original|foreign|english CDATA), `author-group/author`(@english=로마자, 텍스트는 "이름(소속)"), `abstract`, `fpage`/`lpage`, `doi`, `citation-count`(@kci/@wos), `url`
- 판정: `<total>`은 fuzzy 매칭 총건수 — 건수로 단정 말고 record의 `article-title`을 인용 표기와 직접 대조. 저자·연도·권호까지 맞으면 ✅.
- 파라미터: `title`(제목), `author`(저자), `journal`(학술지명) 조합 가능. `$KCI_API_KEY` 없으면 RISS로 폴백하고 "KCI 미조회(키 없음)" 명시.
- 키 발급: https://open.kci.go.kr (IP 등록 방식). 키는 `.env.local`의 `KCI_API_KEY`.

### (b) 공공데이터포털 KCI — 제목검색 X, article-id 조회 전용 (실측 2026-07-08)
`apis.data.go.kr/B552540/KCIOpenApi/*`는 **벌크/ID조회형**이라 제목검색이 안 된다(`title` 파라미터 무시, 전체 220만건 덤프). **(a)에서 얻은 `article-id`로만** 서지·참고문헌 확장에 쓴다.
```bash
# 참고문헌 목록 (article-id 필요) — REFCNT>0인 논문의 인용 검증에 유용
curl -sS --ssl-no-revoke -A "Mozilla/5.0" -G \
  "$KCI_DATA_GO_KR_BASE/doiInfo/openApiD215List" \
  --data-urlencode "ServiceKey=$KCI_DATA_GO_KR_KEY" \
  --data-urlencode "pageNo=1" --data-urlencode "recordCnt=50" \
  --data-urlencode "artiId={article-id}"
```
- 호출 조건(실측): **브라우저 User-Agent 필수**(curl 기본 UA는 KCI 웹방화벽 400 차단), 필수 `pageNo`·`recordCnt`, `serviceKey` base64 `I`/`l` 혼동 주의. 키는 `KCI_DATA_GO_KR_KEY`.
- 유효 오퍼레이션: `doiInfo/D214`=서지(KORTITLE/ENGTITLE/ENGABS/SPAGE/REFCNT), `D215`=참고문헌, `D213`=권호. 프로브: `scripts/kci-probe.sh`.

## RISS — 학위논문·국내문헌 (키 불필요, HTML 파싱)

```bash
curl -sL --max-time 20 \
  -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
  --get "https://www.riss.kr/search/Search.do" \
  --data-urlencode "query={검색어}" \
  --data-urlencode "colName=bib_t"
```

- `colName`: `bib_t`(학위논문) / `re_a_kor`(국내학술지논문) / `all`(전체)
- 결과는 HTML — `detail/DetailView.do?...control_no=...` 링크 유무가 히트 판별 기준 (0건 페이지엔 이 링크가 없음, `<p class="title">`은 메뉴에도 있어 단독으로 쓰지 말 것)
- 데스크톱 UA 필수 (없으면 차단). Jina Reader로는 안 뚫림 — 직접 curl만
- 학위논문 검증은 사실상 RISS가 유일한 무료 경로

## arXiv (프리프린트 인용 시)

```bash
curl -sL "http://export.arxiv.org/api/query?search_query=ti:{제목}&max_results=5"
```

## Rate limits

| 소스 | 제한 | 대응 |
|------|------|------|
| CrossRef | 50/sec | 사실상 자유 |
| OpenAlex | polite pool | mailto 필수 |
| Semantic Scholar | 낮음, 429 잦음 | sleep 3 + 1회 재시도 후 skip |
| KCI | 명시 없음 | 건당 0.5s 간격 권장 |
| RISS | 비공식 | 건당 1s 간격, 대량 조회 자제 |
| arXiv | 3/sec | sleep 필수 |

대량 검증(20건+) 시 소스별 순차 처리하고, 같은 문헌을 여러 소스에 중복 조회하지 않는다 — 한 소스에서 서지 일치가 확정되면 다음 문헌으로.
