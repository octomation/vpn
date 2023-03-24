# Security Audit: Ansible Infrastructure

## Overview

This document captures a security audit of the Ansible playbooks and roles
that deploy a personal VPN and proxy infrastructure (Outline VPN, Telegram
proxy chain, Vector monitoring) across Ubuntu cloud instances.

**Overall assessment:** the configuration is reasonable for personal-use
infrastructure. Key architectural decisions (localhost binding, UFW IP
filtering, TLS tunnel via GOST) provide layered protection. The areas below
are ordered by severity and each includes mitigation options sorted by
effort-to-benefit ratio (best trade-off first).

---

## 1. Secrets Management

### 1.1 No encryption of secrets at rest

**Severity:** Medium

All sensitive data (SOCKS5 passwords, Grafana API keys) lives as plaintext
in `ansible/hosts`. The file is gitignored, which prevents leaking to the
repository, but it sits unprotected on the operator's machine and on any
backup media.

**Mitigations (best trade-off first):**

1. **Ansible Vault for variable files** — encrypt a `group_vars/*/vault.yml`
   file per group and reference vault variables in inventory. Minimal
   workflow change: add `--ask-vault-pass` or a vault password file to the
   `ansible-playbook` invocation.
2. **SOPS + age** — encrypt variable files with
   [SOPS](https://github.com/getsops/sops) using age keys. Integrates with
   git (encrypted files can be committed safely) and does not require
   Ansible Vault infrastructure.
3. **External secrets manager (HashiCorp Vault, 1Password CLI)** — fetch
   secrets at runtime via lookup plugins. More operational overhead; makes
   sense if the secret count grows or multiple operators are involved.

### 1.2 Secrets printed to stdout

**Severity:** Medium

Two tasks output secret material to the terminal (and potentially to CI logs
or shell history):

- `ansible/roles/mtg/tasks/main.yml` — debug task prints the MTProto secret.
- `ansible/roles/vpn/tasks/main.yml` — debug task prints Outline access URL
  with embedded keys.

**Mitigations (best trade-off first):**

1. **Replace debug with a file fetch** — use `ansible.builtin.fetch` to pull
   the secret file to the operator's machine (e.g., `./secrets/mtg_secret`).
   The secret never appears in stdout.
2. **Gate debug output behind a variable** — wrap in
   `when: show_secrets | default(false)` so secrets are hidden by default and
   only shown with `-e show_secrets=true`.
3. **Use `no_log: true`** — prevents Ansible from logging the task output at
   all. Downside: harder to debug when something goes wrong.

---

## 2. Network Security

### 2.1 GOST TLS without mutual authentication

**Severity:** Medium

The GOST gateway accepts any TLS client connection on port 443. The only
access control is the UFW rule restricting the port to the relay server's IP.
If the relay IP is spoofed or the relay host is compromised, the gateway is
exposed.

**Mitigations (best trade-off first):**

1. **Add GOST-level authentication** — GOST v3 supports `auth` blocks with
   username/password on relay handlers. Low effort: add credentials to the
   gateway config and reference them on the relay side.
2. **Mutual TLS (mTLS)** — generate a CA, issue client certificates for the
   relay, and configure GOST to verify them. Stronger guarantee, but
   requires certificate lifecycle management.
3. **WireGuard tunnel between relay and gateway** — run GOST over a
   WireGuard link instead of raw TLS. Provides both authentication and
   encryption with minimal config, but adds another service to maintain.

### 2.2 GOST uses self-signed TLS certificates

**Severity:** Low

GOST v3 auto-generates self-signed certificates by default. For an internal
relay-to-gateway channel this is acceptable, but without certificate pinning
a theoretical MITM is possible if an attacker can intercept traffic between
the two servers.

**Mitigations (best trade-off first):**

1. **Pin the certificate fingerprint on the relay side** — GOST supports
   `tls.secure: false` with custom CA bundles; export the gateway cert and
   reference it in the relay config.
2. **Use Let's Encrypt certificates** — if the gateway has a DNS name, GOST
   can serve real certificates. Eliminates the self-signed concern entirely
   but requires DNS setup and renewal automation.

### 2.3 SSH is not hardened

**Severity:** Medium

Playbooks do not configure sshd: password authentication may be enabled,
root login is unrestricted, and there is no brute-force protection.

**Mitigations (best trade-off first):**

1. **Install and enable fail2ban** — add a task to the `common` role. Blocks
   IPs after repeated failed login attempts. Minimal config, immediate
   benefit.
2. **Harden sshd_config via Ansible** — disable `PasswordAuthentication`,
   set `PermitRootLogin prohibit-password` (key-only), restrict ciphers and
   MACs. Deploy with a handler to reload sshd.
3. **Create a dedicated deploy user** — stop using `root` for Ansible;
   create a user with passwordless `sudo`, disable root login entirely.
   More disruptive to the current workflow.

### 2.4 Root SSH access

**Severity:** Medium

```ini
[ubuntu:vars]
ansible_user=root
```

Direct root login widens the attack surface. If SSH keys are compromised,
the attacker has immediate root access with no privilege escalation step.

**Mitigations (best trade-off first):**

1. **Set `PermitRootLogin prohibit-password`** — keeps key-based root login
   (no workflow change) but blocks password brute-force. One sshd_config
   line.
2. **Create a deploy user with sudo** — `ansible_user=deploy`,
   `ansible_become=true`. Adds an audit trail and limits blast radius of
   a compromised SSH key.

---

## 3. Docker Security

### 3.1 Docker socket mounted in Vector container

**Severity:** Medium

```yaml
- /var/run/docker.sock:/var/run/docker.sock:ro
```

Even read-only access to the Docker socket lets Vector inspect all
containers, their environment variables (including `PROXY_USER`,
`PROXY_PASSWORD`), volumes, and network config. If Vector is compromised,
full visibility into the infrastructure is exposed.

**Mitigations (best trade-off first):**

1. **Accept the risk with documentation** — Vector requires Docker socket
   access for the `docker_logs` source. This is the standard deployment
   model. Document the trust boundary: Vector is a monitoring agent with
   read access to container metadata by design.
2. **Use Docker API proxy** — run a filtering proxy like
   [tecnativa/docker-socket-proxy](https://github.com/Tecnativa/docker-socket-proxy)
   that only exposes the endpoints Vector needs (containers, logs). Blocks
   exec, build, and other dangerous operations.
3. **Switch to file-based log collection** — configure Docker to log to
   files (`json-file` driver) and point Vector at the log directory instead
   of the socket. Loses container metadata enrichment.

### 3.2 Docker images not pinned by digest

**Severity:** Medium

```yaml
vector_image: "timberio/vector:latest-alpine"
socks5_image: "serjs/go-socks5-proxy:latest"
gost_image: "gogost/gost:3"
```

`latest` and major-version tags can silently pull a different image on the
next `docker pull`, introducing untested or even malicious code.

**Mitigations (best trade-off first):**

1. **Pin to specific minor/patch version tags** — e.g.,
   `timberio/vector:0.40.1-alpine`, `gogost/gost:3.0.0`. Easy to update
   manually; prevents surprise changes.
2. **Pin by SHA256 digest** — e.g., `image@sha256:abc123...`. Guarantees
   byte-identical image on every pull. Harder to read and update.
3. **Use Dependabot / Renovate** — automate image version updates with PRs.
   Only useful if combined with version pinning.

### 3.3 network_mode: host for GOST containers

**Severity:** Low (acceptable)

Both GOST containers run with `network_mode: host`, which removes network
namespace isolation. This is required for the port-forwarding use case and
is acceptable here.

**Mitigations (best trade-off first):**

1. **Accept with documentation** — host networking is the intended
   deployment model for GOST relay/gateway. Document that these containers
   share the host network stack.
2. **Publish only required ports** — if GOST can work without host
   networking, switch to explicit port mapping. This would require testing
   with the TLS tunnel setup.

### 3.4 No health checks in docker-compose

**Severity:** Low

Containers use `restart: always` without `healthcheck`. A service can hang
in a broken state and restart indefinitely without detection.

**Mitigations (best trade-off first):**

1. **Add healthcheck to docker-compose templates** — simple TCP or HTTP
   checks. Example for GOST: `test: ["CMD", "nc", "-z", "localhost", "443"]`.
   Integrates with `restart: always` to provide meaningful restarts.
2. **External monitoring via Vector** — add container health status as a
   metric source. Alerts on unhealthy containers without changing the
   compose files.

---

## 4. Host Security

### 4.1 `state: latest` for Docker packages

**Severity:** Low

```yaml
state: latest
```

Unpredictable results on re-runs — a new Docker CE version might introduce
breaking changes or require a daemon restart during production hours.

**Mitigations (best trade-off first):**

1. **Switch to `state: present`** — install once, do not upgrade
   automatically. Upgrades become an explicit operator action.
2. **Pin Docker CE version** — use `name: docker-ce=5:27.0.3-1~ubuntu...`
   to lock to a specific version. More maintenance but fully reproducible.

### 4.2 Config files with mode 0644

**Severity:** Low

Files like `/opt/mtg/config.toml`, `/opt/gost/gost.yml`, and
docker-compose files are world-readable. Not critical when only root has
access to the host, but broader than necessary.

**Mitigations (best trade-off first):**

1. **Set mode to 0640** — readable by root and the owning group only. One
   line change per template task.

### 4.3 `break_system_packages: true` for pip

**Severity:** Low

```yaml
- name: Install the Docker SDK
  pip:
    name: "docker>=7.1.0"
    break_system_packages: true
```

Installs pip packages globally, potentially conflicting with system-managed
Python packages.

**Mitigations (best trade-off first):**

1. **Use `pipx` or a virtualenv** — isolate the Docker SDK in a virtual
   environment. Set `ansible_python_interpreter` to point to the venv
   Python if needed.
2. **Use the OS-packaged Python Docker library** — `apt install
   python3-docker`. Avoids pip entirely but may lag behind the required
   version.

---

## 5. Input Validation and Injection

### 5.1 Inventory variables in shell commands

**Severity:** Low

```yaml
- shell: >
    docker run --rm {{ mtg_image }}
    generate-secret --hex {{ mtg_domain }}
```

Variables are interpolated into shell commands without escaping. Since they
are controlled by the operator via inventory, the risk is low — but
defensive coding would use the `command` module with `argv` or the
`quote` filter.

**Mitigations (best trade-off first):**

1. **Use `ansible.builtin.command` with argv** — avoids shell
   interpretation entirely. Example:
   ```yaml
   command:
     argv:
       - docker
       - run
       - --rm
       - "{{ mtg_image }}"
       - generate-secret
       - --hex
       - "{{ mtg_domain }}"
   ```
2. **Apply the `quote` filter** — `{{ mtg_domain | quote }}`. Escapes
   special characters for safe shell interpolation.

---

## 6. Operational Gaps

### 6.1 No automated security updates

**Severity:** Low

There is no `unattended-upgrades` or equivalent configured. Security
patches for the OS and system packages require manual intervention.

**Mitigations (best trade-off first):**

1. **Enable `unattended-upgrades`** — add a task to the `common` role that
   installs and configures automatic security updates for Ubuntu.
2. **Scheduled re-provisioning** — periodically run playbooks to refresh
   packages. Less reliable than unattended-upgrades for security patches.

### 6.2 No backup strategy for critical secrets

**Severity:** Low

- `/opt/mtg/secret` — MTProto secret, required for client connectivity.
- `/opt/outline/access.txt` — Outline VPN access credentials.

Loss of these files means re-generating secrets and reconfiguring all
clients.

**Mitigations (best trade-off first):**

1. **Fetch secrets to local machine** — add `ansible.builtin.fetch` tasks
   to download critical files to a local `secrets/` directory (gitignored).
   Simple, immediate backup.
2. **Encrypted backup to object storage** — use `restic` or `rclone` with
   encryption to back up `/opt/*/secret*` files to S3/B2. More
   infrastructure to manage.

---

## Summary Table

| #   | Finding                        | Severity | Recommended Mitigation                 |
|-----|--------------------------------|----------|----------------------------------------|
| 1.1 | No encryption of secrets       | Medium   | Ansible Vault for variable files       |
| 1.2 | Secrets printed to stdout      | Medium   | Replace debug with fetch               |
| 2.1 | GOST TLS without mutual auth   | Medium   | Add GOST-level auth credentials        |
| 2.3 | SSH is not hardened            | Medium   | Install fail2ban + harden sshd         |
| 2.4 | Root SSH access                | Medium   | `PermitRootLogin prohibit-password`    |
| 3.1 | Docker socket in Vector        | Medium   | Accept risk; optionally socket proxy   |
| 3.2 | Images not pinned by digest    | Medium   | Pin to minor/patch version tags        |
| 2.2 | Self-signed TLS in GOST        | Low      | Pin certificate fingerprint            |
| 3.3 | network_mode: host for GOST    | Low      | Accept with documentation              |
| 3.4 | No health checks               | Low      | Add healthcheck to compose             |
| 4.1 | `state: latest` for Docker     | Low      | Switch to `state: present`             |
| 4.2 | Config files mode 0644         | Low      | Set mode to 0640                       |
| 4.3 | `break_system_packages`        | Low      | Use virtualenv                         |
| 5.1 | Shell injection surface        | Low      | Use `command` with argv                |
| 6.1 | No automated security updates  | Low      | Enable unattended-upgrades             |
| 6.2 | No backup for critical secrets | Low      | Fetch secrets locally                  |
