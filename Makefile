.DEFAULT_GOAL = setup

AT    := @
ARCH  := $(shell uname -m | tr '[:upper:]' '[:lower:]')
OS    := $(shell uname -s | tr '[:upper:]' '[:lower:]')
DATE  := $(shell date +%Y-%m-%dT%T%Z)
SHELL := /usr/bin/env bash -euo pipefail -c

setup:
	$(AT) ansible-playbook ansible/vpn.yml
.PHONY: setup

sync: SRC = research/Jigsaw-Code/outline-server/src/server_manager/install_scripts
sync: DST = ansible/roles/vpn/scripts
sync:
	$(AT) git submodule update --init --recursive --remote
	$(AT) cp $(SRC)/install_server.sh $(DST)/install_outline.sh
.PHONY: sync

todo:
	$(AT) grep \
		--exclude=Makefile \
		--exclude=**/vpn/scripts/install_outline.sh \
		--exclude-dir=research \
		--color \
		--text \
		-nRo -E ' TODO:.*|SkipNow' . || true
.PHONY: todo

verbose:
	$(eval AT :=) $(eval MAKE := $(MAKE) verbose) @true
.PHONY: verbose
