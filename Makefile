# Skróty do pracy z labem. Pełny opis: README.md
SHELL := /bin/bash
export KUBECONFIG := $(CURDIR)/.kube/config

NS  ?=
POD ?=

.PHONY: help up down kubeconfig phase-a phase-b status falco falco-remove triage test lint rec

help: ## Lista poleceń
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "} {printf "  \033[36m%-13s\033[0m %s\n", $$1, $$2}'

up: ## Postaw klaster k3s (VM-ki Lima, faza A)
	infra/up.sh

down: ## Usuń klaster (pyta o potwierdzenie)
	infra/down.sh

kubeconfig: ## Odtwórz .kube/config (np. po sklonowaniu repo przy działającym klastrze)
	infra/kubeconfig.sh

phase-a: ## Faza A: domyślny k3s
	infra/phase.sh a

phase-b: ## Faza B: forensic readiness (audit log, eventy 24 h, retencja logów)
	infra/phase.sh b

status: ## Faza węzłów, węzły i pody
	@infra/phase.sh status
	@kubectl get nodes -o wide
	@kubectl get pods -A

falco: ## Zainstaluj / zaktualizuj Falco z regułami projektu
	detection/falco/install.sh

falco-remove: ## Odinstaluj Falco
	detection/falco/install.sh --uninstall

triage: ## Zabezpiecz dowody z poda: make triage NS=default POD=nazwa
	@test -n "$(NS)" -a -n "$(POD)" || { echo "Użycie: make triage NS=namespace POD=pod"; exit 2; }
	triage/triage.sh -n "$(NS)" -p "$(POD)"

test: ## Test end-to-end labu (węzły, audit log, Falco)
	tests/smoke.sh

lint: ## shellcheck wszystkich skryptów
	shellcheck -x infra/*.sh infra/node/*.sh infra/libvirt/*.sh detection/*/*.sh triage/*.sh tests/*.sh tools/*.sh

rec: ## Nagraj przebieg celu do docs/logs/ (dowód do raportu): make rec T=test
	@test -n "$(T)" || { echo "Użycie: make rec T=<cel>, np. make rec T=up"; exit 2; }
	@tools/record.sh "$(T)" $(MAKE) --no-print-directory "$(T)" NS="$(NS)" POD="$(POD)"
