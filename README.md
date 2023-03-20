> # ✊ Breakout
>
> Easy way to escape environment limitations.

## 💡 Idea

Nothing special, just to find a way to set up VPN and proxy with ease.

## 🏆 Motivation

Internet censorship has been increasing steadily for the last decade. Needs more?
[10 reasons why you need a VPN](https://www.techradar.com/news/10-reasons-why-you-need-a-vpn).

## 🏗️ Architecture

### Outline VPN (single-server)

A single server running [Outline VPN](https://www.getoutline.org/) (Shadowbox) inside Docker
with automatic updates via Watchtower.

```bash
$ make setup
```

### Telegram proxy (two-node chain)

A two-node relay scheme for Telegram designed to bypass deep packet inspection (DPI).
Direct connections to proxy servers outside the allowed zone are blocked by ISPs,
so traffic is routed through an intermediate relay server inside the allowed zone.

```mermaid
flowchart LR
    Client["Telegram client"]
    Relay["Relay server<br/>(allowed zone)"]
    Gateway["Gateway server<br/>(outside perimeter)"]
    TG["Telegram DCs"]

    Client -- "TCP" --> Relay
    Relay -- "TLS tunnel<br/>(looks like HTTPS)" --> Gateway
    Gateway --> TG
```

#### How it works

```mermaid
flowchart TB
    subgraph Relay ["Relay server"]
        GR["gost-relay<br/>listens on mtproto_port, socks5_port"]
    end

    subgraph Gateway ["Gateway server"]
        GB["gost-gateway<br/>TLS relay on gost_tls_port"]
        MTG["mtg<br/>MTProto proxy<br/>127.0.0.1:mtproto_port"]
        SOCKS["socks5<br/>SOCKS5 proxy<br/>127.0.0.1:socks5_port"]
    end

    Client["Telegram client"] -- "MTProto or SOCKS5" --> GR
    GR -- "relay over TLS" --> GB
    GB -- "localhost" --> MTG
    GB -- "localhost" --> SOCKS
    MTG --> TG["Telegram DCs"]
    SOCKS --> TG
```

**Relay server** accepts client connections and wraps them in a TLS tunnel using
[GOST v3](https://github.com/go-gost/gost). For DPI, this traffic looks like regular HTTPS.

**Gateway server** runs two proxy services, both bound to `127.0.0.1` only (not exposed externally):

| Service | Image | Purpose |
|---------|-------|---------|
| [mtg](https://github.com/9seconds/mtg) | `nineseconds/mtg:2` | MTProto proxy for Telegram |
| [socks5](https://github.com/serjs/socks5-server) | `serjs/go-socks5-proxy` | SOCKS5 proxy with authentication |
| socks5-unsafe | `serjs/go-socks5-proxy` | SOCKS5 proxy without auth (VPN IP-whitelisted) |

GOST's relay protocol multiplexes MTProto and both SOCKS5 streams
through a **single TLS connection** on one port.

The `socks5-unsafe` instance has no authentication but is protected by a UFW rule
on the relay server that only allows connections from the VPN server IP.
This lets you use it as a private proxy when connected to the VPN — no credentials needed.

#### Firewall rules

```mermaid
flowchart LR
    subgraph Relay ["Relay server (UFW)"]
        direction TB
        R22["22/tcp SSH ✓"]
        RM["mtproto_port/tcp ✓"]
        RS["socks5_port/tcp ✓"]
        RU["socks5_unsafe_port/tcp<br/>only from VPN IP ✓"]
    end

    subgraph Gateway ["Gateway server (UFW)"]
        direction TB
        B22["22/tcp SSH ✓"]
        BT["gost_tls_port/tcp<br/>only from relay IP ✓"]
        BM["mtproto_port ✗<br/>localhost only"]
        BS["socks5_port ✗<br/>localhost only"]
        BU["socks5_unsafe_port ✗<br/>localhost only"]
    end

    Internet -- "clients" --> Relay
    Relay -- "TLS" --> BT
```

#### Deployment

```bash
$ make telegram
```

#### Telegram client configuration

**MTProto** (native, no password required):
- Server: `<relay_ip>`
- Port: `<mtproto_port>`
- Secret: printed during deployment, also stored at `/opt/mtg/secret` on gateway

Or use a link: `tg://proxy?server=<relay_ip>&port=<mtproto_port>&secret=<secret>`

**SOCKS5** (universal):
- Server: `<relay_ip>`
- Port: `<socks5_port>`
- Username / Password: as configured in inventory

**SOCKS5 without auth** (requires VPN connection):
- Server: `<relay_ip>`
- Port: `<socks5_unsafe_port>`
- No credentials needed — relay firewall only allows traffic from the VPN server IP

#### Proxy auto-configuration (PAC)

For convenient use of the no-auth SOCKS5 proxy, two PAC file templates are provided:

| Template | Purpose |
|----------|---------|
| `ansible/roles/socks5/files/proxy.pac.tpl` | macOS system proxy (System Settings → Network → Proxies → Automatic Proxy Configuration) |
| `ansible/roles/socks5/files/omega.pac.tpl` | [Proxy SwitchyOmega 3](https://github.com/zero-peak/ZeroOmega) browser extension (PAC profile) |

Generate the macOS PAC file:

```bash
$ export RELAY_HOST=<relay_ip> SOCKS5_UNSAFE_PORT=<port>
$ make proxy
```

Both templates route Telegram domains (`*.telegram.org`, `*.t.me`, `*.cdn-telegram.org`)
through the SOCKS5 proxy and send everything else directly.

### Monitoring (all servers)

[Vector](https://vector.dev/) agent deployed as a Docker container on every server.
Collects Docker container logs and host metrics (CPU, memory, disk, network),
ships them to [Grafana Cloud](https://grafana.com/products/cloud/) (Loki for logs, Prometheus for metrics).

```bash
$ make monitoring
```

Requires Grafana Cloud credentials configured in the inventory
(see `{{.VectorLoki*}}` and `{{.VectorPrometheus*}}` placeholders in `ansible/hosts.tpl.ini`).

## How to

### Outline VPN

```bash
$ export VPN_NAME=gateway   # your server name, any way you like
$ export VPN_HOST=127.0.0.1 # your server ip

$ cat ansible/hosts.tpl.ini \
  | sed "s/{{.VpnName}}/${VPN_NAME}/g" \
  | sed "s/{{.VpnHost}}/${VPN_HOST}/g" \
  > ansible/hosts

$ make
```

### Telegram proxy

Fill in all template placeholders in `ansible/hosts.tpl.ini` and generate the inventory:

```bash
$ cat ansible/hosts.tpl.ini \
  | sed "s/{{.VpnName}}/${VPN_NAME}/g" \
  | sed "s/{{.VpnHost}}/${VPN_HOST}/g" \
  | sed "s/{{.RelayName}}/${RELAY_NAME}/g" \
  | sed "s/{{.RelayHost}}/${RELAY_HOST}/g" \
  | sed "s/{{.GatewayName}}/${GATEWAY_NAME}/g" \
  | sed "s/{{.GatewayHost}}/${GATEWAY_HOST}/g" \
  | sed "s/{{.MTProtoPort}}/${MTPROTO_PORT}/g" \
  | sed "s/{{.SOCKS5Port}}/${SOCKS5_PORT}/g" \
  | sed "s/{{.SOCKS5UnsafePort}}/${SOCKS5_UNSAFE_PORT}/g" \
  | sed "s/{{.GostTLSPort}}/${GOST_TLS_PORT}/g" \
  | sed "s/{{.MTGDomain}}/${MTG_DOMAIN}/g" \
  | sed "s/{{.SOCKS5User}}/${SOCKS5_USER}/g" \
  | sed "s/{{.SOCKS5Password}}/${SOCKS5_PASSWORD}/g" \
  | sed "s/{{.VectorLokiEndpoint}}/${VECTOR_LOKI_ENDPOINT}/g" \
  | sed "s/{{.VectorLokiUser}}/${VECTOR_LOKI_USER}/g" \
  | sed "s/{{.VectorLokiApiKey}}/${VECTOR_LOKI_API_KEY}/g" \
  | sed "s/{{.VectorPrometheusEndpoint}}/${VECTOR_PROMETHEUS_ENDPOINT}/g" \
  | sed "s/{{.VectorPrometheusUser}}/${VECTOR_PROMETHEUS_USER}/g" \
  | sed "s/{{.VectorPrometheusApiKey}}/${VECTOR_PROMETHEUS_API_KEY}/g" \
  > ansible/hosts

$ make telegram
```

### Recommended providers

| Provider           | Availability | IPv6 | Price      |
|:-------------------|:-------------|:----:|-----------:|
| [DigitalOcean][do] | worldwide    |  ✓   | $5/month   |
| [Linode][linode]   | worldwide    |  ✓   | $5/month   |
| [Vultr][vultr]     | worldwide    |  ✓   | $2.5/month |

<small>☝️ all links are referral</small>

## 🧩 Installation

```bash
$ git clone git@github.com:octomation/breakout.git && cd breakout
```

<p align="right">made with ❤️ for everyone</p>

[do]:     http://bit.ly/vps-do-ref
[linode]: http://bit.ly/vps-linode-ref
[vultr]:  http://bit.ly/vps-vultr-ref
