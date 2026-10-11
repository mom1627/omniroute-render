#!/usr/bin/env bash
set -u
export PROXY_PORT=${PROXY_PORT:-${PORT:-7860}}
P=${INTERNAL_PORT:-20128}; B=http://127.0.0.1:$P
: "${OMNIROUTE_ADMIN_PASSWORD:?missing}" "${MCP_PATH_SECRET:?missing}"
pw="$OMNIROUTE_ADMIN_PASSWORD"; unset OMNIROUTE_ADMIN_PASSWORD
echo "== setup"; omniroute setup --non-interactive --password "$pw" 2>&1 | sed "s/$pw/***/g" | tail -5
grep -q '^REQUIRE_API_KEY' ~/.omniroute/.env 2>/dev/null || echo "REQUIRE_API_KEY=true" >> ~/.omniroute/.env
export PORT=$P HOST=127.0.0.1 OMNIROUTE_SERVER_HOST=127.0.0.1
( while true; do omniroute serve --port $P --no-open --no-tray --log; echo "omniroute exited $?, restart"; sleep 5; done ) &
for i in $(seq 1 120); do curl -sf -o /dev/null $B/ && break; sleep 2; done; sleep 3
echo "== root: $(curl -s -o /dev/null -w '%{http_code}' $B/)"
J=/tmp/cj; rm -f $J
for i in 1 2 3 4 5; do
  code=$(curl -s -c $J -o /tmp/login.out -w '%{http_code}' -H 'Content-Type: application/json' -d "$(node -e 'console.log(JSON.stringify({password:process.argv[1]}))' "$pw")" $B/api/auth/login)
  echo "login: $code"; [ "$code" = 200 ] && break; sleep 3; done
KEY=$(curl -s -b $J -H 'Content-Type: application/json' -d '{"name":"claude-mcp","scopes":["manage","mcp:connect"]}' $B/api/keys | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{console.log(JSON.parse(s).key||"")}catch{console.log("")}})')
[ -n "$KEY" ] && echo "key created" || echo "KEY CREATION FAILED"
echo "settings PATCH: $(curl -s -o /dev/null -w "%{http_code}" -X PATCH -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" -d "{\"mcpEnabled\":true,\"mcpTransport\":\"streamable-http\"}" $B/api/settings)"
if [ -n "${GEMINI_API_KEY:-}" ]; then printf %s "$GEMINI_API_KEY" | omniroute keys add gemini --stdin 2>&1 | grep -v 'AQ\.' | tail -3; fi
unset GEMINI_API_KEY
echo "gemini test: $(curl -s -m 90 -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' -d '{"model":"gemini/gemini-3.8-flash","messages":[{"role":"user","content":"Reply only: OK works"}]}' $B/v1/chat/completions | head -c 400)"
export MCP_KEY="$KEY"
exec node /app/key-proxy.mjs
