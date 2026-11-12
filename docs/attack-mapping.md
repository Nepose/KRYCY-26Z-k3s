# Reguły detekcji i mapowanie na ATT&CK for Containers (K.7, nice-to-have)

| Reguła (Falco) | Technika ATT&CK | Scenariusz | Przetestowana |
|---|---|---|---|
| `KRYCY Odczyt tokenu ServiceAccount przez narzędzie powłoki` | T1528 Steal Application Access Token | 2 | ✅ `tests/smoke.sh`, [przykładowe zdarzenie](logs/sample-falco-sa-token-read.json) |
| `KRYCY Ucieczka z kontenera przez nsenter` | T1611 Escape to Host | 1 | ☐ do przebiegu na Macu |
| TODO | T1496 Resource Hijacking | 3 | |
| TODO | T1552.007 Unsecured Credentials: Container API | 4 | |

Reguły: [detection/falco/rules/krycy-rules.yaml](../detection/falco/rules/krycy-rules.yaml).
Warto też wskazać, które reguły **domyślne** Falco wykrywają poszczególne scenariusze.
