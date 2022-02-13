ARG DEBIAN_VERSION=11

FROM debian:${DEBIAN_VERSION}

LABEL maintainer="uib GmbH <info@uib.de>"

ARG DEBIAN_VERSION=11
ARG OPSI_VERSION=4.2
ARG OPSI_BRANCH=development

ENV OPSI_REPO=https://download.opensuse.org/repositories/home:/uibmz:/opsi:/${OPSI_VERSION}:/${OPSI_BRANCH}/Debian_${DEBIAN_VERSION}/
ENV OPSI_SERVICE_ADDRESS=
ENV OPSI_HOST_ID=
ENV OPSI_HOST_KEY=
ENV OPSI_HOST_ROLE=configserver
ENV OPSI_ADMIN_PASSWORD=opsi
ENV MYSQL_ADDRESS=mysql
ENV MYSQL_DATABASE=opsi
ENV MYSQL_USER=opsi
ENV MYSQL_PASSWORD=opsi

RUN apt-get update && \
	apt-get --yes dist-upgrade && \
	apt-get --yes install \
		apt-transport-https \
		gnupg \
		wget \
		zsh \
		psmisc \
		iproute2 \
		locales \
		vim \
		git

RUN sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
	locale-gen

ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en

RUN echo "deb [signed-by=/usr/local/share/keyrings/opsi-obs.gpg] ${OPSI_REPO} /" > /etc/apt/sources.list.d/opsi.list && \
	mkdir /usr/local/share/keyrings && \
	chmod 755 /usr/local/share/keyrings && \
	wget -nv ${OPSI_REPO}Release.key -q -O- | gpg --dearmor > /usr/local/share/keyrings/opsi-obs.gpg && \
	apt-get --yes update && \
	OPSI_HOST_ID="opsiconfd.opsi.org" apt-get --yes install opsi-server-expert

COPY files/ /
RUN mkdir /data && \
	chmod +x /entrypoint.sh && \
	sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" && \
	git clone https://github.com/zsh-users/zsh-autosuggestions /root/.oh-my-zsh/custom/plugins/zsh-autosuggestions && \
	sed -i '1i export TERM=xterm-256color' /root/.zshrc && \
	sed -i s'/^plugins.*/plugins=(git zsh-autosuggestions history)/' /root/.zshrc && \
	usermod -s /usr/bin/zsh root

RUN	apt-get clean && \
	rm /tmp/* && \
	rm /etc/opsi/ssl/* && \
	rm -rf /var/lib/apt/lists/*

VOLUME /data

EXPOSE 4447

ENTRYPOINT /entrypoint.sh
