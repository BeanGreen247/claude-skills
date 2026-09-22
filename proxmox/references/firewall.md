# Firewall (`pve-firewall`)

PVE has a built-in, cluster-aware firewall with three nested levels: **datacenter** (cluster-wide),
**host** (per-node), and **guest** (per-VM/CT, even per-NIC). It's off by default at the
datacenter/guest enable points until you turn it on — turn it on deliberately so you don't lock
yourself out.

- [The three levels](#the-three-levels)
- [Enable safely](#enable-safely)
- [Rules](#rules)
- [Security groups, aliases, IPsets](#security-groups-aliases-ipsets)
- [Inspecting](#inspecting)
- [Gotchas](#gotchas)

## The three levels

| Level | Config file | Scope |
|-------|-------------|-------|
| Datacenter | `/etc/pve/firewall/cluster.fw` | cluster-wide defaults, policies, groups, aliases, IPsets |
| Host | `/etc/pve/nodes/<node>/host.fw` | rules for the node itself |
| Guest | `/etc/pve/firewall/<vmid>.fw` | rules for a VM/CT (and per-NIC with `firewall=1`) |

Both the relevant level **and** the master switch must be enabled for filtering to apply. A guest's
firewall only acts on NICs configured with `firewall=1` (`qm/pct set ... --netX ...,firewall=1`).

## Enable safely

The default input policy becomes **DROP** when enabled — so add an allow rule for your management
access *before* enabling, or use the console:

```bash
# 1. At datacenter level, ensure management is reachable (e.g. allow SSH + web UI from your subnet)
#    via UI: Datacenter → Firewall → add IN ACCEPT rules, OR edit cluster.fw:
#    [RULES]
#    IN SSH(ACCEPT) -source 10.0.0.0/24
#    IN ACCEPT -p tcp -dport 8006 -source 10.0.0.0/24   # web UI
# 2. Then enable:
#    Datacenter → Firewall → Options → Firewall: Yes   (sets enable: 1 in cluster.fw [OPTIONS])
pve-firewall compile        # dry-compile the ruleset (catch errors before they apply)
pve-firewall status         # enabled? running?
pve-firewall restart
```

Always have console/IPMI access when enabling — a missing allow rule will otherwise cut your SSH/UI.

## Rules

Rules are edited in the UI or the `.fw` files. Each file has sections like `[OPTIONS]`, `[RULES]`,
`[IPSET name]`, `[group ...]`. Example guest firewall (`/etc/pve/firewall/101.fw`):

```ini
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
IN SSH(ACCEPT) -source 10.0.0.0/24 -log nolog
IN ACCEPT -p tcp -dport 80,443 -log nolog        # web
IN ACCEPT -p icmp                                 # ping
GROUP webservers                                  # apply a reusable security group
```

- **Direction**: `IN` / `OUT`. **Action**: `ACCEPT` / `DROP` / `REJECT`.
- Built-in **macros** like `SSH(ACCEPT)`, `HTTP(ACCEPT)`, `DNS(ACCEPT)` expand to the right
  ports/protocols — prefer them over raw port numbers for readability.
- Match on `-source`, `-dest`, `-p` (proto), `-dport`, `-sport`, `-iface`, `-log`.

## Security groups, aliases, IPsets

Define once at the datacenter level, reuse everywhere — much cleaner than duplicating rules:

```ini
# in cluster.fw
[ALIASES]
mgmt 10.0.0.0/24
office 203.0.113.0/24

[IPSET admins]
10.0.0.5
10.0.0.6

[group webservers]
IN HTTP(ACCEPT)
IN HTTPS(ACCEPT)
IN SSH(ACCEPT) -source +mgmt        # reference an alias with +name; an IPset with +ipsetname
```

Then a guest just does `GROUP webservers`. Reference aliases/IPsets with `+name`. Update the group
once and every guest using it follows.

## Inspecting

```bash
pve-firewall status                 # overall state
pve-firewall compile                # show the generated iptables/nft rules without applying (debugging)
iptables-save | less                # what's actually loaded (or nft list ruleset on nft backend)
journalctl -u pve-firewall
```

## Gotchas

- **Enabling can lock you out** — default input policy is DROP. Add allow rules for SSH (22) and the
  web UI (8006) from your network *first*, and keep console access.
- **Two switches per guest:** the guest's `enable: 1` in its `.fw` *and* `firewall=1` on the NIC.
  Forgetting the NIC flag means the rules do nothing.
- **Datacenter rules apply on top of guest rules** — a datacenter DROP can override what looks
  allowed at the guest level. Reason top-down.
- **Use macros/groups/aliases** instead of scattering raw ports — far easier to audit and change.
- **`pve-firewall compile` before relying on a change** — it surfaces syntax errors that would
  otherwise fail silently or wrongly.
