#!/usr/bin/env bash

set -o errexit          # Exit on most errors (see the manual)
set -o errtrace         # Make sure any error trap is inherited
set -o nounset          # Disallow expansion of unset variables
set -o pipefail         # Use last non-zero exit code in a pipeline
#set -o xtrace          # Trace the execution of the script (debug)

DISTRIBUTION=${1}

DOCKER_IMAGE_NANE="piaware-builder:${DISTRIBUTION}"
DOCKER_CONTINAER_NANE='piaware-builder'

# build builder image
docker build --tag "${DOCKER_IMAGE_NANE}" --file "Dockerfile-${DISTRIBUTION}" .

mkdir -p "package-${DISTRIBUTION}"
docker run --rm -it --name "${DOCKER_CONTINAER_NANE}" \
    -v "${PWD}:/build:ro" \
    -v "${PWD}/package-${DISTRIBUTION}:/build/package-${DISTRIBUTION}:rw" \
    --workdir="/build" "${DOCKER_IMAGE_NANE}" \
    ./sensible-build.sh "${DISTRIBUTION}"

mkdir -p "debs-${DISTRIBUTION}"
docker run --rm -it --name "${DOCKER_CONTINAER_NANE}" \
    -v "${PWD}/debs-${DISTRIBUTION}:/build:rw" \
    -v "${PWD}/package-${DISTRIBUTION}:/build/package-${DISTRIBUTION}:rw" \
    --workdir="/build/package-${DISTRIBUTION}" \
    "${DOCKER_IMAGE_NANE}" dpkg-buildpackage -b
