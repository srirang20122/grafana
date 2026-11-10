#!/bin/sh
# Starts Prometheus, Loki and Tempo in the background (restarting any that exit),
# then runs Grafana in the foreground as the container's main process.
set -eu

DATA=/var/lib/monitoring
mkdir -p "$DATA/prometheus" "$DATA/loki" "$DATA/tempo"

# Prometheus has no env-var support in its config, so fill in the scrape target here.
sed "s|\${SCRAPE_TARGET}|${SCRAPE_TARGET}|g" /etc/monitoring/prometheus.yml > /tmp/prometheus.yml

keep_running() {
  name=$1
  shift
  while true; do
    "$@" || true
    echo "[start.sh] $name exited, restarting in 5s" >&2
    sleep 5
  done
}

keep_running prometheus /usr/local/bin/prometheus \
  --config.file=/tmp/prometheus.yml \
  --storage.tsdb.path="$DATA/prometheus" \
  --web.listen-address=:9090 &

keep_running loki /usr/local/bin/loki -config.file=/etc/monitoring/loki.yaml &

keep_running tempo /usr/local/bin/tempo -config.file=/etc/monitoring/tempo.yaml &

# Grafana's own entrypoint from the base image.
exec /run.sh "$@"
