#!/bin/sh

[ -d /run/sshd ] || mkdir /run/sshd
[ -d /var/log/opsi-client-agent ] || mkdir -p /var/log/opsi-client-agent
[ -e ssh_host_ecdsa_key ] || dpkg-reconfigure openssh-server
[ -e /etc/xrdp/rsakeys.ini ] || xrdp-keygen xrdp auto


opsi_ip=$(getent hosts opsi-server | cut -d' ' -f1)
if [ -n $opsi_ip ]; then
	domain=$(hostname -d)
	grep -v " opsi-server\\." /etc/hosts > /tmp/hosts
	echo "${opsi_ip}   opsi-server.${domain} opsi.${domain} opsi-server opsi" >> /tmp/hosts
	cat /tmp/hosts > /etc/hosts
	rm /tmp/hosts

	if wget --no-check-certificate -q "https://opsi.${domain}:4447/ssl/opsi-ca-cert.pem" -O /usr/local/share/ca-certificates/opsi_CA.crt; then
		update-ca-certificates
		for cert_db in $(find /home/*/.mozilla -name "cert*.db"); do
			cert_dir="$(dirname ${cert_db})"
			certutil -A -n "opsi CA" -t "TCu,Cuw,Tuw" -i /usr/local/share/ca-certificates/opsi_CA.crt -d "${cert_dir}"
		done
	fi
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

[program:sshd]
command=/usr/sbin/sshd -D
autostart=true
autorestart=true
user=root
priority=400
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:xrdp-sesman]
command=/usr/sbin/xrdp-sesman --nodaemon
autostart=true
autorestart=true
user=root
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:xrdp]
command=/usr/sbin/xrdp --nodaemon
autostart=true
autorestart=true
user=root
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:opsiclientd]
command=/usr/bin/opsiclientd
autostart=true
autorestart=true
user=root
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
EOF

exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
