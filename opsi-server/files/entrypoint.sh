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


function set_timezone {
	ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime
	echo "${TZ}" > /etc/timezone
}


function set_host_id {
	cur_id=$(grep "^id *=" /etc/opsi/opsi.conf | cut -d '"' -f2)
	new_id=$cur_id
	if [ -n $OPSI_HOST_ID ]; then
		new_id=$OPSI_HOST_ID
	elif [ -n $OPSI_HOSTNAME ]; then
		new_id=$OPSI_HOSTNAME
	fi
	if [ "${new_id}" != "${cur_id}" ]; then
		sed -i -e "s/^id = \"[^\"]*\"/id = \"$new_id\"/" /etc/opsi/opsi.conf
		if [ "${OPSI_HOST_ROLE}" = "configserver" ]; then
			echo "* Rename server ${cur_id} => ${new_id}" 1>&2
			/usr/bin/opsiconfd setup --rename-server
		fi
	fi
}


function backend_config_tftpboot {
	if [[ "${OPSI_TFTPBOOT}" =~ ^(true|yes|y|1)$ ]]; then
		sed -i 's/"enabled".*/"enabled": True,/' /etc/opsi/backends/opsipxeconfd.conf
	else
		sed -i 's/"enabled".*/"enabled": False,/' /etc/opsi/backends/opsipxeconfd.conf
	fi
}


function backend_config_configserver {
	echo "* Configure backend for configserver" 1>&2

	sed -i 's/^server-role .*/server-role = "configserver"/' /etc/opsi/opsi.conf

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
}


function backend_config_depotserver {
	echo "* Configure backend for depotserver" 1>&2

	sed -i 's/^server-role .*/server-role = "depotserver"/' /etc/opsi/opsi.conf

	cat > /etc/opsi/backends/jsonrpc.conf <<EOF
# -*- coding: utf-8 -*-

module = 'JSONRPC'
config = {
	"address": "${OPSI_SERVICE_ADDRESS}",
	"username": "${OPSI_HOST_ID}",
	"password": "${OPSI_HOST_KEY}"
}
EOF
}


function init_volumes {
	echo "* Init volumes" 1>&2
	set return_val=0
	for dir_to_move in "/etc/opsi:etc" "/var/lib/opsi:lib" "/var/log/opsi:log" "/tftpboot:tftpboot" "/var/lib/opsiconfd:opsiconfd"; do
		src=${dir_to_move%:*}
		dst=${dir_to_move#*:}
		dst="/data/${dst}"
		if [ ! -L "${src}" ]; then
			echo "Move ${src}" 1>&2
			set return_val=1
			if [ -d "${src}" ]; then
				# Moving sub directories to allow mounts below dst
				[ -e "${dst}" ] || mkdir "${dst}"
				for entry in "${src}"/*; do
					name=$(basename $entry)
					if [ ! -e "${dst}/${name}" ]; then
						mv $entry "${dst}/${name}"
					fi
				done
			fi
			rm --one-file-system -r "${src}"
			ln -s "${dst}" "${src}"
			chown opsiconfd:opsiadmin "${dst}"
			chmod 770 "${dst}"
		fi
	done
	chmod -R o+rX /data/tftpboot
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
		passwd --lock root
	else
		echo "root:${OPSI_ROOT_PASSWORD}" | chpasswd
	fi
}


function configure_supervisord {
	echo "* Configure supervisord" 1>&2

	autostart_opsipxeconfd="false"
	autostart_tftpd="false"
	if [[ "${OPSI_TFTPBOOT}" =~ ^(true|yes|y|1)$ ]]; then
		autostart_opsipxeconfd="true"
		autostart_tftpd="true"
	fi
	cat > /etc/supervisor/supervisord.conf <<EOF
[supervisord]
nodaemon=true
user=root
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid
childlogdir=/var/log/supervisor

[unix_http_server]
file=/var/run/supervisor.sock

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///var/run/supervisor.sock

[program:opsiconfd]
command=/usr/bin/opsiconfd ${OPSICONFD_ARGS}
autostart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:opsipxeconfd]
command=/usr/bin/opsipxeconfd ${OPSIPXECONFD_ARGS}
autostart=${autostart_opsipxeconfd}
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:tftpd]
command=/usr/sbin/in.tftpd ${TFTPD_ARGS}
autostart=${autostart_tftpd}
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
EOF

	mkdir -p /var/run/opsipxeconfd
}


function wait_for_mysql {
	echo "* Waiting for MySQL" 1>&2
	while ! nc -v -z -w3 $MYSQL_HOST 3306 >/dev/null 2>&1; do
		sleep 1
	done
}


function wait_for_redis {
	echo "* Waiting for Redis" 1>&2
	while ! nc -v -z -w3 $REDIS_HOST 6379 >/dev/null 2>&1; do
		sleep 1
	done
}

function fetch_license_file {
	if [ -n "$OPSILICSRV_URL" -a -n "$OPSILICSRV_TOKEN" ]; then
		echo "* Downloading license file" 1>&2
		mkdir -p /etc/opsi/licenses
		wget --header="Authorization: Bearer ${OPSILICSRV_TOKEN}" "${OPSILICSRV_URL}/test?usage=opsi-docker-test" -O /etc/opsi/licenses/test.opsilic
	fi
}

function handle_backup {
	if [ -n "$OPSICONFD_RESTORE_BACKUP_URL" ]; then
		if [ -e /etc/opsi/docker_start_backup_restored ]; then
			echo "* OPSICONFD_RESTORE_BACKUP_URL is set, but marker /etc/opsi/docker_start_backup_restored found - skipping restore."
		else
			echo "* Getting backup from $OPSICONFD_RESTORE_BACKUP_URL and restoring."
			wget -q $OPSICONFD_RESTORE_BACKUP_URL -O /tmp/backupfile
			archive=$(tar -xvf /tmp/backupfile -C /tmp)
			opsiconfd --log-level-stderr=5 restore --server-id="local" "/tmp/${archive}"
			rm -f /tmp/backupfile "/tmp/$archive"
			touch /etc/opsi/docker_start_backup_restored
		fi
	fi
}

function entrypoint {
	set_environment_vars
	set_timezone
	set_host_id
	wait_for_redis
	if [ "${OPSI_HOST_ROLE}" = "configserver" ]; then
		wait_for_mysql
	fi

	set run_set_rights=false
	init_volumes || run_set_rights=true

	backend_config_tftpboot
	if [ "${OPSI_HOST_ROLE}" = "depotserver" ]; then
		backend_config_depotserver
		opsiconfd setup --log-level-stderr 6
	else
		backend_config_configserver
		opsiconfd setup --log-level-stderr 6
	fi

	setup_users
	configure_supervisord

	if $run_set_rights; then
		echo "* Run opsi-set-rights" 1>&2
		opsi-set-rights
	fi

	fetch_license_file
	handle_backup

	echo "* Start supervisord" 1>&2
	exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
}

if [ "$#" -gt "0" ]; then
	for function in "$@"; do
		$function
	done
else
	entrypoint
fi
