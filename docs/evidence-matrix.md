# Macierz dowodów (K.3)

Główny wynik badania: dla każdego scenariusza, jakie dowody są dostępne w fazie A (domyślny k3s)
i w fazie B (forensic readiness), czego nie widać i jak to zebrać.

Legenda: ✅ dostępne · ⚠️ częściowo / tylko gdy pod jeszcze istnieje · ❌ brak

## Źródła dowodów

| Źródło | Faza A | Faza B | Ginie, gdy… |
|---|---|---|---|
| Audit log API servera | ❌ wyłączony | ✅ | rotacja (30 dni / 10 × 100 MB), utrata węzła serwera |
| Eventy Kubernetesa | ⚠️ 1 h | ⚠️ 24 h | minie TTL |
| Logi kontenerów (`/var/log/pods`) | ⚠️ | ⚠️ większa retencja | usunięcie poda |
| Zapisywalna warstwa FS kontenera | ⚠️ | ⚠️ | usunięcie kontenera |
| Procesy, syscalle, połączenia | ❌ | ✅ Falco | (w fazie B zapisane w logu Falco) |
| Journal k3s na węźle | ✅ | ✅ | utrata węzła, rotacja journald |
| Pamięć procesu | ❌ | ❌ (X.1: checkpoint CRIU) | restart lub usunięcie kontenera |

TODO: zweryfikować każdy wiersz eksperymentalnie, z dowodem (zrzut lub wycinek z `evidence/`).

## Scenariusze

| Scenariusz | Dowody: faza A | Dowody: faza B | Luki widoczności | Metoda zebrania |
|---|---|---|---|---|
| 1. Privileged pod → host | TODO | TODO | TODO | TODO |
| 2. Nadużycie SA | TODO | TODO | TODO | TODO |
| 3. Kryptokoparka | TODO | TODO | TODO | TODO |
| 4. Sekrety w env | TODO | TODO | TODO | TODO |
