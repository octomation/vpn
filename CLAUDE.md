# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Automated personal VPN deployment using Infrastructure-as-Code. Deploys an Outline VPN server (Shadowbox) via Ansible on Ubuntu cloud instances (DigitalOcean, Linode, Vultr).

## Commands

| Command | Purpose |
|---------|---------|
| `make` or `make setup` | Deploy VPN via Ansible (`ansible-playbook ansible/vpn.yml`) |
| `make sync` | Update git submodules and sync Outline install script from `research/Jigsaw-Code/outline-server` |
| `make todo` | Find TODO/SkipNow markers |

## Architecture

**Ansible-driven deployment** with two roles applied to hosts in both `vpn` and `docker` inventory groups:

1. **docker role** (`ansible/roles/docker/`) — Installs Docker CE from official repos, Docker Compose binary (v1.29.0), and Docker Python SDK (v5.0.0)
2. **vpn role** (`ansible/roles/vpn/`) — Uploads and executes the Outline Server install script with configurable hostname, ports, and container image settings. Idempotent: skips if `/opt/outline` already exists.

**Inventory** is generated from `ansible/hosts.tpl.ini` using `VPN_NAME` and `VPN_HOST` environment variables — the generated `ansible/hosts` file is gitignored.

**research/** contains git submodules (Outline Server, OpenVPN/WireGuard installers, Streisand) used for reference. The Outline install script is synced from here via `make sync`.

## Setup Workflow

```bash
git clone git@github.com:octomation/vpn.git && cd vpn
export VPN_NAME=gateway VPN_HOST=<server-ip>
cat ansible/hosts.tpl.ini | sed "s/{{.Name}}/${VPN_NAME}/g" | sed "s/{{.Host}}/${VPN_HOST}/g" > ansible/hosts
make
```

VPN credentials end up in `/opt/outline/access.txt` on the target host.
