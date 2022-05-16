#!/bin/bash

PROJECT_NAME="opsi-client-debian-xfce"
IMAGE_NAME="opsi-client-debian-xfce"
DEFAULT_SERVICE="opsi-client-debian-xfce"
[ -z $REGISTRY ] && REGISTRY="docker.uib.gmbh/opsi"
[ -z $OPSI_VERSION ] && OPSI_VERSION="4.2"
[ -z $OPSI_BRANCH ] && OPSI_BRANCH="experimental"
IMAGE_TAG="${OPSI_VERSION}-${OPSI_BRANCH}"

cd $(dirname "${BASH_SOURCE[0]}")


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
	echo "Prune ${PROJECT_NAME} containers, networks and volumes" 1>&2
	read -p "Are you sure? (y/n): " -n 1 -r
	echo ""
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		echo "docker-compose down -v" 1>&2
		docker-compose down -v
	fi
}

function od_start {
	echo "Start containers" 1>&2
	echo "docker-compose up -d" 1>&2
	docker-compose up -d
}


function od_status {
	echo "docker-compose ps"
	docker-compose ps
}


function od_stop {
	echo "Stop containers" 1>&2
	echo "docker-compose stop" 1>&2
	docker-compose stop
}


function od_logs {
	echo "docker-compose logs -f $1" 1>&2
	docker-compose logs -f $1
}


function od_shell {
	service="$1"
	cmd="sh"
	[ -z $service ] && service=$DEFAULT_SERVICE
	[ $service = "opsi-server" ] && cmd="zsh"
	echo "docker-compose exec $service $cmd" 1>&2
	docker-compose exec $service $cmd
}


function od_update {
	echo "docker-compose pull" 1>&2
	docker-compose pull || exit 1
	od_stop
	od_start
}


function od_export_images {
	archive="${PROJECT_NAME}-images.tar.gz"
	[ -e "${archive}" ] && rm "${archive}"
	images=( $(docker-compose config | grep "image:" | sed s'/.*image:\s*//' | tr '\n' ' ') )
	if [ ${#images[@]} -gt 0 ]; then
		echo "Exporting images ${images[@]} to ${archive}" 1>&2
		echo "docker save ${images[@]} | gzip > \"${archive}\"" 1>&2
		docker save ${images[@]} | gzip > "${archive}"
	else
		echo "No images found to export" 1>&2
	fi
}


function od_import_images {
	archive="$1"
	[ -z $archive ] && archive="${PROJECT_NAME}-images.tar.gz"
	if [ ! -e "${archive}" ]; then
		echo "Archive ${archive} not found" 1>&2
		exit 1
	fi
	echo "Importing images from ${archive}" 1>&2
	echo "docker load -i \"${archive}\"" 1>&2
	docker load -i "${archive}"
}


function od_open_volumes {
	sudo xdg-open /var/lib/docker/volumes
}


function od_edit {
	xdg-open docker-compose.yml
}


function od_inspect {
	service="$1"
	[ -z $service ] && service=$DEFAULT_SERVICE
	echo "docker inspect ${PROJECT_NAME}_${service}_1" 1>&2
	docker inspect ${PROJECT_NAME}_${service}_1
}


function od_diff {
	service="$1"
	[ -z $service ] && service=$DEFAULT_SERVICE
	echo "docker diff ${PROJECT_NAME}_${service}_1" 1>&2
	docker diff ${PROJECT_NAME}_${service}_1
}


function od_usage {
	echo "Usage: $0 <command>"
	echo ""
	echo "Commands:"
	echo "  edit                      Edit docker-compose.yml."
	echo "  start                     Start all containers."
	echo "  status                    Show running containers."
	echo "  stop                      Stop all containers."
	echo "  logs [service]            Attach to container logs (all logs or supplied service)."
	echo "  shell [service]           Exexute a shell in a running container (default service: ${DEFAULT_SERVICE})."
	echo "  update                    Update and restart all containers."
	echo "  open-volumes              Open volumes directory in explorer."
	echo "  inspect [service]         Show detailed container informations (default service: ${DEFAULT_SERVICE})."
	echo "  diff [service]            Show container's filesystem changes (default service: ${DEFAULT_SERVICE})."
	echo "  prune                     Delete all containers and unassociated volumes."
	echo "  export-images             Export images as archive."
	echo "  import-images <archive>   Import images from archive."
	echo "  build [--no-cache]        Build ${IMAGE_NAME} image. Use --no-cache to build without cache."
	echo "  publish                   Publish ${IMAGE_NAME} image."
	echo ""
}


case $1 in
	"edit")
		od_edit
	;;
	"start")
		od_start
	;;
	"status")
		od_status
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
	"open-volumes")
		od_open_volumes
	;;
	"inspect")
		od_inspect $2
	;;
	"diff")
		od_diff $2
	;;
	"prune")
		od_prune
	;;
	"export-images")
		od_export_images
	;;
	"import-images")
		od_import_images $2
	;;
	"build")
		od_build $2
	;;
	"publish")
		od_publish
	;;
	*)
		od_usage
		exit 1
	;;
esac

exit 0
