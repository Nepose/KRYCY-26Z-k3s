#!/usr/bin/env bash
# K.1: stawia odtwarzalny klaster k3s w fazie A (domyślna konfiguracja).
#   TRANSPORT=lima (domyślnie): tworzy VM-ki Lima na Macu.
#   TRANSPORT=ssh: instaluje k3s na istniejących hostach, np.
#     TRANSPORT=ssh SERVER=lab1 AGENTS="lab2" NODE_IFACE=eth0 infra/up.sh
# Skrypt jest idempotentny: ponowne uruchomienie dokańcza lub odświeża instalację.
# shellcheck source=infra/lib.sh
source "$(dirname "$0")/lib.sh"
need kubectl

if [ "$TRANSPORT" = lima ]; then
  need limactl
  lima_ensure_vm "$SERVER" "$SERVER_CPUS" "$SERVER_MEM"
  for a in $AGENTS; do lima_ensure_vm "$a" "$AGENT_CPUS" "$AGENT_MEM"; done
fi

log "Serwer $SERVER: instaluję k3s $K3S_VERSION"
node_sync "$SERVER"
server_ip=$(node_out "$SERVER" "$REMOTE_DIR/node/node-ip.sh" "$NODE_IFACE")   # dla agentów
api_ip=$(node_out "$SERVER" "$REMOTE_DIR/node/node-ip.sh" "$API_IFACE")       # dla kubectl z hosta
[ -n "$server_ip" ] || die "nie ustalono IP serwera (interfejs '$NODE_IFACE')"
[ -n "$api_ip" ] || die "nie ustalono adresu API serwera (interfejs '$API_IFACE')"
node_exec "$SERVER" "$REMOTE_DIR/node/install-server.sh" \
  --node-name "$SERVER" --iface "$NODE_IFACE" --tls-san "$api_ip" </dev/null
token=$(node_out "$SERVER" cat /var/lib/rancher/k3s/server/node-token)

for a in $AGENTS; do
  log "Agent $a: dołączam do https://$server_ip:6443"
  node_sync "$a"
  printf '%s\n' "$token" | node_exec "$a" "$REMOTE_DIR/node/install-agent.sh" \
    --server "https://$server_ip:6443" --node-name "$a" --iface "$NODE_IFACE"
done

"$REPO_ROOT/infra/kubeconfig.sh"

wait_cluster_ready
log "Gotowe. Faza A (domyślny k3s). Dalej:  export KUBECONFIG=\$PWD/.kube/config"
