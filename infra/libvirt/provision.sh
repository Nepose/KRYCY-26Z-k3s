# shellcheck shell=bash
# shellcheck disable=SC2154  # REPO_ROOT oraz funkcje log/die/need/all_nodes pochodzą z lib.sh (ten plik jest sourcowany)
# Prowizjoner VM-ek libvirt/KVM dla labu (Linux). Sourcowany przez infra/lib.sh,
# gdy TRANSPORT=libvirt. Odpowiednik lima_ensure_vm z macOS, ale na virsh + cloud-init.
#
# Założenia hosta (Linux):
#   - pakiety: libvirt-daemon-system, qemu-kvm, virtinst, qemu-utils, wget, openssh-client
#   - użytkownik w grupie `libvirt` (dostęp do qemu:///system bez sudo)
#   - aktywna sieć NAT libvirta i pula dysków (domyślnie obie o nazwie `default`)
# Węzły są dostępne po SSH jako użytkownik `krycy` (cloud-init), kluczem z $LAB_KEY.
# Dzięki NAT libvirta host sięga VM bezpośrednio — bez macowego hacku z drugą kartą.

LIBVIRT_URI=${LIBVIRT_URI:-qemu:///system}
LIBVIRT_NET=${LIBVIRT_NET:-default}      # sieć NAT (host<->VM, VM<->VM, VM->internet)
LIBVIRT_POOL=${LIBVIRT_POOL:-default}    # pula dysków libvirta
LAB_USER=${LAB_USER:-krycy}
LAB_KEY=${LAB_KEY:-$REPO_ROOT/.lab/id_ed25519}
LAB_CACHE=${LAB_CACHE:-$REPO_ROOT/.lab/cache}
# Obraz bazowy: Ubuntu 24.04 (noble) cloud image. Nazwę woluminu w puli trzymamy stałą.
UBUNTU_IMAGE_URL=${UBUNTU_IMAGE_URL:-https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img}
BASE_VOL=${BASE_VOL:-krycy-ubuntu-24.04.qcow2}

_vsh() { virsh -c "$LIBVIRT_URI" "$@"; }

# lab_ssh_opts — wspólne opcje SSH do węzłów (klucz labu, bez pytań o known_hosts).
lab_ssh_opts() {
  printf '%s ' -i "$LAB_KEY" -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
    -o UserKnownHostsFile="$REPO_ROOT/.lab/known_hosts" -o ConnectTimeout=10
}

# lab_key_ensure — generuje dedykowany klucz SSH labu, jeśli go nie ma (nie commitujemy go).
lab_key_ensure() {
  [ -f "$LAB_KEY" ] && return 0
  mkdir -p "$(dirname "$LAB_KEY")"; chmod 700 "$(dirname "$LAB_KEY")"
  log "Generuję klucz SSH labu: ${LAB_KEY#"$REPO_ROOT"/}"
  ssh-keygen -t ed25519 -N "" -C "krycy-lab" -f "$LAB_KEY" >/dev/null
}

# libvirt_on_wsl2 — czy host to WSL2 (współdzielone jądro Windows).
libvirt_on_wsl2() { grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; }

# libvirt_wsl2_check — wymagania wstępne specyficzne dla WSL2. Węzły k3s to pełne VM-ki
# KVM z własnym jądrem Ubuntu (BTF), więc Falco działa mimo braku BTF w jądrze WSL2 —
# ale potrzebna jest zagnieżdżona wirtualizacja (/dev/kvm) i systemd jako PID 1 (libvirtd).
libvirt_wsl2_check() {
  libvirt_on_wsl2 || return 0
  log "Host: WSL2 — sprawdzam zagnieżdżoną wirtualizację i systemd"
  [ -e /dev/kvm ] || die "brak /dev/kvm w WSL2: włącz nested virtualization (Windows 11, wirtualizacja w BIOS/UEFI; w %UserProfile%\\.wslconfig: [wsl2] nestedVirtualization=true), potem 'wsl --shutdown'"
  [ -r /dev/kvm ] && [ -w /dev/kvm ] || die "brak dostępu do /dev/kvm: dodaj się do grupy kvm (sudo usermod -aG kvm \$USER) i uruchom dystrybucję ponownie"
  [ "$(ps -p 1 -o comm= 2>/dev/null)" = systemd ] || die "systemd nie jest PID 1 w WSL2 — uruchom: infra/libvirt/wsl2-setup.sh, potem 'wsl --shutdown' w PowerShell"
  case "$REPO_ROOT" in
    /mnt/[a-z]/*) warn "repo leży na dysku Windows ($REPO_ROOT): bity wykonywalne i LF bywają gubione, a I/O jest wolne. Zalecane: sklonuj repo w systemie plików WSL2 (np. ~/KRYCY-26Z-k3s)";;
  esac
}

# libvirt_preflight — sprawdza narzędzia, sieć i pulę, zanim cokolwiek stworzymy.
libvirt_preflight() {
  libvirt_wsl2_check
  need virsh; need virt-install; need qemu-img; need wget; need ssh-keygen
  _vsh version >/dev/null 2>&1 || die "brak dostępu do $LIBVIRT_URI (czy jesteś w grupie 'libvirt'? wyloguj/zaloguj po dodaniu; w WSL2: infra/libvirt/wsl2-setup.sh)"
  _vsh net-info "$LIBVIRT_NET" >/dev/null 2>&1 || die "brak sieci libvirt '$LIBVIRT_NET' (utwórz/uruchom: virsh net-start default)"
  [ "$(_vsh net-info "$LIBVIRT_NET" | awk '/Active:/{print $2}')" = yes ] \
    || { log "Uruchamiam sieć $LIBVIRT_NET"; _vsh net-start "$LIBVIRT_NET" >/dev/null; }
  _vsh pool-info "$LIBVIRT_POOL" >/dev/null 2>&1 || die "brak puli dysków libvirt '$LIBVIRT_POOL'"
  [ "$(_vsh pool-info "$LIBVIRT_POOL" | awk '/State:/{print $2}')" = running ] \
    || { log "Uruchamiam pulę $LIBVIRT_POOL"; _vsh pool-start "$LIBVIRT_POOL" >/dev/null; }
  lab_key_ensure
}

# libvirt_base_image — raz pobiera obraz bazowy i wrzuca go jako wolumin do puli.
libvirt_base_image() {
  _vsh vol-info --pool "$LIBVIRT_POOL" "$BASE_VOL" >/dev/null 2>&1 && return 0
  mkdir -p "$LAB_CACHE"
  local img="$LAB_CACHE/$BASE_VOL"
  [ -s "$img" ] || { log "Pobieram obraz bazowy Ubuntu 24.04 (raz)"; wget -q --show-progress -O "$img" "$UBUNTU_IMAGE_URL"; }
  local bytes; bytes=$(stat -c %s "$img")
  log "Dodaję obraz bazowy do puli $LIBVIRT_POOL jako $BASE_VOL"
  _vsh vol-create-as "$LIBVIRT_POOL" "$BASE_VOL" "$bytes" --format qcow2 >/dev/null
  _vsh vol-upload --pool "$LIBVIRT_POOL" "$BASE_VOL" "$img"
}

# libvirt_ip WĘZEŁ — adres IPv4 VM z dzierżaw DHCP libvirta (pusty, dopóki VM nie wstanie).
libvirt_ip() {
  _vsh domifaddr "$1" --source lease 2>/dev/null \
    | awk '/ipv4/ { split($4, a, "/"); print a[1]; exit }'
}

# libvirt_wait_ssh WĘZEŁ — czeka na adres i działające SSH (cloud-init zdążył wgrać klucz).
libvirt_wait_ssh() {
  local vm=$1 ip="" i
  for i in $(seq 1 60); do
    ip=$(libvirt_ip "$vm"); [ -n "$ip" ] || { sleep 3; continue; }
    # shellcheck disable=SC2046
    if ssh $(lab_ssh_opts) "$LAB_USER@$ip" true 2>/dev/null; then
      log "VM $vm gotowa pod $ip"; return 0
    fi
    sleep 3
  done
  die "VM $vm nie odpowiedziała na SSH (adres: ${ip:-brak})"
}

# libvirt_ensure_vm NAZWA CPU RAM_GIB — tworzy albo uruchamia VM (idempotentnie).
libvirt_ensure_vm() {
  local vm=$1 cpus=$2 mem=$3 disk=${4:-30} state
  state=$(_vsh domstate "$vm" 2>/dev/null || true)
  case $state in
    running) log "VM $vm już działa" ;;
    "shut off"|paused|crashed)
      log "Uruchamiam istniejącą VM $vm"; _vsh start "$vm" >/dev/null ;;
    "")
      libvirt_base_image
      log "Tworzę VM $vm ($cpus CPU, $mem GiB RAM, $disk GiB dysk)"
      _vsh vol-create-as "$LIBVIRT_POOL" "krycy-$vm.qcow2" "${disk}G" \
        --format qcow2 --backing-vol "$BASE_VOL" --backing-vol-format qcow2 >/dev/null
      local ud; ud=$(mktemp)
      sed -e "s/__HOSTNAME__/$vm/g" \
          -e "s#__SSHKEY__#$(cat "$LAB_KEY.pub")#g" \
          "$REPO_ROOT/infra/libvirt/user-data.yaml.tpl" > "$ud"
      virt-install --connect "$LIBVIRT_URI" --name "$vm" \
        --memory "$((mem * 1024))" --vcpus "$cpus" \
        --disk vol="$LIBVIRT_POOL/krycy-$vm.qcow2",bus=virtio \
        --network network="$LIBVIRT_NET",model=virtio \
        --os-variant ubuntu24.04 --import \
        --cloud-init user-data="$ud" \
        --graphics none --noautoconsole >/dev/null
      rm -f "$ud"
      libvirt_wait_ssh "$vm" ;;
    *) die "VM $vm w stanie '$state' — napraw ręcznie (virsh list --all)" ;;
  esac
}

# libvirt_delete_all — kasuje VM-ki labu razem z ich dyskami (nie rusza obrazu bazowego).
libvirt_delete_all() {
  local n
  for n in $(all_nodes); do
    _vsh domstate "$n" >/dev/null 2>&1 || { log "VM $n nie istnieje"; continue; }
    log "Usuwam VM $n"
    _vsh destroy "$n" >/dev/null 2>&1 || true
    _vsh undefine "$n" --remove-all-storage --nvram >/dev/null 2>&1 \
      || _vsh undefine "$n" --remove-all-storage >/dev/null 2>&1 || true
  done
}
