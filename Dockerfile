# One image for the whole observability stack: Grafana + Prometheus + Loki + Tempo.
# Prometheus, Loki and Tempo are single static Go binaries, copied from their
# official images into the Grafana image. start.sh runs them next to Grafana.
ARG PROMETHEUS_VERSION=latest
ARG LOKI_VERSION=latest
ARG TEMPO_VERSION=latest
ARG GRAFANA_VERSION=latest

FROM prom/prometheus:${PROMETHEUS_VERSION} AS prometheus
FROM grafana/loki:${LOKI_VERSION} AS loki
FROM grafana/tempo:${TEMPO_VERSION} AS tempo

FROM grafana/grafana:${GRAFANA_VERSION}

USER root
COPY --from=prometheus /bin/prometheus /usr/local/bin/prometheus
COPY --from=loki /usr/bin/loki /usr/local/bin/loki
COPY --from=tempo /tempo /usr/local/bin/tempo

COPY datasources.yml /etc/grafana/provisioning/datasources/datasources.yml
COPY prometheus.yml loki.yaml tempo.yaml /etc/monitoring/
COPY start.sh /usr/local/bin/start.sh

# Strip Windows line endings (repo is edited on Windows), make the script
# executable, and give the Grafana user (472) its own data folders.
# Tempo also writes to /var/tempo by default, so link that into the data volume.
RUN sed -i 's/\r$//' /usr/local/bin/start.sh \
 && chmod +x /usr/local/bin/start.sh \
 && mkdir -p /var/lib/monitoring/prometheus /var/lib/monitoring/loki /var/lib/monitoring/tempo \
 && chown -R 472:0 /var/lib/monitoring \
 && chmod -R g+rwX /var/lib/monitoring \
 && ln -s /var/lib/monitoring/tempo /var/tempo

# Everything runs in this container, so the datasources point at localhost.
# SCRAPE_TARGET is where Prometheus finds the monitor-system /metrics endpoint.
ENV PROMETHEUS_URL=http://localhost:9090 \
    LOKI_URL=http://localhost:3100 \
    TEMPO_URL=http://localhost:3200 \
    SCRAPE_TARGET=monitor-system:8000

USER 472
VOLUME ["/var/lib/monitoring"]
#      Grafana Prometheus Loki Tempo OTLP-gRPC OTLP-HTTP
EXPOSE 3000    9090       3100 3200  4317      4318
ENTRYPOINT ["/usr/local/bin/start.sh"]
