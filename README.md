# paper-verify — 논문 인용 검증 스킬

논문·보고서의 인용(법령·판례·학술문헌·웹출처)을 실제 원본과 대조해 실존·일치 여부를 검증하는 Claude Code 스킬.

- **법령·판례** — 법제처 국가법령정보센터 (k-skill 프록시 경유, 키 불필요): 조문 실존·본문 대조·개정/시행일 체크, 판례 사건번호 검증
- **학술 문헌** — CrossRef · OpenAlex · Semantic Scholar (영문), KCI · RISS (국문): DOI 대조, 저자·연도·저널 서지 검증
- **웹/보도자료** — 죽은 링크는 Wayback Machine 폴백
- 판정은 3단: ✅ 확인 / ⚠️ 불일치(무엇이 다른지 병기) / ❌ 미확인(환각 의심, 2개 소스 미발견 시에만)

AI 초안에 섞인 **환각 인용**, 집필 중 **개정된 조문**, 연도·저자 오기를 잡는 용도.

## 설치

[Claude Code](https://claude.com/claude-code) 필요.

```bash
git clone git@github.com:chrisryugj/paper-verify.git
mkdir -p ~/.claude/skills
cp -r paper-verify ~/.claude/skills/paper-verify
```

## 사용

Claude Code에서 논문 파일(HWP·PDF·텍스트)과 함께:

```
이 논문 인용 검증해줘
참고문헌 확인해줘
이 조문 현행인지 봐줘
이 주장 뒷받침할 선행연구 찾아줘   ← 탐색 모드
```

## 선택 설정 (없어도 동작)

| 환경변수 | 용도 | 발급 |
|----------|------|------|
| `KCI_API_KEY` | KCI 제목검색(articleSearch) — 국문 검증의 유일한 KCI 제목검색 경로. 없으면 RISS 주력 | https://open.kci.go.kr 무료 (IP 등록 방식, 막힐 수 있음) |
| `KCI_DATA_GO_KR_KEY` | 공공데이터포털 KCI **보조** — 제목검색 불가(artiId 조회만), 서지·참고문헌 보강용 | https://data.go.kr KCI OpenApi 활용신청(자동승인) |
| `LAW_OC` | 법제처 직접 호출 폴백 — 평소엔 프록시라 불필요 | https://open.law.go.kr 무료 |
| `OPENALEX_MAILTO` | OpenAlex polite pool — 본인 이메일 | 발급 불필요 |

## 구조

```
SKILL.md                  # 파이프라인: 추출 → 라우팅 → 판정 → 리포트
references/legal.md       # 법령·판례 검증 레시피 (법제처)
references/scholarly.md   # 학술 문헌 검증 레시피 (CrossRef·OpenAlex·S2·KCI·RISS)
```

## 크레딧

- 법령 프록시: [NomaDamas/k-skill](https://github.com/NomaDamas/k-skill) korean-law-search
- 법령 도구 설계 원본: [chrisryugj/korean-law-mcp](https://github.com/chrisryugj/korean-law-mcp)
