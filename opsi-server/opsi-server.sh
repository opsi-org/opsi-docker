#!/bin/bash

cd $(dirname "${BASH_SOURCE[0]}")

IMAGE_NAME="opsi-server"
[ -z $REGISTRY ] && REGISTRY="docker.uib.gmbh/opsi"
[ -z $OPSI_VERSION ] && OPSI_VERSION="4.2"
[ -z $OPSI_BRANCH ] && OPSI_BRANCH="experimental"
IMAGE_TAG="${OPSI_VERSION}-${OPSI_BRANCH}"


function build {
	echo "Build ${IMAGE_NAME}:${IMAGE_TAG}" 1>&2
	docker build $1 \
		--tag "${IMAGE_NAME}:${IMAGE_TAG}" \
		--build-arg OPSI_VERSION=$OPSI_VERSION \
		--build-arg OPSI_BRANCH=$OPSI_BRANCH \
		.
}


function publish {
	echo "Publish ${IMAGE_NAME}:${IMAGE_TAG} in ${REGISTRY}" 1>&2
	opsiconfd_version=$(docker run -e OPSI_HOSTNAME=opsiconfd.opsi.org --entrypoint /usr/bin/opsiconfd "${IMAGE_NAME}:${IMAGE_TAG}" --version | cut -d' ' -f1)

	docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
	docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${REGISTRY}/${IMAGE_NAME}:${opsiconfd_version}"
	#docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${REGISTRY}/${IMAGE_NAME}:${OPSI_VERSION}-${OPSI_BRANCH}-latest"

	docker push -a "${REGISTRY}/${IMAGE_NAME}"

	docker images "${REGISTRY}/${IMAGE_NAME}"
}


function prune {
	echo "Prune containers, images and volumes" 1>&2
	read -p "Are you sure? (y/n): " -n 1 -r
	echo ""
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		stop
		docker-compose rm -f
		docker volume prune -f
		docker image ls "opsi-server*" --quiet | xargs docker image rm 2>/dev/null
	fi
}

function start {
	echo "Start containers" 1>&2
	docker-compose up -d
}


function stop {
	echo "Stop containers" 1>&2
	docker-compose stop
}


function logs {
	docker-compose logs -f
}


function shell {
	service="$1"
	cmd="sh"
	[ -z $service ] && service="opsi-server"
	[ $service = "opsi-server" ] && cmd="zsh"
	docker-compose exec $service $cmd
}


function update {
	docker-compose pull
	stop
	start
}


case $1 in
	"start")
		start
	;;
	"stop")
		stop
	;;
	"logs")
		logs
	;;
	"shell")
		shell
	;;
	"update")
		update
	;;
	"prune")
		prune
	;;
	"build")
		build
	;;
	"publish")
		publish
	;;
	*)
		echo "Usage: $0 {start|stop|logs|shell|update|prune|build|publish}"
		echo ""
		echo "  start                Start all containers."
		echo "  stop                 Stop all containers."
		echo "  logs                 Attach to container logs."
		echo "  shell [service]      Exexute a shell in the running container (default service: opsi-server)."
		echo "  update               Update and restart all containers."
		echo "  prune                Delete all containers and unassociated volumes."
		echo "  build [--no-cache]   Build opsi-server image. Use --no-cache to build without cache."
		echo "  publish              Publish opsi-server image."
		echo ""
		exit 1
	;;
esac

exit 0
