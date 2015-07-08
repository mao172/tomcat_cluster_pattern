FROM <%= @image %>

ENV LANG=en_US.UTF-8
<% if @http_proxy %>
ENV http_proxy <%= @http_proxy %>
<% end %>
<% if @https_proxy %>
ENV https_proxy <%= @https_proxy %>
<% end %>

<% if @http_proxy %>
RUN echo "proxy=<%= @http_proxy %>" >> /etc/yum.conf
<% end %>

## for test-kitchen + kitchen-docker
#
RUN yum clean all
RUN yum install -y sudo openssh-server openssh-clients which curl htop

RUN ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key
RUN ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key
RUN mkdir -p /var/run/sshd

RUN useradd -d /home/<%= @username %> -m -s /bin/bash <%= @username %>
RUN echo <%= "#{@username}:#{@password}" %> | chpasswd
RUN echo '<%= @username %> ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

## configuration for curl command
#
<% if @http_proxy %>
RUN echo 'proxy = "<%= @http_proxy %>"' >> /root/.curlrc
RUN echo 'noproxy=127.0.0.1,localhost' >> /root/.curlrc
<% end %>

## for cloudconductor bootstrap setup
#

WORKDIR /opt/cloudconductor

RUN echo 'PATTERN_NAME="<%= @cc_pattern %>"' >> ./config
RUN echo 'PATTERN_URL="https://github.com/cloudconductor-patterns/<%= @cc_pattern %>.git"' >> ./config
RUN echo 'PATTERN_REVISION="develop"' >> ./config
RUN echo "ROLE='<%= @cc_role %>'" >> ./config
RUN echo "CONSUL_SECRET_KEY='<%= @cc_token %>'" >> ./config

RUN bash -x /tmp/bootstrap/setup.sh
