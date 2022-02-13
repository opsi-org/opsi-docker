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
	for dir_to_move in "/etc/opsi:etc" "/var/lib/opsi:lib" "/var/log/opsi:log"; do
		src=${dir_to_move%:*}
		dst=${dir_to_move#*:}
		if [ ! -L "${src}" ]; then
			echo "Move ${src}" 1>&2
			if [ -e "/data/${dst}" ]; then
				rm -r "${src}"
				ln -s "/data/${dst}" "${src}"
			else
				mv "${src}" "/data/${dst}"
				ln -s "/data/${dst}" "${src}"
				opsi-set-rights "${src}"
			fi
		fi
	done
}


function setup_users {
	echo "* Setup users" 1>&2
	if getent passwd adminuser >/dev/null 2>&1; then
		echo "Modify adminuser" 1>&2
		usermod -u 1000 -d /data/adminuser -m -g opsiadmin -G opsifileadmins -s /usr/bin/zsh adminuser
	else
		echo "Create adminuser" 1>&2
		useradd -u 1000 -d /data/adminuser -m -g opsiadmin -G opsifileadmins -s /usr/bin/zsh adminuser || true
		cp -a /root/.zshrc /data/adminuser/
		chown adminuser:opsiadmin -R /data/adminuser/.zshrc
		cp -a /root/.oh-my-zsh /data/adminuser/
		chown -R adminuser:opsiadmin -R /data/adminuser/.oh-my-zsh
	fi
	echo "adminuser:${OPSI_ADMIN_PASSWORD}" | chpasswd
}


set_environment_vars
init_volumes

if [ "${OPSI_HOST_ROLE}" = "depotserver" ]; then
	backend_config_depotserver
	opsiconfd setup
else
	backend_config_configserver
	opsiconfd setup
	set_default_configs
fi

setup_users

echo "* Start opsiconfd" 1>&2
exec opsiconfd
