#!/usr/bin/env bash
# Przełącza cały klaster między fazami eksperymentu:
#   a      — domyślny k3s (co zostaje po incydencie „samo z siebie”)
#   b      — forensic readiness: audit log API servera, dłuższe eventy, większa retencja logów
#   status — pokazuje fazę każdego węzła
# shellcheck source=infra/lib.sh
source "$(dirname "$0")/lib.sh"

mode=${1:-}
case $mode in
  a|b|status) ;;
  *) echo "Użycie: $0 a|b|status" >&2; exit 2 ;;
esac

if [ "$mode" = status ]; then
  for n in $(all_nodes); do
    printf '%-16s faza %s\n' "$n" "$(node_out "$n" "$REMOTE_DIR/node/set-phase.sh" status)"
  done
  exit 0
fi

need kubectl
for n in $(all_nodes); do        # najpierw serwer, potem agenci
  node_sync "$n"
  node_exec "$n" "$REMOTE_DIR/node/set-phase.sh" "$mode" </dev/null
done
wait_cluster_ready
log "Klaster w fazie $(echo "$mode" | tr ab AB)."
