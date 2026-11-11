# shellcheck shell=bash
# Wspólne funkcje dla skryptów uruchamianych NA WĘŹLE (Ubuntu, jako root).
set -euo pipefail

NODE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=infra/versions.env
source "$NODE_DIR/../versions.env"

K3S_CONFIG=/etc/rancher/k3s/config.yaml
K3S_DROPIN=/etc/rancher/k3s/config.yaml.d/50-forensic-readiness.yaml

[ "$(id -u)" -eq 0 ] || { echo "uruchom jako root" >&2; exit 1; }

# write_base_config NODE_NAME IFACE [TLS_SAN] — konfiguracja bazowa węzła (to jest cała faza A).
write_base_config() {
  local name=$1 iface=$2 san=${3:-} ip=""
  [ -n "$iface" ] && ip=$("$NODE_DIR/node-ip.sh" "$iface")
  [ -n "$iface" ] && [ -z "$ip" ] && { echo "interfejs $iface nie ma adresu IPv4" >&2; exit 1; }
  mkdir -p "$(dirname "$K3S_CONFIG")"
  {
    echo "# Konfiguracja bazowa węzła, wygenerowana przez $(basename "$0")."
    echo "# Faza A (domyślny k3s) = tylko ten plik."
    echo "# Faza B dodaje $K3S_DROPIN (patrz set-phase.sh)."
    echo "node-name: $name"
    if [ -n "$ip" ]; then
      echo "node-ip: $ip"
      echo "flannel-iface: $iface"
    fi
    if [ -n "$san" ]; then
      echo "tls-san:"
      echo "  - $san"
    fi
  } > "$K3S_CONFIG"
}

# install_k3s ARGUMENTY... — instalator k3s przypięty do wersji z versions.env
# (zarówno sam install.sh, jak i binarka; install.sh weryfikuje sumę SHA256 binarki).
install_k3s() {
  local url="https://raw.githubusercontent.com/k3s-io/k3s/${K3S_VERSION/+/%2B}/install.sh"
  local script
  script=$(curl -sfL --connect-timeout 15 --max-time 60 --retry 3 "$url") \
    || { echo "nie udało się pobrać $url (sprawdź dostęp VM-ki do internetu)" >&2; exit 1; }
  printf '%s\n' "$script" | INSTALL_K3S_VERSION="$K3S_VERSION" sh -s - "$@"
}
