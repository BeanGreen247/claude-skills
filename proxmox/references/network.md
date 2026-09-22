# Networking (bridges, VLANs, bonds, SDN)

PVE host networking is plain Debian `/etc/network/interfaces`, with PVE conventions on top:
guests attach to **Linux bridges** (`vmbrN`). Most setups need one bridge on the management NIC;
add VLANs, bonds, and a separate storage/cluster network as needed.

- [Apply changes safely](#apply-changes-safely)
- [Bridges](#bridges)
- [VLANs](#vlans)
- [Bonds (link aggregation)](#bonds-link-aggregation)
- [Per-guest NIC options](#per-guest-nic-options)
- [Separate networks](#separate-networks)
- [SDN (brief)](#sdn-brief)
- [Gotchas](#gotchas)

## Apply changes safely

PVE stages edits in `/etc/network/interfaces.new` and applies on reboot, or live with `ifreload`
(uses `ifupdown2`, installed by default):

```bash
cat /etc/network/interfaces
ifreload -a            # apply changes live (no reboot) — verify connectivity immediately after
ifquery -a             # show parsed config
```

**A bad network edit can lock you out of a remote host.** Keep a console/IPMI session open, or wrap
risky changes so they auto-revert. Don't `ifreload` a change to the management interface without
out-of-band access.

## Bridges

A bridge is a virtual switch; guests get a NIC on it. The default `vmbr0` bridges the management NIC:

```text
# /etc/network/interfaces
auto lo
iface lo inet loopback

iface eno1 inet manual

auto vmbr0
iface vmbr0 inet static
    address 10.0.0.10/24
    gateway 10.0.0.1
    bridge-ports eno1
    bridge-stp off
    bridge-fd 0
```

- `bridge-ports` = the physical NIC(s) the bridge uses; `none` for an internal-only bridge.
- A guest NIC `--net0 virtio,bridge=vmbr0` plugs into this switch.

## VLANs

Two common patterns:

```text
# A) VLAN-aware bridge (tag per-guest in the NIC config — flexible, recommended)
auto vmbr0
iface vmbr0 inet static
    address 10.0.0.10/24
    gateway 10.0.0.1
    bridge-ports eno1
    bridge-vlan-aware yes
    bridge-vids 2-4094
```
Then tag a guest: `qm set 101 --net0 virtio,bridge=vmbr0,tag=20`.

```text
# B) Dedicated VLAN interface on the host (e.g. host IP in VLAN 50)
auto eno1.50
iface eno1.50 inet manual
auto vmbr50
iface vmbr50 inet static
    address 10.50.0.10/24
    bridge-ports eno1.50
```

VLAN-aware bridges let you assign any VLAN per guest without new host interfaces — prefer them.

## Bonds (link aggregation)

Combine NICs for redundancy/throughput, then bridge the bond:

```text
auto bond0
iface bond0 inet manual
    bond-slaves eno1 eno2
    bond-miimon 100
    bond-mode 802.3ad        # LACP (needs switch config); or active-backup for pure failover
    bond-xmit-hash-policy layer3+4

auto vmbr0
iface vmbr0 inet static
    address 10.0.0.10/24
    gateway 10.0.0.1
    bridge-ports bond0
```

`802.3ad`/LACP needs matching switch config; `active-backup` works on any switch (redundancy only,
no aggregate bandwidth). `balance-alb` is switch-independent and load-balances both directions.

## Per-guest NIC options

```bash
qm set 101 --net0 virtio,bridge=vmbr0,tag=20,firewall=1,rate=100   # VLAN 20, firewall on, 100 MB/s cap
qm set 101 --net0 virtio,bridge=vmbr0,macaddr=BC:24:11:AA:BB:CC     # pin a MAC
qm set 101 --net0 virtio,bridge=vmbr0,queues=4                      # multiqueue (perf; see performance.md)
pct set 201 --net0 name=eth0,bridge=vmbr0,ip=10.0.0.21/24,gw=10.0.0.1,tag=20
```

Use **virtio** for performance. `rate` throttles, `tag` sets the VLAN, `firewall=1` enables per-NIC
filtering (see `firewall.md`).

## Separate networks

For clusters, isolate traffic so latency-sensitive corosync isn't starved and storage gets its own
pipe:

- **Corosync/cluster** — own NIC/VLAN, low latency (see `cluster.md`); even a 1 GbE dedicated link
  beats sharing.
- **Storage/Ceph/replication** — fast, dedicated (10 GbE+), possibly with jumbo frames (MTU 9000
  end-to-end).
- **VM traffic** — the bridges guests use.
- **Management** — the host's admin IP.

Set `mtu 9000` on the host interface, bridge, and guest NIC consistently if using jumbo frames — a
mismatch causes silent drops.

## SDN (brief)

Proxmox SDN (Datacenter → SDN) builds overlay/virtual networks across the cluster: define **Zones**
(VLAN, QinQ, VXLAN, EVPN), **VNets** (the virtual networks guests attach to), and **Subnets**.
After editing SDN config, **Apply** to push it to all nodes. Use it when you need tenant isolation
or L2 networks spanning nodes without manual per-node interface config. For a single host or simple
VLANs, a VLAN-aware bridge is simpler.

## Gotchas

- **A bad edit can lock you out.** Always have console/IPMI access before changing the management
  interface; `ifreload -a` applies live, so verify immediately.
- **VLAN-aware bridge vs per-VLAN interface** — don't mix approaches confusingly; the VLAN-aware
  bridge is the flexible default.
- **LACP needs switch support** — without it, use `active-backup`/`balance-alb`.
- **Jumbo frames must match end-to-end** (host + switch + guest) or you get silent drops/hangs.
- **Don't share corosync's NIC** with backup/storage bursts — it causes cluster flapping.
- **`bridge-ports none`** for isolated internal networks (host-only); add NAT/routing yourself if
  guests need outbound.
