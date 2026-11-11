#!/usr/bin/env bash
# Uruchamiane NA WĘŹLE jako root: dołącza agenta k3s do klastra (faza A).
# Token czytany jest ze stdin, żeby nie był widoczny w liście procesów.
# Użycie: echo TOKEN | install-agent.sh --server https://IP:6443 --node-name NAZWA [--iface INTERFEJS]
# shellcheck source=infra/node/common.sh
source "$(dirname "$0")/common.sh"

NAME=$(hostname); IFACE=""; URL=""
while [ $# -gt 0 ]; do
  case $1 in
    --server)    URL=$2; shift 2 ;;
    --node-name) NAME=$2; shift 2 ;;
    --iface)     IFACE=$2; shift 2 ;;
    *) echo "nieznany argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "$URL" ] || { echo "brak --server" >&2; exit 2; }
IFS= read -r TOKEN || true
[ -n "$TOKEN" ] || { echo "brak tokenu na stdin" >&2; exit 2; }

write_base_config "$NAME" "$IFACE"
K3S_URL="$URL" K3S_TOKEN="$TOKEN" install_k3s agent
echo "$(hostname): agent k3s $K3S_VERSION dołączony do $URL"
