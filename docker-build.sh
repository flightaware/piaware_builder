#!/usr/bin/env bash

set -o errexit          # Exit on most errors (see the manual)
set -o errtrace         # Make sure any error trap is inherited
set -o nounset          # Disallow expansion of unset variables
set -o pipefail         # Use last non-zero exit code in a pipeline
#set -o xtrace          # Trace the execution of the script (debug)

DISTRIBUTION=${1}

DOCKER_IMAGE_NANE="piaware-builder:${DISTRIBUTION}"
DOCKER_CONTINAER_NANE="piaware-builder-${DISTRIBUTION}"

# build builder image
docker build --tag "${DOCKER_IMAGE_NANE}" --file "Dockerfile-${DISTRIBUTION}" .

# Setup the build env
mkdir -p "package-${DISTRIBUTION}"
docker run --rm -it --name "${DOCKER_CONTINAER_NANE}" \
    -u="${UID}:$(id -g ${USER})" -v '/etc/group:/etc/group:ro' -v '/etc/passwd:/etc/passwd:ro' \
    -v "${PWD}:/build:ro" \
    -v "${PWD}/package-${DISTRIBUTION}:/build/package-${DISTRIBUTION}:rw" \
    --workdir="/build" "${DOCKER_IMAGE_NANE}" \
    ./sensible-build.sh "${DISTRIBUTION}"

# build the deb packages
mkdir -p "debs-${DISTRIBUTION}"
docker run --rm -it --name "${DOCKER_CONTINAER_NANE}" \
    -u="${UID}:$(id -g ${USER})" -v '/etc/group:/etc/group:ro' -v '/etc/passwd:/etc/passwd:ro' \
    -v "${PWD}/debs-${DISTRIBUTION}:/build:rw" \
    -v "${PWD}/package-${DISTRIBUTION}:/build/package-${DISTRIBUTION}:rw" \
    --workdir="/build/package-${DISTRIBUTION}" \
    "${DOCKER_IMAGE_NANE}" dpkg-buildpackage -b

rm -rf "package-${DISTRIBUTION}"
rm -rf "debs-${DISTRIBUTION}/package-${DISTRIBUTION}"
