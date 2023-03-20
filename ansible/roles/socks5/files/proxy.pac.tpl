function FindProxyForURL(url, host) {
    if (shExpMatch(host, "*.telegram.org") ||
        shExpMatch(host, "telegram.org")   ||
        shExpMatch(host, "*.t.me")         ||
        shExpMatch(host, "t.me")           ||
        shExpMatch(host, "*.cdn-telegram.org")) {
        return "SOCKS5 {{.RelayHost}}:{{.SOCKS5UnsafePort}}; SOCKS {{.RelayHost}}:{{.SOCKS5UnsafePort}}; DIRECT";
    }
    return "DIRECT";
}
