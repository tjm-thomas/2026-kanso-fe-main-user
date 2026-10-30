#!/usr/bin/env bash
# The frontend must never answer for /api. The bug this guards: when be-main is removed
# from an environment its Ingress goes too, Traefik sends /api/* to this app (prefix /),
# and the SPA fallback (try_files ... /index.html) answered 200 text/html: a dead backend
# that looked alive. Builds the image and runs it locally; no cluster, no secrets.
set -uo pipefail
cd "$(dirname "$0")/.."
fail() { echo "FAIL: $1" >&2; exit 1; }

name=fe-main-user-test port=18088
cleanup() { docker rm -f "${name}" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup
docker build -q -t fe-main-user:test . >/dev/null || fail "image build failed"
docker run -d --name "${name}" -p "127.0.0.1:${port}:80" fe-main-user:test >/dev/null || fail "container did not start"
for _ in $(seq 1 30); do
  curl -sf "http://127.0.0.1:${port}/healthz" >/dev/null && break
  sleep 1
done
curl -sf "http://127.0.0.1:${port}/healthz" >/dev/null || fail "/healthz never came up"

# status <path>: prints "<http code> <content-type without charset>"
status() { curl -s -o /dev/null -w '%{http_code} %{content_type}' "http://127.0.0.1:${port}$1" | sed 's/;.*//'; }

# The defect: API paths must not get the SPA page
for p in /api /api/ /api/status /api/companies/count; do
  got="$(status "${p}")"
  [ "${got%% *}" = 404 ] || fail "${p} should be 404, got: ${got}"
done
# ...and the SPA fallback still works for everything else
[ "$(status /)" = "200 text/html" ]              || fail "/ should be the SPA page, got: $(status /)"
[ "$(status /release)" = "200 text/html" ]       || fail "/release (release.html) should serve, got: $(status /release)"
[ "$(status /no/such/page)" = "200 text/html" ]  || fail "unknown paths should fall back to index.html, got: $(status /no/such/page)"
[ "$(status /version.txt)" = "200 text/plain" ]  || fail "/version.txt should serve, got: $(status /version.txt)"
[ "$(status /apix)" = "200 text/html" ]          || fail "/apix is not an API path and should fall back, got: $(status /apix)"

echo PASS
