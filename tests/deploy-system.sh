#!/usr/bin/env bash
# ci/deploy-system.sh decides which CI system deploys this app. The bug this guards:
# both CI systems compared the DEPLOY_SYSTEM file byte-for-byte and treated anything that
# was not their own name as "skip", so a CRLF copy (a Linux runner reading an exported
# Windows tree) or a typo deployed nothing anywhere, with no error on either side.
# Pure logic on scratch files; no cluster, no CI.
set -uo pipefail
cd "$(dirname "$0")/.."
fail() { echo "FAIL: $1" >&2; exit 1; }

tmp="$(mktemp -d)"; trap 'rm -rf "${tmp}"' EXIT
# with <printf format>: run the script against a scratch root whose DEPLOY_SYSTEM holds it
with() { printf "$1" > "${tmp}/DEPLOY_SYSTEM"; bash ci/deploy-system.sh "${tmp}" 2>&1; }

[ "$(with 'gitlab\n')" = gitlab ]     || fail "LF gitlab not read"
[ "$(with 'gitlab\r\n')" = gitlab ]   || fail "CRLF gitlab not read (the airgap case)"
[ "$(with ' GitHub \r\n')" = github ] || fail "whitespace and case not normalised"
[ "$(with 'github')" = github ]       || fail "file without a trailing newline not read"
rm -f "${tmp}/DEPLOY_SYSTEM"
[ "$(bash ci/deploy-system.sh "${tmp}" 2>&1)" = github ] || fail "a missing file should mean github"

out="$(with 'gitlub\n')" && fail "a typo was accepted: ${out}"
grep -q DEPLOY_SYSTEM <<<"${out}" || fail "the refusal should name the file: ${out}"
out="$(with '')" && fail "an empty file was accepted: ${out}"

[ "$(bash ci/deploy-system.sh)" = gitlab ] || fail "this repo's own DEPLOY_SYSTEM should read gitlab"

# Both CI entry points go through the script; neither reads the file inline any more
for f in ci/gitlab-build-deploy.sh .github/workflows/build-deploy.yml; do
  grep -q 'bash ci/deploy-system.sh' "${f}" || fail "${f} does not call ci/deploy-system.sh"
  grep -q 'cat DEPLOY_SYSTEM' "${f}" && fail "${f} still reads DEPLOY_SYSTEM inline"
done
grep -qx 'DEPLOY_SYSTEM text eol=lf' .gitattributes || fail ".gitattributes does not pin DEPLOY_SYSTEM to LF"

echo PASS
