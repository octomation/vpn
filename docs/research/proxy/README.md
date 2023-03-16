# Proxy Solutions Research

## GOST vs sing-box

### GOST (v3)

[GOST](https://gost.run/) is a tunneling and proxying toolkit focused on
relay/chain architectures. It supports HTTP/HTTPS, SOCKS5, Shadowsocks,
TLS tunnels, and port forwarding. Configuration is YAML-based.

**Strengths:**

- Simple server-to-server relay setup (gateway + relay pattern)
- TLS-wrapped tunnels for forwarding protocols like MTProto and SOCKS5
- Lightweight, single-purpose: does one thing well

**Limitations:**

- Limited DPI circumvention (relies on generic TLS wrapping)
- No built-in DNS server
- No TUN mode (cannot act as a system-wide VPN)
- No client applications for mobile/desktop

### sing-box

[sing-box](https://sing-box.sagernet.org/) is a universal proxy platform
by SagerNet. It supports 20+ protocols and provides advanced routing,
DNS, and client applications. Configuration is JSON-based.

**Strengths:**

- Extensive protocol support: VMess, VLESS, Trojan, Hysteria2, TUIC,
  WireGuard, Shadowsocks, ShadowTLS, AnyTLS, and more
- DPI-resistant protocols (Hysteria2 over QUIC, VLESS+Reality, ShadowTLS)
  designed specifically to evade traffic analysis
- Advanced routing with GeoIP/Geosite rules, protocol sniffing,
  and split tunneling
- Built-in DNS server with DoT, DoH, DoQ, FakeIP support
- TUN mode for system-wide VPN (captures all device traffic)
- Native clients for Android, iOS, macOS, and Windows
- Built-in TLS/ACME certificate management

**Limitations:**

- More complex configuration
- GPLv3 license with additional naming restrictions

### Comparison

| Aspect              | GOST                              | sing-box                                   |
|---------------------|-----------------------------------|--------------------------------------------|
| Focus               | Tunneling and relay               | Universal proxy platform, anti-censorship  |
| Protocols           | HTTP, SOCKS5, SS, TLS tunnels     | 20+ (VMess, VLESS, Trojan, Hysteria2, ...) |
| DPI circumvention   | Limited (TLS wrapping)            | Purpose-built (ShadowTLS, Hysteria2, TUIC) |
| Routing             | Simple chains                     | GeoIP, Geosite, sniffing, rule sets        |
| DNS                 | None                              | Full server (FakeIP, DoH, DoQ)             |
| TUN (system VPN)    | No                                | Yes                                        |
| Client apps         | No (server/CLI only)              | Android, iOS, macOS, Windows               |
| Configuration       | YAML                              | JSON                                       |
| Architecture        | Server-to-server relay            | Client-server (also server-to-server)      |

### When to use which

**GOST** works well for server-to-server relay scenarios: forwarding
traffic (e.g., MTProto, SOCKS5) through a TLS tunnel between two hosts.
Simple and predictable.

**sing-box** is the better choice when:

- DPI circumvention is required (Hysteria2, VLESS+Reality, ShadowTLS)
- Client apps on phones/desktops are needed with TUN mode
- Smart routing is desired (e.g., domestic traffic direct, rest via proxy)
- Consolidating multiple services (Outline + GOST + mtg) into one
