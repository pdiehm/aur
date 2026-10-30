FROM archlinux:base-devel

RUN pacman --noconfirm --sync --refresh --sysupgrade
COPY main.sh /main.sh

RUN useradd --uid 1001 runner
RUN echo "runner ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers
USER runner

ENTRYPOINT ["/usr/bin/bash", "/main.sh"]
