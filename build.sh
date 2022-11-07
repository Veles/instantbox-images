#!/bin/bash

SHOULD_PUSH=true
[[ -z "${DOCKER_USER}" ]] && SHOULD_PUSH=false
[[ -z "${DOCKER_PASSWORD}" ]] && SHOULD_PUSH=false

echo "Downloading latest ttyd"
rm "./ttyd_linux.x86_64" >/dev/null 2&>1
wget -q "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION:-1.4.2}/ttyd_linux.x86_64"
if [[ ! -f "./ttyd_linux.x86_64" ]]; then
  echo "Failed to download ttyd"
  exit 1
fi

echo "Downloading latest ssshwifty"
rm "sshwifty_0.2.30-beta-release_linux_amd64.tar.gz" >/dev/null 2&>1
wget -q https://github.com/nirui/sshwifty/releases/download/0.2.30-beta-release-prebuild/sshwifty_0.2.30-beta-release_linux_amd64.tar.gz
tar -xf sshwifty_0.2.30-beta-release_linux_amd64.tar.gz

if $SHOULD_PUSH; then
  docker login -u "$DOCKER_USER" -p "$DOCKER_PASSWORD" "$DOCKER_REGISTRY"
fi

for IMAGE_NAME in $(cat manifest.json | grep osCode\":\ \" | grep -o '[a-z-]*\/[a-z-][^"]*'); do
  SUFFIX=`echo ${IMAGE_NAME##*/}`
  OS=${SUFFIX%:*}
  VERSION=${SUFFIX##*:}
  DOCKERFILE="./os/$OS/Dockerfile-$VERSION"

  echo ""
  echo "##########################################################################"
  echo "##  Building $IMAGE_NAME using $DOCKERFILE"
  echo "##########################################################################"
#  docker pull "$IMAGE_NAME" || true
   docker build \
    --cache-from "$IMAGE_NAME" \
    --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    --build-arg VCS_REF="$(git rev-parse --short HEAD)" \
    -t "$IMAGE_NAME" \
    -f "$DOCKERFILE" \
    . \
    || exit 1

  docker tag "$IMAGE_NAME"  "$IMAGE_NAME"-local

  if $SHOULD_PUSH; then
    docker push "$IMAGE_NAME"
  fi
done
