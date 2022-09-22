
$PROJECT_NAME = "opsi-client-debian-xfce"
$DEFAULT_SERVICE = "opsi-client-debian-xfce"
$DOCKER_COMPOSE = "docker-compose"

if ((Get-Command $DOCKER_COMPOSE -ErrorAction SilentlyContinue) -eq $null) {
	$DOCKER_COMPOSE = "docker compose"
}

$context_dir = $(Split-Path -Path $PSCommandPath -Parent)
Set-Location -Path $context_dir


function od_prune {
	Write-Host "Prune ${PROJECT_NAME} containers, networks and volumes"
	Write-Host -NoNewline "Are you sure? (y/n): "
	$key = $Host.UI.RawUI.ReadKey().Character
	Write-Host ""
	if ($key -eq "Y" -Or $key -eq "y") {
		Write-Host "${DOCKER_COMPOSE} down -d"
		& ${DOCKER_COMPOSE} down -v
	}
}


function od_start {
	Write-Host "Start containers"
	Write-Host "${DOCKER_COMPOSE} up -d"
	& ${DOCKER_COMPOSE} up -d
}


function od_status {
	Write-Host "${DOCKER_COMPOSE} ps"
	& ${DOCKER_COMPOSE} ps
}


function od_stop {
	Write-Host "Stop containers"
	Write-Host "${DOCKER_COMPOSE} stop"
	& ${DOCKER_COMPOSE} stop
}


function od_logs {
	param (
		$service
	)
	Write-Host "${DOCKER_COMPOSE} logs -f $service"
	& ${DOCKER_COMPOSE} logs -f $service
}


function od_shell {
	param (
		$service
	)
	$cmd = "sh"
	if (!$service) {
		$service = $DEFAULT_SERVICE
	}
	if ($service -eq "opsi-server") {
		$cmd = "zsh"
	}
	Write-Host "${DOCKER_COMPOSE} exec $service $cmd"
	& ${DOCKER_COMPOSE} exec $service $cmd
}


function od_upgrade {
	Write-Host "docker-compose pull"
	& ${DOCKER_COMPOSE} pull
	if ($? -eq $false) {
		exit 1
	}
	Write-Host "${DOCKER_COMPOSE} down"
	& ${DOCKER_COMPOSE} down
	Write-Host "${DOCKER_COMPOSE} up --force-recreate -d"
	& ${DOCKER_COMPOSE} up --force-recreate -d
}


function od_export_images {
	$archive = "$PROJECT_NAME-images.tar.gz"
	if (Test-Path -Path $archive -PathType Leaf) {
		Remove-Item -Path $archive
	}
	$images = @()
	$out = & ${DOCKER_COMPOSE} config
	$pattern = "\s*image:\s*([^\s]+)\s*"
	$matches = [regex]::Matches($out, $pattern)
	foreach ($match in $matches) {
		$images += $match.Groups[1].Value
	}
	if ($images.count -gt 0) {
		Write-Host "Exporting images $images to $archive"
		$archive = Join-Path $context_dir -ChildPath $archive
		Write-Host "docker save $images -o \"$archive\""
		docker save $images -o "$archive"
	}
	else {
		Write-Host "No images found to export"
	}
}


function od_import_images {
	param (
		$archive
	)
	if (!$archive) {
		$archive = "$PROJECT_NAME-images.tar.gz"
	}
	if (-not(Test-Path -Path $archive -PathType Leaf)) {
		Write-Host "Archive $archive not found"
		exit 1
	}
	Write-Host "Importing images from $archive"
	Write-Host "docker load -i $archive"
	docker load -i $archive
}


function od_open_volumes {
	start explorer.exe "\\wsl$\docker-desktop-data\version-pack-data\community\docker\volumes"
}


function od_edit {
	start docker-compose.yml
}


function od_inspect {
	param (
		$service
	)
	if (!$service) {
		$service = $DEFAULT_SERVICE
	}
	Write-Host "docker inspect ${PROJECT_NAME}_${service}_1"
	docker inspect ${PROJECT_NAME}_${service}_1
}


function od_diff {
	param (
		$service
	)
	if (!$service) {
		$service = $DEFAULT_SERVICE
	}
	Write-Host "docker diff ${PROJECT_NAME}_${service}_1"
	docker diff ${PROJECT_NAME}_${service}_1
}


function od_usage {
	Write-Host "Usage: $(Split-Path -Path $PSCommandPath -Leaf) <command>"
	Write-Host ""
	Write-Host "Commands:"
	Write-Host "  edit                      Edit docker-compose.yml."
	Write-Host "  start                     Start all containers."
	Write-Host "  status                    Show running containers."
	Write-Host "  stop                      Stop all containers."
	Write-Host "  logs [service]            Attach to container logs (all logs or supplied service)."
	Write-Host "  shell [service]           Exexute a shell in a running container (default service: ${DEFAULT_SERVICE})."
	Write-Host "  upgrade                   Upgrade and restart all containers."
	Write-Host "  open-volumes              Open volumes directory in explorer."
	Write-Host "  inspect [service]         Show detailed container informations (default service: ${DEFAULT_SERVICE})."
	Write-Host "  diff [service]            Show container's filesystem changes (default service: ${DEFAULT_SERVICE})."
	Write-Host "  prune                     Delete all containers and unassociated volumes."
	Write-Host "  export-images             Export images as archive."
	Write-Host "  import-images [archive]   Import images from archive."
	Write-Host ""
}


switch ($args[0]) {
	"edit" {
		od_edit
	}
	"start" {
		od_start
	}
	"status" {
		od_status
	}
	"stop" {
		od_stop
	}
	"logs" {
		od_logs $args[1]
	}
	"shell" {
		od_shell $args[1]
	}
	"upgrade" {
		od_upgrade
	}
	"open-volumes" {
		od_open_volumes
	}
	"inspect" {
		od_inspect $args[1]
	}
	"diff" {
		od_diff $args[1]
	}
	"prune" {
		od_prune
	}
	"export-images" {
		od_export_images
	}
	"import-images" {
		od_import_images $args[1]
	}
	default {
		od_usage
		exit 1
	}
}

exit 0
