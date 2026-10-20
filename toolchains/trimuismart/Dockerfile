# Replaces the Dockerfile of github.com/shauninman/union-trimuismart-toolchain,
# built with that repo as the context. Same toolchain, but the sources are
# fetched first in a newer Debian: stretch's wget can no longer connect to
# buildroot.org (no TLS 1.3), so the upstream image fails before building.
# build.sh adds cacert.pem (Mozilla's current CA list) to support/.

# Buildroot plus every source it needs, downloaded with a TLS stack servers still accept
FROM debian:buster-slim AS sources
ENV DEBIAN_FRONTEND=noninteractive

RUN sed -i -e 's/deb.debian.org/archive.debian.org/g' \
		-e 's|security.debian.org|archive.debian.org|g' \
		-e '/buster-updates/d' /etc/apt/sources.list
RUN apt-get -o Acquire::Check-Valid-Until=false -y update && apt-get -y install \
	bc \
	build-essential \
	bzip2 \
	cpio \
	file \
	git \
	patch \
	perl \
	python \
	rsync \
	unzip \
	wget \
	xz-utils \
  && rm -rf /var/lib/apt/lists/*
RUN echo "ca_certificate = /root/cacert.pem" >> /etc/wgetrc

WORKDIR /root
COPY support .
RUN set -xe \
	&& wget -nv https://buildroot.org/downloads/buildroot-2016.05.tar.gz \
	&& tar -xf buildroot-2016.05.tar.gz \
	&& mv buildroot-2016.05 buildroot \
	&& cd buildroot \
	&& patch -p1 < ../libpng12.patch \
	&& patch -p1 < ../sdl_mixer.patch \
	&& cp ../trimuismart.config .config \
	&& make oldconfig \
	&& make source \
	&& rm -rf output

# from here on the same as upstream, building offline from dl/
FROM debian:stretch-slim
ENV DEBIAN_FRONTEND=noninteractive

ENV TZ=America/New_York
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN sed -i s/deb.debian.org/archive.debian.org/g /etc/apt/sources.list
RUN sed -i 's|security.debian.org|archive.debian.org|g' /etc/apt/sources.list
RUN sed -i '/stretch-updates/d' /etc/apt/sources.list
RUN apt-get -y update && apt-get -y install \
	bc \
	build-essential \
	bzip2 \
	bzr \
	cmake \
	cmake-curses-gui \
	cpio \
	git \
	libncurses5-dev \
	locales \
	make \
	rsync \
	scons \
	tree \
	unzip \
	wget \
  && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /root/workspace
WORKDIR /root

COPY support .
COPY --from=sources /root/buildroot ./buildroot
# build-toolchain.sh without its download and patch steps
RUN set -xe \
	&& sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
	&& locale-gen \
	&& cd buildroot \
	&& export FORCE_UNSAFE_CONFIGURE=1 \
	&& make oldconfig \
	&& make world \
	&& mkdir -p /opt/trimuismart-toolchain \
	&& cp -rf output/host/usr/ /opt/trimuismart-toolchain/ \
	&& cp ~/relocate-sdk.sh ~/sdk-location /opt/trimuismart-toolchain/ \
	&& /opt/trimuismart-toolchain/relocate-sdk.sh \
	&& cp ~/hwcap.h /opt/trimuismart-toolchain/usr/arm-buildroot-linux-gnueabihf/sysroot/usr/include/asm/ \
	&& rm -rf ~/buildroot
RUN cat ./setup-env.sh >> .bashrc

VOLUME /root/workspace
WORKDIR /root/workspace

CMD ["/bin/bash"]
