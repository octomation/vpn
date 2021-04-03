.DEFAULT_GOAL = setup

AT    := @
ARCH  := $(shell uname -m | tr '[:upper:]' '[:lower:]')
OS    := $(shell uname -s | tr '[:upper:]' '[:lower:]')
DATE  := $(shell date +%Y-%m-%dT%T%Z)
SHELL := /usr/bin/env bash -euo pipefail -c

verbose:
	$(eval AT :=)
	@echo >/dev/null
.PHONY: verbose

setup:
	$(AT) ansible-playbook ansible/vpn.yml
.PHONY: setup

copy: SRC = research/Jigsaw-Code/outline-server/src/server_manager/install_scripts
copy: DST = ansible/roles/vpn/scripts
copy:
	$(AT) cp $(SRC)/install_server.sh $(DST)/install_outline.sh
.PHONY: copy

reset:
	# docker rm -f shadowbox watchtower && rm -rf /opt/outline
.PHONY: reset
