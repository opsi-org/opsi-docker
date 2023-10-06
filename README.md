# Official opsi server image

This image can be used to set up an opsi config-server or an opsi depot-server.
The only supported depot protocol is WebDAV, there is no Samba support included in this image.
File backend is not supported, you will need an opsi MySQL module license.

All files mentioned here and the full README are available in the following GitHub repository:

https://github.com/opsi-org/opsi-docker

# Quick start
```
git clone https://github.com/opsi-org/opsi-docker.git
cd opsi-docker/opsi-server
./opsi-server.sh start
```

# Docker Compose
The image is meant to be used with Docker Compose.
Minimum required Docker Compose version is 1.17.0 with Docker engine 17.09.0+.
There are four services defined in the docker-compose.yml:
- mysql: The current stable official MariaDB Server.
- redis: Latest official Redis Server from Redis Labs with RedisTimeSeries Module.
- grafana: The latest official Grafana Server from Grafana Labs.
- opsi-server: Contains the latest opsiconfd, opsipxeconfd, opsi-tftpd-hpa and opsi-utils from uib GmbH.

# How to use this image
## Install Docker
Install Docker or Docker Desktop for Linux, macOS or Windows.
Open an terminal and make sure the command `docker run --rm hello-world` is working.

## docker-compose.yml
The docker-compose.yml is a YAML file defining services, networks and volumes.

At the start of the file there are some X Properties defined (x-restart-policy for example).
These YAML anchors are used to share settings between services.

For security reasons you should change all passwords in this file:
`MYSQL_ROOT_PASSWORD`, `MYSQL_PASSWORD`, `REDIS_PASSWORD`, `GF_SECURITY_ADMIN_PASSWORD` and `OPSI_ADMIN_PASSWORD`.
The root account has no password set. If needed, it is possible to set the root password via `OPSI_ROOT_PASSWORD`.

## Helper script
There are helper scripts called `opsi-server.sh` and `opsi-server.ps1` that can be used to simplify container handling.

In a Linux or macOS environment, open a terminal and make sure that the help script is executable (`chmod +x opsi-server.sh`).
Now run `./opsi-server.sh` to display the help text of the script.
In a Windows environment, open a terminal with Powershell and run `.\opsi-server.ps1`.

## Usage as opsi config-server
- Adapt the docker-compose.yml to your needs regarding network and volumes.
- Set the variable `OPSI_HOST_ROLE` to `configserver`.
- Set the values for `hostname` and `domainname` to reflect your environment.
The resulting FQDN must resolve to the external address of the container.
- Start all services with `./opsi-server.sh start` / `.\opsi-server.ps1 start`.
- You can see the containers status using `./opsi-server.sh status` / `.\opsi-server.ps1 status`.
- The container logs are available via `./opsi-server.sh logs` / `.\opsi-server.ps1 logs`.

## Usage as opsi depot-server
- Adapt the docker-compose.yml to your needs regarding network and volumes.
- You won't need the services `mysql` and `grafana` for a depotserver, so you can remove them from the docker-compose.yml.
In this case you should also remove `mysql` from the `depends_on` attribute of the `opsiconfd` service.
- Set the variable `OPSI_HOST_ROLE` to `depotserver`.
- The variable `OPSI_SERVICE_ADDRESS` has to contain the address of your opsi configserver.
- `OPSI_HOST_KEY` has to contain the host key of the depot.
- Start all services with `./opsi-server.sh start` / `.\opsi-server.ps1 start`.

## TFTP netboot
- If TFTP netboot is not needed, you should disable opsipxeconfd and opsi-tftp-hpa
by setting the environment variable `OPSI_TFTPBOOT` to `"false"`.

# Next steps
- Open the address `https://<FQDN>:4447` in a browser.
- Login as `adminuser` with password `<OPSI_ADMIN_PASSWORD>` as set in the docker-compose.yml.
- Open the `Licensing`-Tab and upload your opsi license file.
- You can use the `Terminal`-Tab to get a terminal on your server.
- Continue reading https://docs.opsi.org/opsi-docs-de/4.2/getting-started/getting-started.html
