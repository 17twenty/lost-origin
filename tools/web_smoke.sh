#!/usr/bin/env bash
# Smoke-tests the web build in headless Chrome (system Google Chrome via playwright-core).
# usage: tools/web_smoke.sh [url]   (default: serve build/web on http://127.0.0.1:8765/)
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -d tools/web/node_modules/playwright-core ]] || (cd tools/web && npm install --silent)
URL=${1:-http://127.0.0.1:8765/}
SERVER=""
if [[ "$URL" == http://127.0.0.1:8765* ]]; then
	[[ -f build/web/index.html ]] || { echo "no build/web — run tools/export_web.sh first"; exit 1; }
	python3 -m http.server 8765 --bind 127.0.0.1 --directory build/web >/tmp/lo_http.log 2>&1 &
	SERVER=$!
	trap '[[ -n "$SERVER" ]] && kill $SERVER 2>/dev/null' EXIT
	sleep 1
fi
shift || true
node tools/web/smoke.mjs "$URL" "$@"
