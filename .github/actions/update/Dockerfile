FROM archlinux:base-devel

RUN pacman --noconfirm --sync --refresh --sysupgrade git devtools nvchecker
RUN sed -i "s/return 1/return 0/" /usr/share/devtools/lib/util/term.sh
COPY main.sh /main.sh

RUN useradd --uid 1001 runner
RUN echo "runner ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers
USER runner

ENTRYPOINT ["/usr/bin/bash", "/main.sh"]
