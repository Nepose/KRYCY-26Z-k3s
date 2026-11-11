# Procedura IR dla klastra k3s (K.6)

Szkielet do wypełnienia. Każdy krok: **cel**, **polecenia** (najlepiej odwołanie do skryptu z repo),
**co zostaje zabezpieczone**, **czego NIE robić** (np. `kubectl delete pod` przed triage).

## 0. Przygotowanie
TODO: dostęp analityka, kubeconfig tylko do odczytu, synchronizacja czasu, gdzie trafiają dowody.

## 1. Identyfikacja
TODO: źródło alertu (Falco, audit log), ustalenie poda, węzła i service account.

## 2. Zabezpieczenie dowodów (kolejność ulotności)
TODO: `make triage NS=… POD=…`, opisać, co i w jakiej kolejności zbiera [triage.sh](../triage/triage.sh), oraz sumy SHA-256.

## 3. Izolacja (bez niszczenia dowodów)
TODO: NetworkPolicy deny-all dla poda, `kubectl cordon` węzła, odebranie uprawnień SA. Kolejność względem kroku 2.

## 4. Analiza
TODO: korelacja audit logu, Falco i dowodów z węzła; oś czasu.

## 5. Usunięcie zagrożenia i odtworzenie
TODO

## 6. Wnioski
TODO: co dodać do konfiguracji forensic readiness ([forensic-readiness.md](forensic-readiness.md)).
