FROM centos:7
MAINTAINER Alberto Rodriguez <arodriguez@redborder.com>

RUN yum install -y epel-release which && rpm -ivh http://repo.redborder.com/redborder-repo-0.0.3-1.el7.rb.noarch.rpm && yum clean all
RUN yum install -y redborder-serf && yum clean all
ADD entrypoint.sh /

CMD /entrypoint.sh



