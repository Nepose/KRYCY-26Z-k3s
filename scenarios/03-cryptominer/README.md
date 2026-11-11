# Scenariusz 3: kryptokoparka

| | |
|---|---|
| Wymagania | K.2, K.3 |
| ATT&CK for Containers | T1496 Resource Hijacking, T1610 Deploy Container |
| Punkt startowy atakującego | TODO, np. przejęty token z prawem tworzenia Deploymentów |
| Status | ☐ wykonanie ☐ faza A ☐ faza B ☐ wpis w macierzy dowodów |

> **Tylko symulacja.** Nie łączymy się z prawdziwą pulą wydobywczą (względy etyczne i regulaminy dostawców).
> Wystarczy obciążenie CPU, binarka o nazwie typowej dla koparki, zapytanie DNS o domenę puli
> oraz połączenie na port stratum (np. 3333) do lokalnego fałszywego serwera w klastrze.

## Wykonanie

TODO: manifesty i `run.sh`.

## Obserwacje

### Faza A (domyślny k3s)
TODO: co zostaje po `kubectl delete deployment`? (metryki CPU nie są przechowywane, logi giną z podem)

### Faza B (forensic readiness)
TODO: audit log (kto utworzył Deployment), Falco (połączenia na porty stratum, DNS do domen pul)

## Luki widoczności
TODO

## Metoda zebrania
TODO: `triage.sh` zabiera zapisywalną warstwę FS (`container-*-upperdir.tar`), czyli podrzuconą binarkę,
i gniazda sieciowe kontenera. Wynik zbiorczy: [docs/evidence-matrix.md](../../docs/evidence-matrix.md)
