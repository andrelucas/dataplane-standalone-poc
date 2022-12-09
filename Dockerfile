# Docker image in which DPLL tests can be run.

FROM docker.io/soegarots/build-rocky8mp:20220923-0022
# Install an ssh server and some additional development tools.
RUN yum-config-manager --disable Artifactory && \
    yum -y install \
    bash-completion \
    gcc-toolset-11-libatomic-devel \
    gdb \
    lldb \
    openssh-server \
    sg3_utils \
    tcpdump \
    && \
    yum clean all
RUN systemctl enable sshd && \
    echo "root" | passwd --stdin root
RUN pip3 install junitparser

# Expose ssh, the supervisor gRPC, and directfs.
EXPOSE 22 5703 5704 25004

# Containers will run systemd as if they're VMs.
ENTRYPOINT [ "/usr/sbin/init" ]

# We'll use this to configure the linker.
ENV DP_DESTDIR /staging

# All the build and runtime scripts etc. are in tools/.
COPY tools/ /tools/

# This is a useful default, as the Makefile is here.
WORKDIR /tools

# Configuration that is independent of the tools, tests and libraries uploaded.
RUN make build-configure

# Configuration that depends on /staging contents.
RUN make staging-configure

