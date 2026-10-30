#!/usr/bin/env bash
# Print which CI system deploys this app: github or gitlab, from the DEPLOY_SYSTEM file in
# the repo root (missing file = github). Both the GitHub workflow and the GitLab pipeline
# read it through this script, so whitespace (a CRLF copy on a Linux runner included) and
# case never matter, and a value that is neither exits 1: each system used to treat anything
# but its own name as "skip", so a typo deployed nothing anywhere without an error.
# Usage: bash ci/deploy-system.sh [repo-root]
set -euo pipefail

root="${1:-$(dirname "$0")/..}"
value=""
if [ -f "${root}/DEPLOY_SYSTEM" ]; then
  value="$(tr -d '[:space:]' < "${root}/DEPLOY_SYSTEM")"
  value="${value,,}"
else
  value=github
fi

case "${value}" in
  github|gitlab) echo "${value}" ;;
  *)
    echo "DEPLOY_SYSTEM must say github or gitlab (missing = github); it says '${value}'" >&2
    exit 1
    ;;
esac
