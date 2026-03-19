# https://hub.docker.com/_/centos for details on the first stage of this build
FROM almalinux:9 AS systemd-enabled
ENV container docker
RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == \
systemd-tmpfiles-setup.service ] || rm -f $i; done); \
rm -f /lib/systemd/system/multi-user.target.wants/*;\
rm -f /etc/systemd/system/*.wants/*;\
rm -f /lib/systemd/system/local-fs.target.wants/*; \
rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
rm -f /lib/systemd/system/basic.target.wants/*;\
rm -f /lib/systemd/system/anaconda.target.wants/*;
VOLUME [ "/sys/fs/cgroup" ]
CMD ["/usr/sbin/init"]

FROM systemd-enabled

# Install dependencies
# Install compilers for gems & more dependencies - this section is > 1 GB so might see if we can shrink it down some
# Should we remove git, since the mutagen files can't see the git directory?
# See https://mutagen.io/documentation/synchronization/version-control-systems
# devtoolset-8 installed due to newer mini_racer requirement of newer g++
# Also install ChromeDriver
# TODO: are we using httpd?
RUN dnf -y update \
&& dnf -y install epel-release \
&& dnf config-manager --set-enabled crb \
&& dnf -y install gcc gcc-c++ make git \
&& dnf -y install libyaml libyaml-devel libxml2-devel libxslt-devel zlib-devel \
# AlmaLinux 9 ships NodeJS 18 or 20. Ruby 3.2 not available in AlmaLinux 9, so using Ruby 3.3
&& dnf -y module enable ruby:3.3 nodejs:18 \
&& dnf -y install ruby ruby-devel \
&& dnf -y install https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-aarch64/pgdg-redhat-repo-latest.noarch.rpm \
&& dnf -qy module disable postgresql \
&& dnf install -y python3 python3-devel \
&& dnf -y install nodejs-devel npm \
&& dnf -y install postgresql14 postgresql14-devel postgresql14-libs libxslt-devel \
# Create symlinks for standard paths so bundler can find postgres config
&& ln -s /usr/pgsql-14 /usr/pgsql \
&& ln -s /usr/pgsql-14/bin/pg_config /usr/local/bin/pg_config \
# redhat-lsb-core was removed in RHEL 9 / AlmaLinux 9 and is no longer available
&& dnf -y install git libreoffice-core clamav-devel clamav clamav-update clamd libXScrnSaver wget unzip \
&& dnf -y install ghostscript GraphicsMagick \
&& dnf -y install chromium \
# Install libvips build dependencies (libvips is not packaged for aarch64 in EPEL 9)
&& dnf -y install glib2-devel expat-devel meson ninja-build \
&& dnf clean all && rm -rf /var/cache/yum \
&& wget -q -P /tmp "https://github.com/harvard-lts/fits/releases/download/1.5.5/fits-1.5.5.zip" \
&& mkdir /fits \
&& unzip /tmp/fits-1.5.5.zip -d /fits/fits-1.5.5 \
&& rm -f /tmp/fits-1.5.5.zip \
&& npm install yarn -g \
&& yarn \
&& dnf -y update ca-certificates

# Build libvips 8.15.x from source — provides libvips.so.42 required by the ruby-vips gem
RUN wget -q -O /tmp/vips.tar.xz "https://github.com/libvips/libvips/releases/download/v8.15.3/vips-8.15.3.tar.xz" \
&& tar xf /tmp/vips.tar.xz -C /tmp \
&& cd /tmp/vips-8.15.3 && meson setup build --prefix=/usr/local \
&& ninja -C build \
&& ninja -C build install \
&& echo "/usr/local/lib64" > /etc/ld.so.conf.d/local-lib64.conf \
&& ldconfig \
&& rm -rf /tmp/vips*

ENV PATH "/fits:$PATH"
COPY docker/fits.xml /fits/fits-1.5.5/xml/fits.xml
COPY docker/start-app.sh /hyrax/docker/start-app.sh

# Install gems
COPY Gemfile* /hyrax/
WORKDIR /hyrax

ENV BUNDLER_ALLOW_ROOT=1
RUN gem install rubygems-update \
&& update_rubygems \
&& gem update --system

# Create FTP directories
RUN mkdir -p /opt/data/ftp/proquest && mkdir -p /opt/data/ftp/sage

EXPOSE 3000
CMD ["sh", "/hyrax/docker/start-app.sh"]
