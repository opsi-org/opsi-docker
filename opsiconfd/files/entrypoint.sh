#!/usr/bin/env zsh

function set_environment_vars {
	echo "* Set environment vars" 1>&2
	if [ -z $OPSICONFD_REDIS_INTERNAL_URL ]; then
		if [ -z $REDIS_PASSWORD ]; then
			export OPSICONFD_REDIS_INTERNAL_URL=redis://${REDIS_HOST};
		else
			export OPSICONFD_REDIS_INTERNAL_URL=redis://default:${REDIS_PASSWORD}@${REDIS_HOST}
		fi
	fi
	if [ -z $OPSICONFD_GRAFANA_INTERNAL_URL ]; then
		if [ -z $GF_SECURITY_ADMIN_PASSWORD ]; then
			export OPSICONFD_GRAFANA_INTERNAL_URL=http://${GRAFANA_HOST}:3000
		else
			export OPSICONFD_GRAFANA_INTERNAL_URL=http://${GF_SECURITY_ADMIN_USER}:${GF_SECURITY_ADMIN_PASSWORD}@${GRAFANA_HOST}:3000
		fi
	fi
}


function backend_config_configserver {
	echo "* Configure backend for configserver" 1>&2
	cat > /etc/opsi/backends/mysql.conf <<EOF
# -*- coding: utf-8 -*-

module = 'MySQL'
config = {
	"address": "${MYSQL_HOST}",
	"database": "${MYSQL_DATABASE}",
	"username": "${MYSQL_USER}",
	"password": "${MYSQL_PASSWORD}"
}
EOF
	echo ".*: mysql" > /etc/opsi/backendManager/dispatch.conf
}


function backend_config_depotserver {
	echo "* Configure backend for depotserver" 1>&2
	cat > /etc/opsi/backends/jsonrpc.conf <<EOF
# -*- coding: utf-8 -*-

module = 'JSONRPC'
config = {
	"address": "${OPSI_SERVICE_ADDRESS}",
	"username": "${OPSI_HOST_ID}",
	"password": "${OPSI_HOST_KEY}"

EOF
	echo ".*: jsonrpc" > /etc/opsi/backendManager/dispatch.conf
}


function set_default_configs {
	echo "* Set default configs" 1>&2
	opsi-admin -dS method config_createBool opsiclientd.global.verify_server_cert "Verify opsi server certificates" true
	opsi-admin -dS method config_createBool opsiclientd.global.install_opsi_ca_into_os_store "Install opsi CA into os certificate store" true
	opsi-admin -dS method config_createUnicode clientconfig.depot.protocol "Protocol for depot access" '["cifs","webdav"]' '["webdav"]'
	opsi-admin -dS method config_createUnicode clientconfig.depot.protocol.netboot "Protocol for depot access in bootimage" '["cifs","webdav"]' '["webdav"]'
}


function init_volumes {
	echo "* Init volumes" 1>&2
	set return_val=0
	for dir_to_move in "/etc/opsi:etc" "/var/lib/opsi:lib" "/var/log/opsi:log" "/tftpboot:tftpboot"; do
		src=${dir_to_move%:*}
		dst=${dir_to_move#*:}
		dst="/data/${dst}"
		if [ ! -L "${src}" ]; then
			echo "Move ${src}" 1>&2
			set return_val=1
			if [ -e "${dst}" ]; then
				rm -r "${src}"
				ln -s "${dst}" "${src}"
			else
				mv "${src}" "${dst}"
				ln -s "${dst}" "${src}"
				chown opsiconfd:opsiadmin "${dst}"
				chmod 770 "${dst}"
			fi
		fi
	done
	return $return_val
}


function setup_users {
	echo "* Setup users" 1>&2
	if ! getent passwd adminuser >/dev/null 2>&1; then
		echo "Create adminuser" 1>&2
		useradd -u 1000 -d /data/adminuser -m -g opsiadmin -G opsifileadmins -s /usr/bin/zsh adminuser || true
		cp -a /root/.zshrc /data/adminuser/
		chown adminuser:opsiadmin -R /data/adminuser/.zshrc
		cp -a /root/.oh-my-zsh /data/adminuser/
		chown -R adminuser:opsiadmin -R /data/adminuser/.oh-my-zsh
	fi
	echo "adminuser:${OPSI_ADMIN_PASSWORD}" | chpasswd

	if [ -z $OPSI_ROOT_PASSWORD ]; then
		passwd --delete root
	else
		echo "root:${OPSI_ROOT_PASSWORD}" | chpasswd
	fi
}


function configure_supervisord() {
	echo "* Configure supervisord" 1>&2

	autostart_opsipxeconfd="false"
	autostart_tftpd="false"
	if [[ "${OPSI_TFTPBOOT}" =~ ^(true|yes|y|1)$ ]]; then
		autostart_opsipxeconfd="true"
		autostart_tftpd="true"
	fi
	cat > /etc/supervisor/conf.d/supervisord.conf <<EOF
[supervisord]
nodaemon=true
user=root

[program:opsiconfd]
command=/usr/bin/opsiconfd ${OPSICONFD_ARGS}
autostart=true

[program:opsipxeconfd]
command=/usr/bin/opsipxeconfd ${OPSIPXECONFD_ARGS}
autostart=${autostart_opsipxeconfd}

[program:tftpd]
command=/usr/sbin/in.tftpd ${TFTPD_ARGS}
autostart=${autostart_tftpd}
EOF

	mkdir -p /var/run/opsipxeconfd
}


function wait_for_mysql() {
	echo "* Waiting for MySQL" 1>&2
	while ! nc -v -z -w3 $MYSQL_HOST 3306 >/dev/null 2>&1; do
		sleep 1
	done
}


function wait_for_redis() {
	echo "* Waiting for Redis" 1>&2
	while ! nc -v -z -w3 $REDIS_HOST 6379 >/dev/null 2>&1; do
		sleep 1
	done
}


set_environment_vars
wait_for_redis
if [ "${OPSI_HOST_ROLE}" = "configserver" ]; then
	wait_for_mysql
fi

set run_set_rights=false
init_volumes || run_set_rights=true

if [ "${OPSI_HOST_ROLE}" = "depotserver" ]; then
	backend_config_depotserver
	opsiconfd setup
else
	backend_config_configserver
	opsiconfd setup
	set_default_configs
fi

setup_users
configure_supervisord

if $run_set_rights; then
	echo "* Run opsi-set-rights" 1>&2
	opsi-set-rights
fi

echo "* Start supervisord" 1>&2
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
