
$context_dir = $(Split-Path -Path $PSCommandPath -Parent)
Set-Location -Path $context_dir


function od_prune {
	Write-Host "Prune opsi-server containers, networks and volumes"
	Write-Host -NoNewline "Are you sure? (y/n): "
	$key = $Host.UI.RawUI.ReadKey().Character
	Write-Host ""
	if ($key -eq "Y" -Or $key -eq "y") {
		docker-compose down -v
	}
}


function od_start {
	Write-Host "Start containers"
	docker-compose up -d
}


function od_stop {
	Write-Host "Stop containers"
	docker-compose stop
}


function od_logs {
	param (
		$service
	)
	docker-compose logs -f $service
}


function od_shell {
	param (
		$service
	)
	$cmd = "sh"
	if (!$service) {
		$service = "opsi-server"
	}
	if ($service -eq "opsi-server") {
		$cmd = "zsh"
	}
	docker-compose exec $service $cmd
}


function od_update {
	docker-compose pull
	od_stop
	od_start
}


function od_export_images {
	$archive = "opsi-server-images.tar"
	if (Test-Path -Path $archive -PathType Leaf) {
		Remove-Item -Path $archive
	}
	$images = @()
	$out = docker-compose config
	$pattern = "\s*image:\s*([^\s]+)\s*"
	$matches = [regex]::Matches($out, $pattern)
	foreach ($match in $matches) {
		$images += $match.Groups[1].Value
	}
	if ($images.count -gt 0) {
		Write-Host "Exporting images $images to $archive"
		$archive = Join-Path $context_dir -ChildPath $archive
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
	if (-not(Test-Path -Path $archive -PathType Leaf)) {
		Write-Host "Archive $archive not found"
		exit 1
	}
	Write-Host "Importing images from $archive"
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
		$service = "opsi-server"
	}
	docker inspect opsi-server_$service_1
}


function od_diff {
	param (
		$service
	)
	if (!$service) {
		$service = "opsi-server"
	}
	docker diff opsi-server_$service_1
}


function od_usage {
	Write-Host "Usage: $(Split-Path -Path $PSCommandPath -Leaf) <command>"
	Write-Host ""
	Write-Host "Commands:"
	Write-Host "  edit                      Edit docker-compose.yml."
	Write-Host "  start                     Start all containers."
	Write-Host "  stop                      Stop all containers."
	Write-Host "  logs [service]            Attach to container logs (all logs or supplied service)."
	Write-Host "  shell [service]           Exexute a shell in the running container (default service: opsi-server)."
	Write-Host "  update                    Update and restart all containers."
	Write-Host "  open-volumes              Open volumes directory in explorer."
	Write-Host "  inspect [service]         Show detailed container informations (default service: opsi-server)."
	Write-Host "  diff [service]            Show container's filesystem changes (default service: opsi-server)."
	Write-Host "  prune                     Delete all containers and unassociated volumes."
	Write-Host "  export-images             Export images as archive."
	Write-Host "  import-images <archive>   Import images from archive."
	Write-Host ""
}


switch ($args[0]) {
	"edit" {
		od_edit
	}
	"start" {
		od_start
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
	"update" {
		od_update
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
