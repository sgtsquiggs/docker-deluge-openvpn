#!/usr/bin/env sh
set -e

IMAGE=$1

export DOCKER_CLI_EXPERIMENTAL=enabled

docker push "${IMAGE}:amd64-latest"
#docker push "${IMAGE}:arm32v7-latest"
#docker push "${IMAGE}:arm64v8-latest"
docker manifest push --purge "${IMAGE}:latest" || :
docker manifest create "${IMAGE}:latest" "${IMAGE}:amd64-latest"
#docker manifest create "${IMAGE}:latest" "${IMAGE}:arm32v7-latest" "${IMAGE}:arm64v8-latest" "${IMAGE}:amd64-latest"
#docker manifest annotate "${IMAGE}:latest" "${IMAGE}:arm32v7-latest" --os linux --arch arm
#docker manifest annotate "${IMAGE}:latest" "${IMAGE}:arm64v8-latest" --os linux --arch arm64 --variant v8
docker manifest push "${IMAGE}:latest"
