#!/usr/bin/env bash
# Usuwa klaster labu: VM-ki Lima (TRANSPORT=lima) albo k3s z hostów (TRANSPORT=ssh).
# Użycie: infra/down.sh [-y]
# shellcheck source=infra/lib.sh
source "$(dirname "$0")/lib.sh"

nodes=$(all_nodes)
if [ "${1:-}" != "-y" ]; then
  warn "Usunę węzły: $nodes ($TRANSPORT)."
  warn "Dowody, które są tylko na węzłach (audit log, logi podów, journal), PRZEPADNĄ. Najpierw: make triage."
  printf 'Kontynuować? [t/N] '
  read -r ans
  case $ans in t|T|y|Y) ;; *) echo "Przerwano."; exit 1 ;; esac
fi

case $TRANSPORT in
  lima)
    need limactl
    # shellcheck disable=SC2086
    limactl delete --force $nodes ;;
  ssh)
    for n in $nodes; do
      log "Odinstalowuję k3s z $n"
      # shellcheck disable=SC2016  # $s ma się rozwinąć na węźle, nie tutaj
      node_exec "$n" sh -c 'for s in /usr/local/bin/k3s-uninstall.sh /usr/local/bin/k3s-agent-uninstall.sh; do [ -x "$s" ] && "$s"; done; rm -rf /opt/krycy' </dev/null
    done ;;
esac
rm -f "$KUBECONFIG_PATH"
log "Klaster usunięty."
