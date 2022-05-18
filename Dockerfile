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

# Install dependencies
# Install compilers for gems & more dependencies - this section is > 1 GB so might see if we can shrink it down some
# Should we remove git, since the mutagen files can't see the git directory?
# See https://mutagen.io/documentation/synchronization/version-control-systems
# devtoolset-8 installed due to mini_racer requirement of newer g++
# TODO: are we using httpd?
RUN yum -y update  && yum -y install httpd && yum clean all && systemctl enable httpd.service \
&& yum -y install centos-release-scl-rh centos-release-scl \
&& yum -y --enablerepo=centos-sclo-rh install rh-ruby27 rh-ruby27-ruby-devel \
&& yum -y install gcc gcc-c++ zlib-devel postgresql-devel libxslt-devel \
git libreoffice clamav-devel clamav clamav-update clamd redhat-lsb libXScrnSaver wget unzip \
epel-release ghostscript GraphicsMagick devtoolset-8

RUN echo "source scl_source enable devtoolset-8" >> /etc/bashrc \
&& echo "source scl_source enable rh-ruby27" >> /etc/bashrc

# Download and install Chromedriver
RUN wget -q -P /tmp "https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm" \
&& yum -y localinstall /tmp/google-chrome-stable_current_x86_64.rpm

# Install fits
WORKDIR /fits
ADD https://projects.iq.harvard.edu/files/fits/files/fits-1.0.5.zip /fits/
ENV PATH "/fits:$PATH"

#RUN scl enable devtoolset-8 rh-ruby27 -- gem update --system \
RUN scl enable devtoolset-8 rh-ruby27 -- gem install bundler \
&& yum install -y python3 \
&& unzip fits-1.0.5.zip -d /fits \
&& rm -rf fits-1.0.5.zip

#&& scl enable devtoolset-8 rh-ruby27 -- gem install nokogiri --platform=ruby \
#RUN scl enable devtoolset-8 rh-ruby27 -- gem install libv8 -- --with-system-v8

# Install gems
WORKDIR /hyrax
COPY Gemfile* /hyrax/
RUN scl enable devtoolset-8 rh-ruby27 -- bundle install

EXPOSE 3000
CMD ["sh", "/hyrax/docker/start-app.sh"]
