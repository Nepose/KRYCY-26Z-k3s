#!/usr/bin/env bash
# Tworzy .kube/config stacji analityka z /etc/rancher/k3s/k3s.yaml na serwerze.
# Wywoływany przez up.sh; osobno przydaje się po sklonowaniu repo przy działającym klastrze.
# tls-server-name=kubernetes: certyfikat jest weryfikowany po nazwie z SAN k3s, a nie po IP,
# więc kubeconfig działa także wtedy, gdy VM-ka po restarcie dostanie inny adres.
# shellcheck source=infra/lib.sh
source "$(dirname "$0")/lib.sh"
need kubectl

api_ip=$(node_out "$SERVER" "$REMOTE_DIR/node/node-ip.sh" "$API_IFACE")
[ -n "$api_ip" ] || die "nie ustalono adresu API serwera $SERVER (interfejs '$API_IFACE')"

mkdir -p "$(dirname "$KUBECONFIG_PATH")"
umask 077
node_out "$SERVER" cat /etc/rancher/k3s/k3s.yaml > "$KUBECONFIG_PATH"
kubectl config --kubeconfig "$KUBECONFIG_PATH" set-cluster default \
  --server "https://$api_ip:6443" --tls-server-name kubernetes >/dev/null
kubectl config --kubeconfig "$KUBECONFIG_PATH" rename-context default krycy-lab >/dev/null
chmod 600 "$KUBECONFIG_PATH"
log "Zapisano kubeconfig: ${KUBECONFIG_PATH#"$REPO_ROOT"/} (API: https://$api_ip:6443)"
