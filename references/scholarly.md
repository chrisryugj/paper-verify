# 학술 문헌 검증 레시피

라우팅 순서 — **DOI가 있으면 무조건 CrossRef 단건 조회부터** (가장 확실).
없으면: 영문 → CrossRef 검색 → OpenAlex → Semantic Scholar / 국문 → KCI → RISS.
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

## KCI — 국내 학술지 (키 필요)

```bash
curl -sL --get "https://open.kci.go.kr/po/openapi/openApiSearch.kci" \
  --data-urlencode "apiCode=articleSearch" \
  --data-urlencode "key=$KCI_API_KEY" \
  --data-urlencode "title={논문제목}"
# 응답 XML: journalInfo/article-title/author-group/pub-year 대조
```

- `$KCI_API_KEY` 미설정이면 이 소스는 건너뛰고 리포트에 "KCI 미조회(키 없음)" 명시.
  키는 https://open.kci.go.kr 무료 발급 → `.zshrc` 등에 `export KCI_API_KEY=...`
- 파라미터: `title`(제목), `author`(저자), `journal`(학술지명) 조합 가능

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
