#!/bin/bash

IMAGE_NAME="opsiconfd"
[ -z $REGISTRY ] && REGISTRY="docker.uib.gmbh/opsi/prod"
[ -z $OPSI_VERSION ] && OPSI_VERSION="4.2"
[ -z $OPSI_BRANCH ] && OPSI_BRANCH="development"
IMAGE_TAG="${OPSI_VERSION}-${OPSI_BRANCH}"


function build {
	docker build --no-cache \
		--tag "${IMAGE_NAME}:${IMAGE_TAG}" \
		--build-arg OPSI_VERSION=$OPSI_VERSION \
		--build-arg OPSI_BRANCH=$OPSI_BRANCH \
		opsiconfd
}


function publish {
	opsiconfd_version=$(docker run -e OPSI_HOSTNAME=opsiconfd.opsi.org --entrypoint /usr/bin/opsiconfd "${IMAGE_NAME}:${IMAGE_TAG}" --version | cut -d' ' -f1)

	docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
	docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${REGISTRY}/${IMAGE_NAME}:${opsiconfd_version}"
	#docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${REGISTRY}/${IMAGE_NAME}:${OPSI_VERSION}-${OPSI_BRANCH}-latest"

	docker push -a "${REGISTRY}/${IMAGE_NAME}"

	docker images "${REGISTRY}/${IMAGE_NAME}"
}


function prune {
	docker-compose rm -f
	docker volume prune -f
}

function run {
	docker-compose up
}


case $1 in
	"build")
		build
	;;
	"run")
		run
	;;
	"publish")
		publish
	;;
	"prune")
		prune
	;;
	*)
		echo "Usage: $0 {build|run|publish|prune}"
		exit 1
	;;
esac

exit 0
