# CUBRID image for NCA testing. CI only. Not a release.
#
# The engine plus the CUBRID Manager Server, which is what NCA talks to.
# The package comes from ftp.cubrid.org/cubrid_dev/NCA_Nightly/, which ships a
# single tarball and no hash.md5, so there is nothing to verify the download
# against. The pipeline records the file's size and md5 instead.
#   docker build -t <image> --build-arg BUILD_ID=<id> --build-arg ENGINE_SHA=<sha> .

FROM rockylinux/rockylinux:8.10@sha256:e8a49c5403b687db05d4d67333fa45808fbe74f36e683cec7abb1f7d0f2338c6 AS extract
ADD dist/CUBRID-*.tar.gz /extract/

FROM rockylinux/rockylinux:8.10@sha256:e8a49c5403b687db05d4d67333fa45808fbe74f36e683cec7abb1f7d0f2338c6

ARG BUILD_ID
ARG ENGINE_SHA
LABEL org.opencontainers.image.title="CUBRID for NCA testing (CI only)" \
      org.opencontainers.image.description="Not a release. Not supported. Carries the manager server." \
      org.opencontainers.image.version="${BUILD_ID}" \
      org.opencontainers.image.revision="${ENGINE_SHA}" \
      org.opencontainers.image.source="https://github.com/CUBRID/cubrid" \
      org.cubrid.nightly.build_id="${BUILD_ID}"

ENV GOSU_VERSION="1.19" \
    CUBRID_USER_PATH="/home/cubrid" \
    CUBRID="/home/cubrid/CUBRID" \
    CUBRID_DATABASES="/home/cubrid/CUBRID/databases" \
    CUBRID_BACKUPDB="/home/cubrid/CUBRID/backupdb" \
    CUBRID_DB="cubdb" \
    CUBRID_VOLUME_SIZE="100M" \
    CUBRID_LOCALE="en_US" \
    CUBRID_COMPONENTS="NCA" \
    PATH="/home/cubrid/CUBRID/bin:$PATH" \
    LD_LIBRARY_PATH="/home/cubrid/CUBRID/lib"

# No epel-release: every package below is in the Rocky base repos. The release
# image needs epel for its diagnostic tools, which this image does not install,
# and reaching for it made the build fail on an epel mirror having a bad day.
RUN dnf -y install --setopt=tsflags=nodocs --setopt=install_weak_deps=False \
        wget tar gzip shadow-utils glibc-langpack-en && \
    dnf clean all && rm -rf /var/cache/dnf /tmp/* /var/tmp/*

RUN groupadd -r -g 1000 cubrid && \
    useradd -r -u 1000 -g cubrid -d /home/cubrid -m cubrid && \
    chmod 777 -R /tmp

RUN wget -q -O /usr/bin/gosu \
      "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64" && \
    chmod +x /usr/bin/gosu && gosu nobody true

# ADD --chown does not apply to auto-extracted tar contents: the archive's uid 0
# survives, leaving the tree root:root so cubrid cannot write log/ or var/ and
# the broker and PL server fail to start. COPY --from does apply --chown, in a
# single layer, and keeps the 281MB archive out of the final image.
COPY --from=extract --chown=cubrid:cubrid /extract/CUBRID /home/cubrid/CUBRID
RUN mkdir -p ${CUBRID_DATABASES} ${CUBRID_BACKUPDB} && \
    chown cubrid:cubrid ${CUBRID_DATABASES} ${CUBRID_BACKUPDB}

COPY docker-entrypoint.sh /home/cubrid/entrypoint.sh
COPY cubrid.sh            /home/cubrid/.cubrid.sh
RUN chmod 755 /home/cubrid/entrypoint.sh /home/cubrid/.cubrid.sh && \
    chown cubrid:cubrid /home/cubrid/entrypoint.sh /home/cubrid/.cubrid.sh && \
    printf '%s\n' \
      '#----------------------------------------------------------------' \
      '# set CUBRID environment variables' \
      '#----------------------------------------------------------------' \
      'if [ -f /home/cubrid/.cubrid.sh ];then' \
      '. /home/cubrid/.cubrid.sh' \
      'fi' >> /home/cubrid/.bash_profile && \
    chown cubrid:cubrid /home/cubrid/.bash_profile

# Both the engine and the manager have to be up: NCA is useless without the
# manager, and a manager that answers while the engine is down is misleading.
# No @host on the db name: databases.txt records the container hostname, so
# <db>@localhost fails when csql runs without a shell.
# The manager check greps the status text rather than trusting an exit code.
HEALTHCHECK --interval=10s --timeout=10s --start-period=120s --retries=3 \
  CMD gosu cubrid csql -u dba -c "SELECT 1" ${CUBRID_DB} > /dev/null 2>&1 \
      && gosu cubrid cubrid manager status 2>&1 | grep -q "is running" || exit 1

VOLUME ${CUBRID_DATABASES}
EXPOSE 33000 8001
ENTRYPOINT ["/home/cubrid/entrypoint.sh"]
