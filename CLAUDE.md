# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Automated personal VPN and proxy deployment using Infrastructure-as-Code.
Ansible playbooks deploy three independent setups on Ubuntu cloud instances (DigitalOcean, Linode, Vultr):

1. **Outline VPN** — single-server Shadowbox deployment
2. **Telegram proxy** — two-node relay chain (relay + gateway) to bypass DPI
3. **Monitoring** — Vector agent on all servers, shipping logs and host metrics to Grafana Cloud

## Commands

| Command | Purpose |
|---------|---------|
| `make` or `make setup` | Deploy Outline VPN via Ansible (`ansible-playbook ansible/vpn.yml`) |
| `make telegram` | Deploy Telegram proxy chain (`ansible-playbook ansible/telegram.yml`) |
| `make monitoring` | Deploy Vector monitoring agent (`ansible-playbook ansible/monitoring.yml`) |
| `make sync` | Fetch the latest Outline install script from [OutlineFoundation/outline-server](https://github.com/OutlineFoundation/outline-server) on GitHub |
| `make proxy` | Generate PAC file for macOS SOCKS proxy from template (`ansible/proxy.pac`); requires `RELAY_HOST` and `SOCKS5_UNSAFE_PORT` env vars |
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
4. **socks5** (`ansible/roles/socks5/`) — Two SOCKS5 proxy instances: `socks5` with authentication and `socks5-unsafe` without auth, both bound to `127.0.0.1` (gateway only). The `socks5-unsafe` port on the relay is firewalled to accept connections only from the VPN server IP, making it a private no-auth proxy for VPN users.
5. **gost_gateway** (`ansible/roles/gost_gateway/`) — GOST TLS relay endpoint, accepts connections only from relay IP (gateway only)
6. **gost_relay** (`ansible/roles/gost_relay/`) — GOST port forwarding over TLS tunnel to gateway (relay only)

### Proxy auto-configuration (PAC)

PAC file templates for routing Telegram traffic through the no-auth SOCKS5 proxy:

- `ansible/roles/socks5/files/proxy.pac.tpl` — macOS system proxy configuration
- `ansible/roles/socks5/files/omega.pac.tpl` — [Proxy SwitchyOmega 3](https://github.com/nicehorse06/SwitchyOmega) browser extension

`make proxy` generates `ansible/proxy.pac` from `proxy.pac.tpl` by substituting `{{.RelayHost}}` and `{{.SOCKS5UnsafePort}}`. The `omega.pac.tpl` is provided as a reference for manual import into the browser extension.

### Monitoring (all servers)

Playbook `ansible/monitoring.yml` deploys Vector to all hosts in the `docker` inventory group.

1. **vector role** (`ansible/roles/vector/`) — Deploys [Vector](https://vector.dev/) agent as a Docker container. Collects Docker container logs via `docker_logs` source and host metrics (CPU, memory, disk, network, filesystem) via `host_metrics` source. Ships logs to Grafana Cloud Loki and metrics to Grafana Cloud Prometheus via remote write.

## Inventory

Generated from `ansible/hosts.tpl.ini` using sed — the generated `ansible/hosts` file is gitignored.

Template placeholders: `{{.VpnName}}`, `{{.VpnHost}}`, `{{.RelayName}}`, `{{.RelayHost}}`, `{{.GatewayName}}`, `{{.GatewayHost}}`, `{{.MTProtoPort}}`, `{{.SOCKS5Port}}`, `{{.SOCKS5UnsafePort}}`, `{{.GostTLSPort}}`, `{{.MTGDomain}}`, `{{.SOCKS5User}}`, `{{.SOCKS5Password}}`, `{{.VectorLokiEndpoint}}`, `{{.VectorLokiUser}}`, `{{.VectorLokiApiKey}}`, `{{.VectorPrometheusEndpoint}}`, `{{.VectorPrometheusUser}}`, `{{.VectorPrometheusApiKey}}`.

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
