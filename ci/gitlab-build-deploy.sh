#!/usr/bin/env bash
# The GitLab twin of .github/workflows/build-deploy.yml, run by .gitlab-ci.yml.
# staging branch: build the image once, push it to this project's registry, then ask the
# platform to deploy it to staging. main branch: no build; ask for the promote to prod
# (the platform's deploy-prod job waits for a Maintainer to press play).
# The tag is git's tree hash of the repo content, same as on GitHub, so a merge maps to
# the image staging tested. DEPLOY_SYSTEM decides which CI system may deploy this app.
# Needs: PLATFORM_TRIGGER_TOKEN (masked, protected variable), PLATFORM_PROJECT_ID (.gitlab-ci.yml).
set -euo pipefail

system="$(cat DEPLOY_SYSTEM 2>/dev/null || echo github)"
if [ "${system}" != gitlab ]; then
  echo "DEPLOY_SYSTEM is ${system}, not gitlab; skipping"
  exit 0
fi

APP=fe-main-user
: "${CI_REGISTRY_IMAGE:?not running under GitLab CI}"
IMAGE_REPO="${CI_REGISTRY_IMAGE,,}"
IMAGE="${IMAGE_REPO}:$(git rev-parse --short=12 'HEAD^{tree}')"
if [ "${CI_COMMIT_BRANCH:-}" = main ]; then ENV=prod; else ENV=staging; fi

if [ "${ENV}" = staging ]; then
  printf '%s' "${CI_JOB_TOKEN}" | docker login -u gitlab-ci-token --password-stdin "${CI_REGISTRY}"
  if docker manifest inspect "${IMAGE}" >/dev/null 2>&1; then
    echo "${IMAGE} already exists, not rebuilding"
  else
    docker build --build-arg "VERSION=${IMAGE##*:}" \
      --label "org.opencontainers.image.source=${CI_PROJECT_URL}" \
      -t "${IMAGE}" .
    docker push "${IMAGE}"
  fi
fi

# The clusters pull anonymously: the project is public, so its registry is too
docker logout "${CI_REGISTRY}" >/dev/null
if ! docker manifest inspect "${IMAGE}" >/dev/null 2>&1; then
  echo "Cannot pull ${IMAGE} without a login." >&2
  [ "${ENV}" = prod ] && echo "It is not in the registry: push this change to staging first." >&2
  echo "If it exists, check the project is Public (its registry inherits that)." >&2
  exit 1
fi

: "${PLATFORM_TRIGGER_TOKEN:?variable PLATFORM_TRIGGER_TOKEN is not set}"
: "${PLATFORM_PROJECT_ID:?variable PLATFORM_PROJECT_ID is not set}"
echo "==> Asking the platform to deploy ${IMAGE} to ${ENV}"
curl -sS -f -X POST "https://gitlab.com/api/v4/projects/${PLATFORM_PROJECT_ID}/trigger/pipeline" \
  --form "token=${PLATFORM_TRIGGER_TOKEN}" \
  --form ref=main \
  --form "variables[ACTION]=deploy" \
  --form "variables[APP]=${APP}" \
  --form "variables[ENV]=${ENV}" \
  --form "variables[IMAGE]=${IMAGE}" \
  --form "variables[SOURCE]=${CI_PROJECT_PATH}@${CI_COMMIT_SHORT_SHA}" \
  -o /dev/null
echo "Deploy of ${IMAGE} to ${ENV} requested."
echo "Follow it at https://gitlab.com/tjm-thomas/2026-kubernetes-platform/-/pipelines"
[ "${ENV}" = prod ] && echo "prod waits for a Maintainer to press play there." || true
