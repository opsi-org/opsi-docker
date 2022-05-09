#!/bin/bash

cd $(dirname "${BASH_SOURCE[0]}")

IMAGE_NAME="opsi-server"
[ -z $REGISTRY ] && REGISTRY="docker.uib.gmbh/opsi"
[ -z $OPSI_VERSION ] && OPSI_VERSION="4.2"
[ -z $OPSI_BRANCH ] && OPSI_BRANCH="experimental"
IMAGE_TAG="${OPSI_VERSION}-${OPSI_BRANCH}"


function od_build {
	echo "Build ${IMAGE_NAME}:${IMAGE_TAG}" 1>&2
	docker build $1 \
		--tag "${IMAGE_NAME}:${IMAGE_TAG}" \
		--build-arg OPSI_VERSION=$OPSI_VERSION \
		--build-arg OPSI_BRANCH=$OPSI_BRANCH \
		.
}


function od_publish {
	echo "Publish ${IMAGE_NAME}:${IMAGE_TAG} in ${REGISTRY}" 1>&2
	opsiconfd_version=$(docker run -e OPSI_HOSTNAME=opsiconfd.opsi.org --entrypoint /usr/bin/opsiconfd "${IMAGE_NAME}:${IMAGE_TAG}" --version | cut -d' ' -f1)

	docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
	docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${REGISTRY}/${IMAGE_NAME}:${opsiconfd_version}"
	#docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${REGISTRY}/${IMAGE_NAME}:${OPSI_VERSION}-${OPSI_BRANCH}-latest"

	docker push -a "${REGISTRY}/${IMAGE_NAME}"

	docker images "${REGISTRY}/${IMAGE_NAME}"
}


function od_prune {
	echo "Prune containers, images and volumes" 1>&2
	read -p "Are you sure? (y/n): " -n 1 -r
	echo ""
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		od_stop
		docker-compose rm -f
		docker volume prune -f
		docker image ls "opsi-server*" --quiet | xargs docker image rm --force 2>/dev/null
	fi
}

function od_start {
	echo "Start containers" 1>&2
	docker-compose up -d
}


function od_stop {
	echo "Stop containers" 1>&2
	docker-compose stop
}


function od_logs {
	docker-compose logs -f $1
}


function od_shell {
	service="$1"
	cmd="sh"
	[ -z $service ] && service="opsi-server"
	[ $service = "opsi-server" ] && cmd="zsh"
	docker-compose exec $service $cmd
}


function od_update {
	docker-compose pull
	od_stop
	od_start
}

function od_export_images {
	archive="opsi-server-images.tar.gz"
	[ -e "${archive}" ] && rm "${archive}"
	images=( $(docker-compose config | grep image | sed s'/.*image:\s*//' | tr '\n' ' ') )
	echo "Exporting images ${images[@]} to ${archive}" 1>&2
	docker save ${images[@]} | gzip > "${archive}"
}

function od_import_images {
	archive="$1"
	[ -e "${archive}" ] || (echo "Archive ${archive} not found" 1>&2; exit 1)
	echo "Importing images from ${archive}" 1>&2
	docker load -i "${archive}"
}

function od_usage {
	echo "Usage: $0 {start|stop|logs|shell|update|prune|build|publish|export-images|import-images}"
	echo ""
	echo "  start                     Start all containers."
	echo "  stop                      Stop all containers."
	echo "  logs [service]            Attach to container logs (all logs or supplied service)."
	echo "  shell [service]           Exexute a shell in the running container (default service: opsi-server)."
	echo "  update                    Update and restart all containers."
	echo "  prune                     Delete all containers and unassociated volumes."
	echo "  build [--no-cache]        Build opsi-server image. Use --no-cache to build without cache."
	echo "  publish                   Publish opsi-server image."
	echo "  export-images             Export images as archive."
	echo "  import-images <archive>   Import images from archive."
	echo ""
}

case $1 in
	"start")
		od_start
	;;
	"stop")
		od_stop
	;;
	"logs")
		od_logs $2
	;;
	"shell")
		od_shell $2
	;;
	"update")
		od_update
	;;
	"prune")
		od_prune
	;;
	"build")
		od_build $2
	;;
	"publish")
		od_publish
	;;
	"export-images")
		od_export_images
	;;
	"import-images")
		od_import_images $2
	;;
	*)
		od_usage
		exit 1
	;;
esac

exit 0
