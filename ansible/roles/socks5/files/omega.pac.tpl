// [SwitchyOmega Conditions]
// @with result
//
// *.telegram.org +proxy
// *.t.me +proxy
// *.cdn-telegram.org +proxy
//
// * +direct
var FindProxyForURL = function(init, profiles) {
    return function(url, host) {
        "use strict";
        var result = init, scheme = url.substr(0, url.indexOf(":"));
        do {
            if (!profiles[result]) return result;
            result = profiles[result];
            if (typeof result === "function") result = result(url, host, scheme);
        } while (typeof result !== "string" || result.charCodeAt(0) === 43);
        return result;
    };
}("+auto switch", {
    "+auto switch": function(url, host, scheme) {
        "use strict";
        if (/(?:^|\.)telegram\.org$/.test(host)) return "+proxy";
        if (/(?:^|\.)t\.me$/.test(host)) return "+proxy";
        if (/(?:^|\.)cdn-telegram\.org$/.test(host)) return "+proxy";
        return "DIRECT";
    },
    "+proxy": function(url, host, scheme) {
        "use strict";
        if (/^127\.0\.0\.1$/.test(host) || /^::1$/.test(host) || /^localhost$/.test(host)) return "DIRECT";
        return "SOCKS5 {{.RelayHost}}:{{.SOCKS5UnsafePort}}";
    }
});
