#!/usr/bin/env bash
# X.3: triage IR dla poda. Zabezpiecza dowody w kolejności ulotności, liczy SHA-256 i pakuje.
# Użycie: triage/triage.sh -n NAMESPACE -p POD [-o KATALOG] [--no-node]
#
# Kolejność (od najbardziej ulotnych):
#   10 logi kontenerów (znikają razem z podem)
#   20 specyfikacja i stan poda
#   30 węzeł: crictl inspect, procesy i połączenia kontenera, zapisywalna warstwa FS, logi z dysku, journal k3s
#   40 kontekst klastra: eventy (TTL!), service account, RBAC, NetworkPolicy
#   50 telemetria: audit log API servera, zdarzenia Falco z węzła poda
# Skrypt tylko czyta (żadnych exec do kontenera); każdy krok jest logowany w collection.log.
# shellcheck source=infra/lib.sh
source "$(dirname "$0")/../infra/lib.sh"
need kubectl
export KUBECONFIG=${KUBECONFIG:-$KUBECONFIG_PATH}

NS=""; POD=""; OUT=""; NODE_LEVEL=1
while [ $# -gt 0 ]; do
  case $1 in
    -n) NS=$2; shift 2 ;;
    -p) POD=$2; shift 2 ;;
    -o) OUT=$2; shift 2 ;;
    --no-node) NODE_LEVEL=0; shift ;;
    *) echo "Użycie: $0 -n NAMESPACE -p POD [-o KATALOG] [--no-node]" >&2; exit 2 ;;
  esac
done
[ -n "$NS" ] && [ -n "$POD" ] || { echo "Użycie: $0 -n NAMESPACE -p POD [-o KATALOG] [--no-node]" >&2; exit 2; }

TS=$(date -u +%Y%m%dT%H%M%SZ)
OUT=${OUT:-$REPO_ROOT/evidence/${TS}_${NS}_${POD}}
mkdir -p "$OUT"
LOG="$OUT/collection.log"

# collect PLIK POLECENIE... — stdout do pliku; stderr, czas i kod wyjścia do collection.log.
# Błąd pojedynczego kroku nie przerywa zbierania (brak dowodu to też wynik).
collect() {
  local file=$1 rc=0; shift
  mkdir -p "$(dirname "$OUT/$file")"
  "$@" > "$OUT/$file" 2>> "$LOG.stderr" || rc=$?
  printf '%s\trc=%s\t%s\t%s\n' "$(date -u +%FT%TZ)" "$rc" "$file" "$*" >> "$LOG"
  [ "$rc" -eq 0 ] || warn "krok '$file' zakończony kodem $rc"
  return 0
}
jp() { kubectl get pod -n "$NS" "$POD" -o "jsonpath=$1" 2>/dev/null || true; }

log "Triage $NS/$POD -> ${OUT#"$REPO_ROOT"/}"
{
  echo "analityk:      $(whoami)@$(hostname)"
  echo "start (UTC):   $TS"
  echo "kontekst:      $(kubectl config current-context 2>/dev/null)"
  echo "cel:           pod $NS/$POD"
  echo "faza labu:     $(node_out "$SERVER" "$REMOTE_DIR/node/set-phase.sh" status 2>/dev/null || echo '?')"
  echo "narzędzie:     triage.sh @ $(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')"
} > "$OUT/00-metadata.txt"
collect 00-cluster-version.txt kubectl version

POD_EXISTS=1
kubectl get pod -n "$NS" "$POD" >/dev/null 2>&1 || POD_EXISTS=0
if [ "$POD_EXISTS" -eq 0 ]; then
  warn "Pod $NS/$POD nie istnieje. Logi, stan i FS kontenera są już utracone; zbieram kontekst klastra."
  echo "POD NIE ISTNIAŁ W CHWILI TRIAGE" >> "$OUT/00-metadata.txt"
fi

NODE=$(jp '{.spec.nodeName}')
POD_UID=$(jp '{.metadata.uid}')
SA=$(jp '{.spec.serviceAccountName}')
CONTAINERS=$(jp '{range .spec.initContainers[*]}{.name}{" "}{end}{range .spec.containers[*]}{.name}{" "}{end}')
CIDS=$(jp '{range .status.initContainerStatuses[*]}{.containerID}{" "}{end}{range .status.containerStatuses[*]}{.containerID}{" "}{end}' | sed 's#[a-z]*://##g')

# --- 10: logi kontenerów ---
for c in $CONTAINERS; do
  collect "10-logs/$c.log" kubectl logs -n "$NS" "$POD" -c "$c" --timestamps
  collect "10-logs/$c.previous.log" kubectl logs -n "$NS" "$POD" -c "$c" --timestamps --previous
done

# --- 20: specyfikacja i stan poda ---
if [ "$POD_EXISTS" -eq 1 ]; then
  collect 20-pod/pod.yaml kubectl get pod -n "$NS" "$POD" -o yaml
  collect 20-pod/describe.txt kubectl describe pod -n "$NS" "$POD"
fi

# --- 30: węzeł ---
if [ "$NODE_LEVEL" -eq 1 ] && [ -n "$NODE" ]; then
  log "Zbieram dowody z węzła $NODE"
  rc=0
  # shellcheck disable=SC2086  # CIDS to lista rozdzielona spacjami
  node_exec "$NODE" bash -s -- "$NS" "$POD" "$POD_UID" $CIDS \
    < "$REPO_ROOT/triage/node-collect.sh" > "$OUT/30-node.tar" 2>> "$LOG.stderr" || rc=$?
  if [ "$rc" -eq 0 ]; then
    mkdir -p "$OUT/30-node"
    tar -xf "$OUT/30-node.tar" -C "$OUT/30-node" && rm -f "$OUT/30-node.tar"
  else
    warn "zbieranie z węzła nie powiodło się (szczegóły: collection.log.stderr)"
  fi
  printf '%s\trc=%s\t30-node/\twęzeł %s\n' "$(date -u +%FT%TZ)" "$rc" "$NODE" >> "$LOG"
fi

# --- 40: kontekst klastra ---
collect 40-cluster/events-namespace.txt kubectl get events -n "$NS" --sort-by=.lastTimestamp -o wide
collect 40-cluster/events-all.yaml kubectl get events -A -o yaml
collect 40-cluster/pods-namespace.txt kubectl get pods -n "$NS" -o wide
[ -n "$SA" ] && collect "40-cluster/serviceaccount-$SA.yaml" kubectl get serviceaccount -n "$NS" "$SA" -o yaml
collect 40-cluster/rolebindings.yaml kubectl get rolebindings -n "$NS" -o yaml
collect 40-cluster/clusterrolebindings.yaml kubectl get clusterrolebindings -o yaml
collect 40-cluster/networkpolicies.yaml kubectl get networkpolicies -n "$NS" -o yaml

# --- 50: telemetria ---
# shellcheck disable=SC2016
collect 50-telemetry/audit.log.gz node_raw "$SERVER" sh -c \
  'f=/var/lib/rancher/k3s/server/logs/audit.log; if [ -f "$f" ]; then gzip -c "$f"; else echo "brak audit logu (faza A?)" >&2; exit 3; fi'
if [ -n "$NODE" ] && kubectl get ns falco >/dev/null 2>&1; then
  FALCO_POD=$(kubectl get pods -n falco -l app.kubernetes.io/name=falco \
    --field-selector "spec.nodeName=$NODE" -o name 2>/dev/null | head -1)
  [ -n "$FALCO_POD" ] && collect "50-telemetry/falco-$NODE.jsonl" kubectl logs -n falco "$FALCO_POD" -c falco
fi

# --- Sumy kontrolne i paczka ---
{ echo "koniec (UTC):  $(date -u +%Y%m%dT%H%M%SZ)"; } >> "$OUT/00-metadata.txt"
sha256() { if command -v sha256sum >/dev/null; then sha256sum "$@"; else shasum -a 256 "$@"; fi; }
(cd "$OUT" && find . -type f | LC_ALL=C sort | while IFS= read -r f; do sha256 "$f"; done > "$OUT.sums.tmp")
mv "$OUT.sums.tmp" "$OUT/SHA256SUMS"
tar -C "$(dirname "$OUT")" -czf "$OUT.tar.gz" "$(basename "$OUT")"
(cd "$(dirname "$OUT")" && sha256 "$(basename "$OUT").tar.gz" > "$(basename "$OUT").tar.gz.sha256")
log "Gotowe: ${OUT#"$REPO_ROOT"/}.tar.gz"
cat "$OUT.tar.gz.sha256"
