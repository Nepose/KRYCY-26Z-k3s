# Scenariusz 2: nadużycie service account

| | |
|---|---|
| Wymagania | K.2, K.3 |
| ATT&CK for Containers | T1528 Steal Application Access Token, T1613 Container and Resource Discovery |
| Punkt startowy atakującego | TODO, np. RCE w aplikacji działającej w podzie z nadmiarowym RoleBindingiem |
| Status | ☐ wykonanie ☐ faza A ☐ faza B ☐ wpis w macierzy dowodów |

## Wykonanie

TODO: manifesty (aplikacja + ServiceAccount + zbyt szeroki Role/ClusterRoleBinding) i `run.sh`.

Kierunek: odczyt `/var/run/secrets/kubernetes.io/serviceaccount/token`, rozpoznanie uprawnień
(`kubectl auth can-i --list` albo `curl` do API), potem nadużycie (np. odczyt sekretów, utworzenie poda).

Gotowa reguła Falco dla tego kroku: `KRYCY Odczyt tokenu ServiceAccount przez narzędzie powłoki`
([detection/falco/rules/krycy-rules.yaml](../../detection/falco/rules/krycy-rules.yaml)).

## Obserwacje

### Faza A (domyślny k3s)
TODO: hipoteza do sprawdzenia: działania przez API są praktycznie niewidoczne.

### Faza B (forensic readiness)
TODO: audit log (`user.username = system:serviceaccount:…`, `sourceIPs`, `selfsubjectrulesreviews`), Falco

## Luki widoczności
TODO

## Metoda zebrania
TODO, wynik zbiorczy: [docs/evidence-matrix.md](../../docs/evidence-matrix.md)
