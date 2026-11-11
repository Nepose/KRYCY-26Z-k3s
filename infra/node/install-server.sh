#!/usr/bin/env bash
# Uruchamiane NA WĘŹLE jako root: instaluje serwer k3s w konfiguracji bazowej (faza A).
# Użycie: install-server.sh --node-name NAZWA [--iface INTERFEJS] [--tls-san ADRES]
#   --tls-san: dodatkowy adres w certyfikacie API (np. adres, pod którym widzi go host analityka)
# shellcheck source=infra/node/common.sh
source "$(dirname "$0")/common.sh"

NAME=$(hostname); IFACE=""; SAN=""
while [ $# -gt 0 ]; do
  case $1 in
    --node-name) NAME=$2; shift 2 ;;
    --iface)     IFACE=$2; shift 2 ;;
    --tls-san)   SAN=$2; shift 2 ;;
    *) echo "nieznany argument: $1" >&2; exit 2 ;;
  esac
done

write_base_config "$NAME" "$IFACE" "$SAN"
install_k3s server

# Czekamy, aż serwer wystawi token dla agentów i odpowie API
for _ in $(seq 1 60); do
  [ -s /var/lib/rancher/k3s/server/node-token ] && k3s kubectl get --raw /readyz >/dev/null 2>&1 && break
  sleep 2
done
k3s kubectl get --raw /readyz >/dev/null
echo "$(hostname): serwer k3s $K3S_VERSION gotowy"
