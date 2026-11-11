#!/usr/bin/env bash
# K.4: instaluje albo aktualizuje Falco (telemetria runtime) z regułami projektu.
# Użycie: detection/falco/install.sh [--uninstall]
# shellcheck source=infra/lib.sh
source "$(dirname "$0")/../../infra/lib.sh"
need kubectl
need helm
export KUBECONFIG=$KUBECONFIG_PATH
D="$REPO_ROOT/detection/falco"

if [ "${1:-}" = "--uninstall" ]; then
  helm uninstall falco --namespace falco
  exit 0
fi

log "Falco: chart $FALCO_CHART_VERSION, sterownik modern_ebpf"
helm upgrade --install falco falco \
  --repo https://falcosecurity.github.io/charts \
  --version "$FALCO_CHART_VERSION" \
  --namespace falco --create-namespace \
  --values "$D/values.yaml" \
  --set-file "customRules.krycy-rules\.yaml=$D/rules/krycy-rules.yaml" \
  --wait --timeout 10m
kubectl -n falco rollout status daemonset/falco --timeout=5m
kubectl -n falco get pods -o wide
log "Zdarzenia:  kubectl -n falco logs -l app.kubernetes.io/name=falco -c falco -f"
