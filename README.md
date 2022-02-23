# Official opsi server image

This image can be used to set up an opsi config-server or an opsi depot-server.
The only supported depot protocol is WebDAV, there is no Samba server included in this image.

# How to use this image
The image is meant to be used with Docker Compose.
Minimum required Docker Compose version is 1.17.0 with Docker engine 17.09.0+.
There are four services defined in the docker-compose.yml:
- mysql: The latest official MariaDB Server
- redis: Latest official Redis Server from Redis Labs with RedisTimeSeries Module
- grafana: The latest official Grafana Server from Grafana Labs
- opsi-server: Contains the latest opsiconfd, opsipxeconfd, opsi-tftpd-hpa and opsi-utils from uib GmbH.

For security reasons you should change all passwords in this file:
`MYSQL_ROOT_PASSWORD`, `MYSQL_PASSWORD`, `REDIS_PASSWORD`, `GF_SECURITY_ADMIN_PASSWORD` and `OPSI_ADMIN_PASSWORD`.
The root account has no password set. If needed, it is possible to set the root password via `OPSI_ROOT_PASSWORD`.

## Usage as opsi config-server
- Adapt the docker-compose.yml to your needs regarding network and volumes.
- Set the variable `OPSI_HOST_ROLE` to `configserver`.
- Set the values for `hostname` and `domainname` to reflect your environment.
The resulting FQDN must resolve to the external address of the container.
- Set the `OPSICONFD_GRAFANA_EXTERNAL_URL` to point to the external address of your grafana container.
- Start all services with `docker-compose` (or in the background using `docker-compose -d`).

## Usage as opsi depot-server
- Adapt the docker-compose.yml to your needs regarding network and volumes.
- You won't need the services `mysql` and `grafana` for a depotserver, so you can remove them from the docker-compose.yml.
In this case you should also remove `mysql` from the `depends_on` attribute of the `opsiconfd` service.
- Set the variable `OPSI_HOST_ROLE` to `depotserver`.
- The variable `OPSI_SERVICE_ADDRESS` has to contain the address of your opsi configserver.
- `OPSI_HOST_KEY` has to contain the host key of the depot.
- Start all services with `docker-compose` (or in the background using `docker-compose -d`).

## TFTP netboot
- If TFTP netboot is not needed, you should disable opsipxeconfd and opsi-tftp-hpa
by setting the environment variable `OPSI_TFTPBOOT` to `"false"`.
