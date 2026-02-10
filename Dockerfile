FROM registry:2

COPY config.yml /etc/docker/registry/config.yml

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:5000/v2/ || exit 1
