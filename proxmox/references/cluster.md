# Clustering (`pvecm`, corosync, pmxcfs)

A PVE cluster gives you a single management view, guest migration, shared HA, and a replicated
config filesystem. It relies on **corosync** (cluster membership/messaging, latency-sensitive) and
**pmxcfs** (the `/etc/pve` filesystem, writable only while the node has **quorum**).

- [Before you cluster](#before-you-cluster)
- [Create a cluster](#create-a-cluster)
- [Join a node](#join-a-node)
- [Quorum](#quorum)
- [Remove a node](#remove-a-node)
- [Corosync & redundant links](#corosync--redundant-links)
- [pmxcfs](#pmxcfs)
- [Gotchas](#gotchas)

## Before you cluster

- Cluster on a **low-latency network** — corosync needs <~5 ms and steady latency; jitter causes
  membership flaps. Give it its own NIC/VLAN if you can (see `network.md`).
- All nodes need **unique hostnames**, resolvable names, and synced time (NTP).
- **Join is one-way and destructive to the joiner's cluster state** — a node can only join an empty
  cluster (no guests with conflicting VMIDs). Plan VMIDs to be unique across all nodes first.
- Aim for an **odd number of nodes** (3+) so quorum survives one failure. Two-node clusters need a
  QDevice or careful `two_node`/quorum handling.

## Create a cluster

On the first node:

```bash
pvecm create my-cluster                          # uses the default link (link0) on this node's IP
pvecm create my-cluster --link0 10.10.10.1       # pin corosync to a dedicated network
pvecm status                                     # verify: quorate, 1 node
```

## Join a node

On each additional node (must have no VMID conflicts with the cluster):

```bash
# Easiest: copy the join info from an existing node's UI (Datacenter → Cluster → Join Information),
# then on the new node paste it, or use the CLI:
pvecm add 10.10.10.1                              # IP of an existing cluster node; prompts for root pw
pvecm add 10.10.10.1 --link0 10.10.10.4          # bind this node's corosync to its dedicated IP
pvecm status                                     # should now show the new node, quorate
pvecm nodes                                      # list members
```

After joining, the node's `/etc/pve` is replaced by the cluster's — its previous standalone config
is gone. That's why you join *empty* nodes.

## Quorum

Quorum = a majority of votes present. **Without quorum, `/etc/pve` goes read-only** — you can't
start/change guests or edit config. Check and, only in deliberate recovery, override:

```bash
pvecm status                                     # Quorate: Yes/No, Expected/Total votes
pvecm expected 1                                 # TEMPORARILY lower expected votes to regain a writable /etc/pve
                                                 # (recovery only — risks split-brain; never on a partitioned cluster)
```

For 2-node clusters, add a lightweight tie-breaker (QDevice) on a third box:

```bash
apt install corosync-qdevice                     # on all nodes
pvecm qdevice setup <qdevice-host-ip>            # configures an external QDevice for an extra vote
```

## Remove a node

Removing a node is **permanent** and the node must stay off the network afterward (never rejoin a
removed node without a fresh reinstall).

```bash
# 1. Migrate/back up all guests off the node first. Then power it OFF for good.
# 2. From a REMAINING node:
pvecm nodes
pvecm delnode <nodename>
pvecm status
# 3. Optionally clean stale entries: remove /etc/pve/nodes/<nodename>/ on a remaining node.
```

To reuse the hardware, **reinstall PVE** before joining again — a deleted node's corosync state is
incompatible with rejoining.

## Corosync & redundant links

Corosync config is `/etc/pve/corosync.conf` (cluster-wide) mirrored to
`/etc/corosync/corosync.conf` (local). Edit live config carefully — a bad edit can break the
cluster. Add a second ring for redundancy:

```bash
# Add a redundant link when joining:
pvecm add <ip> --link0 10.10.10.4 --link1 10.20.20.4
# Editing corosync.conf: ALWAYS bump the config_version, validate, and apply to all nodes via /etc/pve.
```

When editing `corosync.conf`, increment `config_version`, keep all nodes online, and verify with
`pvecm status` / `journalctl -u corosync`. Mistakes here can split-brain the cluster.

## pmxcfs

`/etc/pve` is the Proxmox Cluster File System — a FUSE filesystem backed by SQLite, synced over
corosync. It's the single source of truth for config. If pmxcfs is mounted read-only, you've lost
quorum (see above). For deep recovery you can start it standalone:

```bash
pmxcfs -l            # local mode: mount /etc/pve writable WITHOUT quorum (recovery only — single node)
systemctl status pve-cluster
```

`pmxcfs -l` is a recovery hammer for a node that's alone and needs its config writable; don't use it
on a node that should be talking to peers.

## Gotchas

- **No quorum ⇒ read-only `/etc/pve`** ⇒ can't manage guests. First thing to check when "nothing
  works" on a cluster.
- **Corosync hates latency/jitter** — sharing its NIC with backup/storage traffic causes random
  membership loss. Isolate it.
- **Join wipes the joiner's config** and needs unique VMIDs — plan before joining.
- **Deleted nodes can't rejoin** without a reinstall; keep them off the network after `delnode`.
- **Edit `corosync.conf` with care** (bump `config_version`, all nodes up) — it's the easiest way to
  take a whole cluster down.
