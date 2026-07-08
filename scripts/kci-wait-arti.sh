#!/usr/bin/env bash
# artiInfo(논문정보) 활용신청 반영 대기 폴링.
# 15분 간격, 최대 8회(2시간). 200+resultCode 00 뜨면 즉시 종료(ACTIVATED).
set -u
cd "$(dirname "$0")/.." || exit 1
set -a; . ./.env.local; set +a
KEY="$KCI_DATA_GO_KR_KEY"; BASE="$KCI_DATA_GO_KR_BASE"
OUT="${TEMP:-/tmp}/kci_arti.xml"
UA='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36'
URL="$BASE/artiInfo/openApiD217List"

for i in $(seq 1 8); do
  code=$(curl -sS --ssl-no-revoke --max-time 25 -A "$UA" -o "$OUT" -w "%{http_code}" --get "$URL" \
    --data-urlencode "ServiceKey=$KEY" --data-urlencode "pageNo=1" --data-urlencode "recordCnt=3")
  if [ "$code" = "200" ] && grep -q "<resultCode>00</resultCode>" "$OUT"; then
    echo "ACTIVATED (attempt $i)"; head -c 800 "$OUT" | tr -d '\r'; exit 0
  fi
  echo "attempt $i/8 → HTTP $code (still not active). waiting 15m..."
  [ "$i" -lt 8 ] && sleep 900
done
echo "TIMEOUT: artiInfo 2시간 내 반영 안 됨 (마지막 HTTP $code)"; exit 1
