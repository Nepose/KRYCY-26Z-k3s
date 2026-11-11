# Scenariusz 1: ucieczka z kontenera przez privileged pod

| | |
|---|---|
| Wymagania | K.2, K.3 |
| ATT&CK for Containers | T1610 Deploy Container, T1611 Escape to Host |
| Punkt startowy atakującego | TODO, np. konto z prawem `create pods` w namespace `dev` |
| Status | ☐ wykonanie ☐ faza A ☐ faza B ☐ wpis w macierzy dowodów |

## Wykonanie

TODO: manifesty i `run.sh` w tym katalogu.

Kierunek: pod z `securityContext.privileged: true` i `hostPID: true`, potem
`nsenter --target 1 --mount --uts --ipc --net --pid -- bash` i działania na węźle
(np. odczyt `/var/lib/rancher/k3s/server/token`, persystencja przez crona albo usługę systemd).

## Obserwacje

### Faza A (domyślny k3s)
TODO: co zostało po usunięciu poda? (audit log: brak; logi poda; journal; pliki na węźle)

### Faza B (forensic readiness)
TODO: audit log (utworzenie poda z `privileged`), zdarzenia Falco (np. reguły dot. `nsenter`, powłoki w kontenerze)

## Luki widoczności
TODO: czego nie widać nawet w fazie B? (np. działania po ucieczce, wykonywane już jako procesy hosta)

## Metoda zebrania
TODO, wynik zbiorczy: [docs/evidence-matrix.md](../../docs/evidence-matrix.md)
