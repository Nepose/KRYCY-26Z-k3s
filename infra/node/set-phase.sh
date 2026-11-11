#!/usr/bin/env bash
# Uruchamiane NA WĘŹLE jako root: przełącza węzeł między fazą A i B.
#   a      — usuwa drop-in forensic readiness (k3s wraca do konfiguracji bazowej)
#   b      — instaluje drop-in z infra/config/phase-b/<rola>.yaml (+ politykę audytu na serwerze)
#   status — wypisuje A albo B
# shellcheck source=infra/node/common.sh
source "$(dirname "$0")/common.sh"

if systemctl cat k3s.service >/dev/null 2>&1; then ROLE=server; SVC=k3s
elif systemctl cat k3s-agent.service >/dev/null 2>&1; then ROLE=agent; SVC=k3s-agent
else echo "k3s nie jest zainstalowany na $(hostname)" >&2; exit 1
fi
CONF="$NODE_DIR/../config/phase-b"

case ${1:-} in
  status)
    if [ -f "$K3S_DROPIN" ]; then echo B; else echo A; fi
    exit 0 ;;
  a)
    rm -f "$K3S_DROPIN" ;;
  b)
    install -D -m 0600 "$CONF/$ROLE.yaml" "$K3S_DROPIN"
    if [ "$ROLE" = server ]; then
      install -D -m 0600 "$CONF/audit-policy.yaml" /etc/rancher/k3s/audit-policy.yaml
      install -d -m 0700 /var/lib/rancher/k3s/server/logs
    fi ;;
  *)
    echo "Użycie: $0 a|b|status" >&2; exit 2 ;;
esac

systemctl restart "$SVC"
echo "$(hostname) ($ROLE): faza $(echo "$1" | tr ab AB)"
