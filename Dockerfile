# https://hub.docker.com/_/centos for details on the first stage of this build
FROM almalinux:8 AS systemd-enabled
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
&& dnf config-manager --set-enabled powertools \
&& dnf -y install gcc gcc-c++ make git \
&& dnf -y install libyaml libyaml-devel libxml2-devel libxslt-devel zlib-devel \
&& dnf -y install libsass libsass-devel \
&& dnf -y module enable ruby:3.0 nodejs:14 \
&& dnf -y install ruby ruby-devel \
&& dnf -y install https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-aarch64/pgdg-redhat-repo-latest.noarch.rpm \
&& dnf -qy module disable postgresql \
&& dnf install -y python3 python3-devel \
&& dnf -y install nodejs-devel npm \
&& dnf -y install postgresql14 postgresql14-devel postgresql14-libs libxslt-devel \
# Create symlinks for standard paths so bundler can find postgres config
&& ln -s /usr/pgsql-14 /usr/pgsql \
&& ln -s /usr/pgsql-14/bin/pg_config /usr/local/bin/pg_config \
&& dnf -y install git libreoffice-core clamav-devel clamav clamav-update clamd redhat-lsb-core libXScrnSaver wget unzip \
&& dnf -y install ghostscript GraphicsMagick \
&& dnf -y install chromium \
&& dnf clean all && rm -rf /var/cache/yum \
&& wget -q -P /tmp "https://github.com/harvard-lts/fits/releases/download/1.5.5/fits-1.5.5.zip" \
&& mkdir /fits \
&& unzip /tmp/fits-1.5.5.zip -d /fits/fits-1.5.5 \
&& rm -f /tmp/fits-1.5.5.zip \
&& npm install yarn -g \
&& yarn \
&& dnf -y update ca-certificates

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
