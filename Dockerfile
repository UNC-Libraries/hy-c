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
RUN yum -y install httpd; yum clean all; systemctl enable httpd.service; \
yum -y install centos-release-scl-rh centos-release-scl; \
yum -y --enablerepo=centos-sclo-rh install rh-ruby26 rh-ruby26-ruby-devel

RUN scl enable rh-ruby26 -- gem install bundler -v '~> 2.2.28'; \
# Install compilers for gems
yum -y install gcc gcc-c++ zlib-devel postgresql-devel libxslt-devel

EXPOSE 3000
CMD ["/usr/sbin/init"]
