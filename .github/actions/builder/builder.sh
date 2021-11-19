#!/bin/bash
set -x
set -eu
set -o pipefail

docker build -t tmp - <<'EOF'
FROM debian:11-slim as builder
RUN sed -i -re 's#http://deb.debian.org/#http://ftp.jp.debian.org/#g' /etc/apt/sources.list \
    && apt-get update && apt-get install -y --no-install-recommends git make gcc libc-dev ca-certificates \
    && git clone https://github.com/ncopa/su-exec.git /su-exec && cd /su-exec && make CC=gcc CFLAGS="-O -g -Wall -Werror" \
    && cp -p /su-exec/su-exec /usr/local/bin/su-exec

FROM debian:11-slim
COPY --from=builder /su-exec/su-exec /usr/local/bin/su-exec
RUN dpkg --clear-selections \
    && echo "apt install" | dpkg --set-selections \
    && echo "tzdata install" | dpkg --set-selections \
    && SUDO_FORCE_REMOVE=yes DEBIAN_FRONTEND=noninteractive apt-get --purge -y --allow-remove-essential dselect-upgrade \
    && SUDO_FORCE_REMOVE=yes DEBIAN_FRONTEND=noninteractive apt-get --purge -y --allow-remove-essential autoremove \
    && dpkg-query -Wf '${db:Status-Abbrev}\t${binary:Package}\n' | grep -E '^?i' | awk -F'\t' '{print $2 " install"}' | dpkg --set-selections \
    && sed -i -re 's#http://deb.debian.org/#http://ftp.jp.debian.org/#g' /etc/apt/sources.list \
    && apt-get update && apt-get install -y tini \
    && ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime

RUN find /usr/share/doc \( -name 'copyright' -o -name 'changelog.Debian.*' \) -print | tar cf /keep.tar -T - \
    && rm -rf /usr/share/man/* /usr/share/locale/*/LC_MESSAGES/*.mo /usr/share/doc /var/lib/apt/lists/*debian* /var/cache/apt/*.bin \
    && tar xf /keep.tar -C / \
    && rm /keep.tar

ADD https://raw.githubusercontent.com/oggfogg/entrypoint/main/entrypoint.sh /
RUN chmod +x /entrypoint.sh
EOF

docker run --rm -i tmp tar zpc --exclude=/etc/hostname --exclude=/etc/resolv.conf --exclude=/etc/hosts --one-file-system / >rootfs.tar.gz

docker run --rm -i tmp uname -a
