# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Automated personal VPN and proxy deployment using Infrastructure-as-Code.
Ansible playbooks deploy two independent setups on Ubuntu cloud instances (DigitalOcean, Linode, Vultr):

1. **Outline VPN** — single-server Shadowbox deployment
2. **Telegram proxy** — two-node relay chain (relay + gateway) to bypass DPI

## Commands

| Command | Purpose |
|---------|---------|
| `make` or `make setup` | Deploy Outline VPN via Ansible (`ansible-playbook ansible/vpn.yml`) |
| `make telegram` | Deploy Telegram proxy chain (`ansible-playbook ansible/telegram.yml`) |
| `make sync` | Fetch the latest Outline install script from [OutlineFoundation/outline-server](https://github.com/OutlineFoundation/outline-server) on GitHub |
| `make todo` | Find TODO/SkipNow markers |

## Architecture

### Outline VPN (single-server)

Playbook `ansible/vpn.yml` targets hosts in both `vpn` and `docker` inventory groups:

1. **docker role** (`ansible/roles/docker/`) — Installs Docker CE from official repos, docker-compose-plugin, and Docker Python SDK (v7.1.0)
2. **vpn role** (`ansible/roles/vpn/`) — Uploads and executes the Outline Server install script with configurable hostname, ports, and container image settings. Idempotent: skips if `/opt/outline` already exists.

### Telegram proxy (two-node chain)

Playbook `ansible/telegram.yml` deploys a relay + gateway pair. Traffic from clients reaches the relay server (in an allowed zone), which wraps it in TLS via GOST v3 and forwards to the gateway server (outside perimeter), where MTProto and SOCKS5 proxies run on localhost.

Roles applied in order:

1. **common** (`ansible/roles/common/`) — UFW firewall setup, base packages (applied to both relay and gateway)
2. **docker** (`ansible/roles/docker/`) — Docker CE and plugins (applied to both relay and gateway)
3. **mtg** (`ansible/roles/mtg/`) — MTProto proxy for Telegram, bound to `127.0.0.1` (gateway only)
4. **socks5** (`ansible/roles/socks5/`) — SOCKS5 proxy with authentication, bound to `127.0.0.1` (gateway only)
5. **gost_gateway** (`ansible/roles/gost_gateway/`) — GOST TLS relay endpoint, accepts connections only from relay IP (gateway only)
6. **gost_relay** (`ansible/roles/gost_relay/`) — GOST port forwarding over TLS tunnel to gateway (relay only)

## Inventory

Generated from `ansible/hosts.tpl.ini` using sed — the generated `ansible/hosts` file is gitignored.

Template placeholders: `{{.VpnName}}`, `{{.VpnHost}}`, `{{.RelayName}}`, `{{.RelayHost}}`, `{{.GatewayName}}`, `{{.GatewayHost}}`, `{{.MTProtoPort}}`, `{{.SOCKS5Port}}`, `{{.GostTLSPort}}`, `{{.MTGDomain}}`, `{{.SOCKS5User}}`, `{{.SOCKS5Password}}`.

## Setup Workflow

### Outline VPN

```bash
git clone git@github.com:octomation/breakout.git && cd breakout
export VPN_NAME=gateway VPN_HOST=<server-ip>
cat ansible/hosts.tpl.ini | sed "s/{{.VpnName}}/${VPN_NAME}/g" | sed "s/{{.VpnHost}}/${VPN_HOST}/g" > ansible/hosts
make
```

VPN credentials end up in `/opt/outline/access.txt` on the target host.

### Telegram proxy

See README.md for full sed command with all placeholders, then run `make telegram`.

## Research

**docs/research/** contains notes on VPN and proxy solutions. The Outline install script is fetched directly from GitHub via `make sync`.
