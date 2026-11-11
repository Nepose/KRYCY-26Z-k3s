#!/usr/bin/env bash
# Test end-to-end labu: węzły, faza, audit log (faza B) i wykrycie zdarzenia przez Falco.
# Użycie: tests/smoke.sh   (kod wyjścia != 0, jeśli któryś test nie przeszedł)
# shellcheck source=infra/lib.sh
source "$(dirname "$0")/../infra/lib.sh"
need kubectl
export KUBECONFIG=$KUBECONFIG_PATH
FAILED=0
ok()   { printf '  \033[32mOK\033[0m   %s\n' "$*"; }
bad()  { printf '  \033[31mFAIL\033[0m %s\n' "$*"; FAILED=1; }
skip() { printf '  \033[33mSKIP\033[0m %s\n' "$*"; }

echo "[1] Węzły"
want=$(all_nodes | wc -w | tr -d ' ')
ready=$(kubectl get nodes --no-headers 2>/dev/null | awk '$2=="Ready"' | wc -l | tr -d ' ' || true)
if [ "$ready" -eq "$want" ]; then ok "$ready/$want węzłów Ready"; else bad "Ready: $ready/$want"; fi

echo "[2] Faza i audit log"
phase=$(node_out "$SERVER" "$REMOTE_DIR/node/set-phase.sh" status)
ok "serwer w fazie $phase"
if [ "$phase" = B ]; then
  marker="krycy-smoke-$(date +%s)"
  kubectl auth can-i --list -n "$marker" >/dev/null 2>&1 || true   # znacznik w audit logu
  found=0
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if node_out "$SERVER" grep -q "$marker" /var/lib/rancher/k3s/server/logs/audit.log 2>/dev/null; then found=1; break; fi
    sleep 1
  done
  if [ "$found" -eq 1 ]; then ok "audit log rejestruje selfsubjectrulesreviews (znacznik $marker)"
  else bad "brak znacznika $marker w audit logu"; fi
else
  skip "faza A: audit log wyłączony z założenia"
fi

echo "[3] Falco"
if kubectl get ns falco >/dev/null 2>&1; then
  pod="krycy-smoke-$(date +%s)"
  kubectl run "$pod" -n default --image=busybox:1.37 --restart=Never --command -- \
    sh -c 'cat /var/run/secrets/kubernetes.io/serviceaccount/token >/dev/null' >/dev/null
  kubectl wait -n default --for=jsonpath='{.status.phase}'=Succeeded "pod/$pod" --timeout=120s >/dev/null || true
  found=0
  for _ in $(seq 1 20); do
    if kubectl logs -n falco -l app.kubernetes.io/name=falco -c falco --tail=-1 2>/dev/null \
         | grep 'KRYCY Odczyt tokenu' | grep -q "$pod"; then found=1; break; fi
    sleep 2
  done
  kubectl delete pod -n default "$pod" --wait=false >/dev/null 2>&1 || true
  if [ "$found" -eq 1 ]; then ok "reguła 'KRYCY Odczyt tokenu ServiceAccount' wykryła pod $pod"
  else bad "Falco nie zgłosił odczytu tokenu w podzie $pod"; fi
else
  skip "Falco nie jest zainstalowany (make falco)"
fi

if [ "$FAILED" -eq 0 ]; then echo "Wszystkie testy OK"; else echo "Są błędy"; exit 1; fi
