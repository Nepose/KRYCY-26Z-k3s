# shellcheck shell=bash
# Wspólne funkcje dla skryptów uruchamianych na HOŚCIE (stacja analityka / Mac).
# Kompatybilne z bash 3.2 (domyślny bash w macOS).
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=infra/versions.env
source "$REPO_ROOT/infra/versions.env"

# --- Konfiguracja labu (każdą wartość można nadpisać zmienną środowiskową) ---
TRANSPORT=${TRANSPORT:-lima}            # lima = VM-ki Lima na Macu; ssh = istniejące hosty
SERVER=${SERVER:-k3s-server}            # nazwa VM-ki Lima albo alias SSH serwera k3s
AGENTS=${AGENTS-k3s-agent-1}            # lista rozdzielona spacjami; AGENTS="" = 1 węzeł
if [ "$TRANSPORT" = lima ]; then
  NODE_IFACE=${NODE_IFACE-eth0}         # interfejs sieci między węzłami (Lima user-v2)
  API_IFACE=${API_IFACE-lima1}          # interfejs, przez który host łączy się z API (vzNAT)
else
  # ssh / libvirt: pojedyncza karta, adres z trasy domyślnej (node-ip.sh bez interfejsu).
  # Przy libvirt NAT libvirta jest widoczny także z hosta, więc API_IFACE = NODE_IFACE.
  NODE_IFACE=${NODE_IFACE-}             # "" = adres z trasy domyślnej
  API_IFACE=${API_IFACE-$NODE_IFACE}
fi
SERVER_CPUS=${SERVER_CPUS:-2}; SERVER_MEM=${SERVER_MEM:-4}   # GiB
AGENT_CPUS=${AGENT_CPUS:-2};   AGENT_MEM=${AGENT_MEM:-4}     # GiB
KUBECONFIG_PATH=${KUBECONFIG_PATH:-$REPO_ROOT/.kube/config}
REMOTE_DIR=/opt/krycy                   # gdzie na węźle lądują infra/node i infra/config

# Prowizjoner VM-ek na Linuksie (virsh + cloud-init). Sourcujemy tylko dla TRANSPORT=libvirt,
# żeby ścieżka macOS (lima) nie zależała od obecności tego pliku ani narzędzi libvirta.
if [ "$TRANSPORT" = libvirt ]; then
  # shellcheck source=infra/libvirt/provision.sh
  source "$REPO_ROOT/infra/libvirt/provision.sh"
fi

log()  { printf '\033[1;34m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
warn() { printf '\033[1;33mUWAGA:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mBŁĄD:\033[0m %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "brak polecenia '$1' (zobacz README, sekcja Wymagania)"; }

all_nodes() { echo "$SERVER $AGENTS"; }

# node_exec WĘZEŁ POLECENIE... — uruchamia polecenie na węźle jako root.
# stdin i stdout są przekazywane, więc można przesyłać skrypty i strumienie tar.
node_exec() {
  local node=$1; shift
  case $TRANSPORT in
    lima) limactl shell --workdir / "$node" sudo "$@" ;;
    ssh)  ssh -o BatchMode=yes "$node" "sudo $(printf '%q ' "$@")" ;;
    # shellcheck disable=SC2046  # lab_ssh_opts celowo się dzieli na słowa
    libvirt) ssh $(lab_ssh_opts) "$LAB_USER@$(libvirt_ip "$node")" "sudo $(printf '%q ' "$@")" ;;
    *)    die "nieznany TRANSPORT=$TRANSPORT (dozwolone: lima, ssh, libvirt)" ;;
  esac
}

# node_out WĘZEŁ POLECENIE... — jak node_exec, ale do przechwytywania wyniku: bez stdin
# (żeby nie powstał pseudo-terminal) i bez znaków \r.
node_out() { node_exec "$@" </dev/null | tr -d '\r'; }

# node_raw WĘZEŁ POLECENIE... — wynik binarny (np. gzip) bez żadnej obróbki.
node_raw() { node_exec "$@" </dev/null; }

# node_sync WĘZEŁ — kopiuje infra/node, infra/config i versions.env do $REMOTE_DIR na węźle.
node_sync() {
  local tar_opts=""
  # bsdtar z macOS dokleja atrybuty rozszerzone, których GNU tar na węźle nie rozumie
  if tar --version 2>/dev/null | grep -q bsdtar; then tar_opts="--no-mac-metadata --no-xattrs"; fi
  # shellcheck disable=SC2086
  COPYFILE_DISABLE=1 tar $tar_opts -C "$REPO_ROOT/infra" -cf - node config versions.env \
    | node_exec "$1" sh -c "rm -rf $REMOTE_DIR && mkdir -p $REMOTE_DIR && tar --no-same-owner -C $REMOTE_DIR -xf - && chmod +x $REMOTE_DIR/node/*.sh"
}

# lima_ensure_vm NAZWA CPU RAM_GIB — tworzy albo uruchamia VM-kę (idempotentnie).
lima_ensure_vm() {
  local vm=$1 cpus=$2 mem=$3 status
  status=$(limactl list --format '{{.Status}}' "$vm" 2>/dev/null || true)
  case $status in
    Running) log "VM $vm już działa" ;;
    Stopped) log "Uruchamiam istniejącą VM $vm"; limactl start --tty=false "$vm" ;;
    "")      log "Tworzę VM $vm ($cpus CPU, $mem GiB RAM)"
             limactl start --tty=false --name="$vm" --cpus="$cpus" --memory="$mem" "$REPO_ROOT/infra/lima/node.yaml" ;;
    *)       die "VM $vm jest w stanie '$status', napraw ręcznie (limactl list)" ;;
  esac
}

# wait_cluster_ready — czeka, aż API odpowiada i wszystkie węzły labu są Ready.
wait_cluster_ready() {
  local want ready i
  want=$(all_nodes | wc -w | tr -d ' ')
  log "Czekam na API i $want węzeł(y) w stanie Ready…"
  for i in $(seq 1 90); do
    # `|| true`: zaraz po starcie API nie odpowiada, a przy set -e + pipefail przerwałoby to skrypt
    ready=$(KUBECONFIG=$KUBECONFIG_PATH kubectl get nodes --no-headers 2>/dev/null | awk '$2=="Ready"' | wc -l | tr -d ' ' || true)
    if [ "${ready:-0}" -ge "$want" ]; then
      KUBECONFIG=$KUBECONFIG_PATH kubectl get nodes -o wide
      return 0
    fi
    [ $((i % 15)) -eq 0 ] && log "…nadal czekam (Ready: ${ready:-0}/$want)"
    sleep 2
  done
  die "klaster nie osiągnął gotowości w 3 minuty"
}
