# https://hub.docker.com/_/centos for details on the first stage of this build
FROM centos:7 AS systemd-enabled
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

COPY docker/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo

# Install dependencies
# Install compilers for gems & more dependencies - this section is > 1 GB so might see if we can shrink it down some
# Should we remove git, since the mutagen files can't see the git directory?
# See https://mutagen.io/documentation/synchronization/version-control-systems
# devtoolset-8 installed due to newer mini_racer requirement of newer g++
# Also install ChromeDriver
# TODO: are we using httpd?
RUN yum -y update \
&& yum -y install epel-release \
&& yum -y install centos-release-scl-rh centos-release-scl \
&& yum -y install libyaml libyaml-devel \
&& yum -y --enablerepo=centos-sclo-rh install rh-ruby30 rh-ruby30-ruby-devel \
&& yum -y install https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm \
&& yum -y install gcc gcc-c++ zlib-devel devtoolset-8 postgresql14 libpq5-devel libxslt-devel \
&& yum -y install git libreoffice clamav-devel clamav clamav-update clamd redhat-lsb libXScrnSaver wget unzip \
&& yum -y install ghostscript GraphicsMagick \
&& yum -y install chromium \
&& yum -y install rh-nodejs14 \
&& yum install -y python3 \
&& yum clean all && rm -rf /var/cache/yum \
&& wget -q -P /tmp "https://github.com/harvard-lts/fits/releases/download/1.5.5/fits-1.5.5.zip" \
&& mkdir /fits \
&& unzip /tmp/fits-1.5.5.zip -d /fits/fits-1.5.5 \
&& rm -f /tmp/fits-1.5.5.zip \
&& echo "source scl_source enable devtoolset-8" >> /etc/bashrc \
&& echo "source scl_source enable rh-ruby30" >> /etc/bashrc \
&& scl enable rh-nodejs14 -- npm install yarn -g \
&& scl enable rh-nodejs14 -- yarn \
&& yum -y update ca-certificates

ENV PATH "/fits:$PATH"
COPY docker/fits.xml /fits/fits-1.5.5/xml/fits.xml
COPY docker/start-app.sh /hyrax/docker/start-app.sh

# Install gems
COPY Gemfile* /hyrax/
WORKDIR /hyrax

ENV BUNDLER_ALLOW_ROOT=1
RUN scl enable devtoolset-8 rh-ruby30 -- gem install rubygems-update \
&& scl enable devtoolset-8 rh-ruby30 -- update_rubygems \
&& scl enable devtoolset-8 rh-ruby30 -- gem update --system

# Create FTP directories
RUN mkdir -p /opt/data/ftp/proquest && mkdir -p /opt/data/ftp/sage

EXPOSE 3000
CMD ["sh", "/hyrax/docker/start-app.sh"]
