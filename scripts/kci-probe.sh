#!/usr/bin/env bash
# KCI 공공데이터포털 OpenAPI 프로브
# 용도:
#   1) 신규 발급 키 활성화 여부 확인(401이 사라지면 활성화됨)
#   2) 논문 제목/저자 검색이 가능한 오퍼레이션이 있는지 실측 탐색
# 실행: bash scripts/kci-probe.sh
# 키는 .env.local 에서 로드.

set -u
cd "$(dirname "$0")/.." || exit 1
# shellcheck disable=SC1091
set -a; . ./.env.local; set +a

KEY="${KCI_DATA_GO_KR_KEY:?KCI_DATA_GO_KR_KEY 미설정 (.env.local 확인)}"
BASE="${KCI_DATA_GO_KR_BASE:-https://apis.data.go.kr/B552540/KCIOpenApi}"
OUT="${TEMP:-/tmp}/kci_probe.xml"

# curl 공통 옵션.
#  --ssl-no-revoke : Windows schannel revocation 우회
#  -A 브라우저 UA  : KCI 웹방화벽이 curl 기본 UA를 봇으로 차단(400) → 필수
UA='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36'
call () {
  local url="$1"; shift
  curl -sS --ssl-no-revoke --max-time 25 -A "$UA" -o "$OUT" -w "%{http_code}" --get "$url" \
    --data-urlencode "ServiceKey=$KEY" --data-urlencode "pageNo=1" --data-urlencode "recordCnt=5" "$@"
}

probe () {
  local label="$1" url="$2"; shift 2
  local code; code=$(call "$url" "$@")
  echo "── $label → HTTP $code"
  head -c 500 "$OUT" | tr -d '\r'; echo; echo
}

echo "###############################################"
echo "# 1) 활성화 스모크 테스트"
echo "###############################################"
probe "sereInfo/openApiD154List" "$BASE/sereInfo/openApiD154List"
# → 여전히 401 이면: 키 활성화 대기중. 1~2시간 후 재실행.
# → 00 (resultCode) / 정상 XML 이면: 키 활성화됨.

echo "###############################################"
echo "# 2) 확정된 유효 호출 (실측 2026-07-08)"
echo "#    ⚠️ 제목검색은 불가 — 모두 artiId를 이미 아는 경우의 조회다."
echo "#    (제목만 있는 인용의 실존검증은 RISS/open.kci.go.kr로)"
echo "###############################################"
ARTI="${1:-ART001333086}"   # 조회할 논문ID (첫 인자로 교체 가능)

# 논문 서지정보(제목/초록/키워드/페이지/참고문헌수) — artiId로 단건 조회
probe "서지 D214 (artiId=$ARTI)"  "$BASE/doiInfo/openApiD214List" --data-urlencode "artiId=$ARTI"
# 논문 참고문헌 — artiId로
probe "참고문헌 D215 (artiId=$ARTI)" "$BASE/doiInfo/openApiD215List" --data-urlencode "artiId=$ARTI"
# 논문-학술지 매핑(학술지ID·권호ID) — artiId로
probe "매핑 D218 (artiId=$ARTI)"   "$BASE/artiInfo/openApiD218List" --data-urlencode "artiId=$ARTI"

echo "==> 참고: 유효 오퍼레이션 맵"
echo "   doiInfo/D214=서지, D215=참고문헌, D213=권호/발행연월"
echo "   artiInfo/D217=반입현황, D218=논문-학술지매핑, D219=그림, D220=표문단"
echo "   sereInfo/D154~D158=학술지-분야/인증, insiInfo/M142=공동발행기관"
echo "   ↳ 어느 것도 제목·저자 검색을 지원하지 않음(전부 벌크/ID조회형)"
