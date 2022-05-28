FROM debian:bullseye

LABEL maintainer="uib GmbH <info@uib.de>"

ENV TZ="Europe/Berlin"
ENV LC_ALL="en_US.UTF-8"
ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US:en"

ARG DEBIAN_FRONTEND="noninteractive"

RUN apt-get update \
	&& apt-get --yes update \
	&& apt-get --yes dist-upgrade \
	&& apt-get --yes install --no-install-recommends \
		apt-transport-https \
		gnupg \
		wget \
		curl \
		psmisc \
		iproute2 \
		locales \
		vim \
		nano \
		git \
		bzip2 \
		sudo \
		procps \
		netcat \
		libnss3-tools \
		iputils-ping \
		ca-certificates \
		xfce4 \
		xfce4-terminal \
		mousepad \
		xorgxrdp \
		xrdp \
		davfs2 \
		dbus-x11 \
		openssh-server \
		supervisor \
		openssh-client \
		firefox-esr \
		lshw \
		dmidecode \
		pciutils \
		usbutils \
		lsb-release \
		cifs-utils \
		xterm \
		dnsutils \
		lsof \
		openssl \
		pkg-config \
		desktop-file-utils \
		libnotify-bin \
		libgtk2.0-0 \
		psmisc \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

RUN	sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
	&& locale-gen \
	&& ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime && echo "${TZ}" > /etc/timezone \
	&& adduser xrdp ssl-cert \
	&& useradd -m adminuser -p $(openssl passwd adminuser) -s /bin/bash -G sudo \
	&& cp /etc/X11/xrdp/xorg.conf /etc/X11 \
	&& sed -i "s#xrdp/xorg#xorg#g" /etc/xrdp/sesman.ini \
	&& rm -f /etc/ssh/ssh_host_* \
	&& rm -rf /etc/xrdp/rsakeys.ini

COPY files/ /

VOLUME /home

EXPOSE 22 3389

CMD /entrypoint.sh
