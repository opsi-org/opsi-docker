# Official opsi server image

This image can be used to set up a opsi config-server or a depot-server.
Depot share is WebDAV only, there is no Samba server included in this image.

# How to use this image
The image is meant to be used with Docker Compose.
Minimum required Docker Compose version is 1.17.0 with Docker engine 17.09.0+.
There are four services defined in the docker-compose.yml:
- mysql: The latest official MariaDB Server
- redis: Latest official Redis Server from Redis Labs with RedisTimeSeries Module
- grafana: The latest official Grafana Server from Grafana Labs
- opsiconfd: The latest stable opsiconfd and opsi-utils from uib GmbH

For security reasons you should change all passwords in this file:
`MYSQL_ROOT_PASSWORD`, `MYSQL_PASSWORD`, `REDIS_PASSWORD`, `GF_SECURITY_ADMIN_PASSWORD` and `OPSI_ADMIN_PASSWORD`.

## Usage as a opsi configserver
- Adapt the docker-compose.yml to your needs regarding network and volumes.
- Set the variable `OPSI_HOST_ROLE` to `configserver`.
- Set the values for `hostname` and `domainname` to reflect your environment.
The resulting FQDN must resolve in your environment to the external address of the container.
- Set the `OPSICONFD_GRAFANA_EXTERNAL_URL` to point to the external address of your grafana container.
- Start all service with `docker-compose` (or in the background using `docker-compose -d`).

## Usage as a opsi depotserver
- Adapt the docker-compose.yml to your needs regarding network and volumes.
- You won't need the services `mysql` and `grafana` for a depotserver, so you can remove them from the docker-compose.yml.
In this case you should also remove `mysql` from the `depends_on` attribute of the `opsiconfd` service.
- Set the variable `OPSI_HOST_ROLE` to `depotserver`.
- The variable `OPSI_SERVICE_ADDRESS` has to contain the address of your opsi configserver.
- `OPSI_HOST_KEY` has to contain the host key of the depot.
- Start all service with `docker-compose` (or in the background using `docker-compose -d`).
