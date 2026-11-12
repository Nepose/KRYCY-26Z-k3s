# Decyzje projektowe

## D-001: lab na VM-kach Lima zamiast na VPS-ie (2026-11-11)

**Kontekst.** Pierwotny plan zakładał klaster na prywatnym VPS-ie zespołu.

**Ustalenia.** VPS okazał się nieuprzywilejowanym kontenerem LXC (`systemd-detect-virt` → `lxc`,
`/proc/self/uid_map` → `0 26600000 65536`), z jądrem współdzielonym z hostem dostawcy:
- wywołanie `bpf()` (`BPF_MAP_CREATE`) kończy się `EPERM`, mimo że w przestrzeni nazw widać `CAP_BPF`
  (uprawnienia działają tylko wewnątrz user namespace), więc **Falco i Tetragon nie ruszą** (K.4, K.8),
- brak `/dev/kmsg` (wymagany przez kubelet) i `/dev/kvm` (nie da się uruchomić VM-ki wewnątrz),
- CRIU / checkpointy kontenerów niedostępne (X.1),
- na tej samej maszynie działają inne usługi, a API k3s (6443) byłoby na publicznym IP bez firewalla.

**Decyzja.** Klaster na VM-kach Lima (Apple Virtualization.framework) na Macu: pełne jądro Ubuntu 24.04
z BTF, izolacja od hosta (tryb `plain`, bez montowania katalogu domowego). Skrypty węzła są niezależne
od Limy (`TRANSPORT=ssh`), więc lab można przenieść na dowolny host z pełną wirtualizacją (KVM).

**Wniosek do raportu.** Sam typ wirtualizacji węzła decyduje o dostępności telemetrii runtime.
To argument w rekomendacjach forensic readiness (K.5).

## D-002: sieć labu, user-v2 jako eth0 i vzNAT tylko dla hosta (2026-11-11)

**Kontekst.** Pierwsza wersja używała jednej sieci vzNAT (NAT vmnet macOS) do wszystkiego.

**Ustalenia (Mac zespołu, macOS 26.6).** W sieci vzNAT działa ruch host↔VM, ale **VM↔VM i VM→internet
są blokowane** (prawdopodobnie firewall macOS albo VPN):
- `curl --interface lima0` (w pierwszej wersji: vzNAT) do GitHuba: timeout; ten sam `curl --interface eth0` (usernet): HTTP 301,
- agent k3s: `failed to get CA certs … read tcp …` przy łączeniu z `192.168.64.2:6443`, `ping` VM→VM: brak odpowiedzi,
- `curl` z Maca do `https://192.168.64.2:6443/cacerts`: HTTP 200.

**Decyzja.** Dwa interfejsy w VM-ce ([infra/lima/node.yaml](../infra/lima/node.yaml)):
`eth0` to sieć Limy `user-v2` (w przestrzeni użytkownika; zastępuje domyślny usernet) dla internetu
oraz k3s i flannela, `lima1` (vzNAT) wyłącznie dla `kubectl` z Maca. Certyfikat API dostaje adres
z `lima1` (`tls-san`). Sprawdzone: agent (192.168.104.3) pinguje serwer (192.168.104.1), a `curl` do GitHuba z VM-ki zwraca HTTP 301.


## D-003: port na Linux przez libvirt/KVM (TRANSPORT=libvirt) (2026-11-12)

**Kontekst.** Lab powstał na macOS (Lima/Apple vz). Część zespołu pracuje na Linuksie, a VM-ki
Lima na Macu nie są dla nich dostępne. Potrzebna była natywna ścieżka linuksowa, która nie dubluje
skryptów węzła.

**Ustalenia.** Mac-specyficzna jest wyłącznie warstwa hosta (stacja analityka): `limactl`, szablon
[node.yaml](../infra/lima/node.yaml) i macowy hack sieciowy z D-002. Skrypty węzła
([infra/node/](../infra/node/)) są czysto linuksowe (ip, systemd, k3s) i działają bez zmian.
Istniejąca ścieżka `TRANSPORT=ssh` już dowodziła tej niezależności.

**Decyzja.** Dodany `TRANSPORT=libvirt`: VM-ki Ubuntu 24.04 stawiane przez `virt-install` + cloud-init
([provision.sh](../infra/libvirt/provision.sh), [user-data.yaml.tpl](../infra/libvirt/user-data.yaml.tpl)),
dostęp do węzłów po SSH jako `krycy` dedykowanym kluczem (`.lab/`, poza gitem). W odróżnieniu od D-002
**nie ma drugiej karty**: NAT libvirta jest widoczny także z hosta, więc jeden interfejs obsługuje
host↔VM, VM↔VM i VM→internet, a `NODE_IFACE`/`API_IFACE` są puste (adres z trasy domyślnej).
Ścieżka Limy pozostaje nietknięta (provisioner sourcowany tylko dla `TRANSPORT=libvirt`).

**Status.** Kod napisany i sprawdzony składniowo (`bash -n`, `make lint`). Pełny przebieg
`make up && make test` na realnym hoście Linux z libvirt — do wykonania; wynik i ewentualne
poprawki (os-variant, opcje `virt-install`, czas pobierania obrazu) dopisać tutaj.

**WSL2 jako host (Windows).** WSL2 nie jest osobnym transportem — jest hostem ścieżki `libvirt`.
Węzły k3s to pełne VM-ki KVM z własnym jądrem Ubuntu (BTF), więc Falco działa **mimo** że
współdzielone jądro WSL2 zwykle nie ma `CONFIG_DEBUG_INFO_BTF` (to ten sam problem co w D-001 z LXC,
tylko rozwiązany zagnieżdżoną wirtualizacją, a nie rezygnacją z telemetrii). Warunki: nested virt
(`/dev/kvm`) i systemd jako PID 1. Konfiguruje je [wsl2-setup.sh](../infra/libvirt/wsl2-setup.sh),
a `libvirt_preflight` sprawdza je przed stawianiem VM. Repo musi być w FS WSL2 (nie `/mnt/c`).

**Wniosek do raportu.** Rozdział „host vs węzeł” w architekturze labu opłacił się: dodanie podłoża
to jeden plik provisionera i trzy gałęzie `case`, bez ruszania detekcji, scenariuszy ani triage.
WSL2 doszedł jako wyłącznie zestaw wymagań wstępnych, bez zmian w logice stawiania klastra.
