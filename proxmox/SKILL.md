---
name: proxmox
description: >-
  Administer Proxmox VE (PVE) virtualization hosts and clusters. Create and manage
  VMs (qm/QEMU-KVM) and LXC containers (pct), configure storage (pvesm — ZFS, LVM-thin,
  Ceph RBD, dir, NFS), networking (Linux bridges, VLANs, bonds, SDN), the firewall,
  backups and restore (vzdump, Proxmox Backup Server), clustering (pvecm), high
  availability (ha-manager) and storage replication (pvesr), users/roles/API tokens
  (pveum), and the REST API (pvesh). Also covers performance tuning and best practices
  for guest VMs and containers. Use this whenever the user mentions Proxmox, PVE, a
  Proxmox node or cluster, /etc/pve configs, VMIDs, or the qm/pct/pvesm/pvecm/vzdump/
  pveum/ha-manager/pvesh tools — or asks to provision, clone, migrate, snapshot, back
  up, resize, tune, secure, or troubleshoot guests and hosts on Proxmox, even if they
  never name the exact command.
metadata:
  origin: "installed as-is from https://github.com/3shn/skill-proxmox (MIT license) — purely CLI/SSH-based, no MCP or API dependency"
---

# Proxmox VE Administration

Proxmox VE (PVE) is a Debian-based virtualization platform managing **KVM virtual
machines** and **LXC containers** through a clustered config layer (`/etc/pve`), a
web UI, a REST API, and a family of `pve*`/`qm`/`pct` CLI tools. This skill helps you
provision, configure, tune, protect, and troubleshoot PVE hosts, guests, storage,
networking, and clusters — correctly and safely.

## How to operate (hybrid: advise + execute)

You work in one of two modes depending on whether a live PVE host is reachable. **Always
figure out which before doing anything** — acting blind is how VMIDs collide and the wrong
guest gets destroyed.

1. **Execute mode** — you can run commands against a real node (you're on the node, or can
   SSH to it, or `pvesh`/`pveproxy` API is reachable). Run the orientation step, then perform
   the task and **verify with a status command**. Stop and ask before anything destructive
   (see Guardrails).
2. **Advise mode** — no host is reachable, or the user only wants guidance. Produce the exact
   commands and config edits, annotated with *why* each flag matters, ready to paste. Never
   pretend you ran something you didn't.

When unsure which mode applies, run `command -v pveversion` (or try the SSH/API path the user
described). If it resolves, you're likely on/near a node — confirm with the user before
executing changes. If it doesn't, you're in advise mode.

### Step 0 — Orient before you act

Never create, modify, or delete anything until you know what's already there. The bundled
helper gathers a safe, read-only snapshot in one shot:

```bash
bash scripts/pve-preflight.sh        # version, node, cluster/quorum, storages, guests, next free VMID
```

If you can't run the script (advise mode), tell the user to run it, or to report: `pveversion`,
`pvecm status` (clustered?), `pvesm status` (storages + free space), `qm list` / `pct list`
(existing guests + VMIDs), and `cat /etc/pve/.members`. You need this because:

- **VMIDs are cluster-wide and must be unique.** Get the next free one with
  `pvesh get /cluster/nextid` — never hand-pick a number that might be taken.
- **Storage determines what's possible.** Snapshots, thin-provisioning, live migration, and
  disk formats all depend on the storage type (ZFS/LVM-thin/Ceph support snapshots; plain LVM
  and `dir`+qcow2 differ). Check `pvesm status` and the storage's `content`/`shared` flags first.
- **Cluster + quorum gate cluster ops.** Editing `/etc/pve` requires quorum (`pvecm status`).
  A node without quorum has a read-only config filesystem.

## Safety guardrails (read before any change)

Proxmox commands act on real workloads; many are irreversible. Treat these as the cost of
being trusted to run them, not bureaucracy.

- **Confirm destructive operations first.** `qm destroy`, `pct destroy`, `qm/pct` disk
  removal, `pvesm remove`, `pveceph osd destroy`, `pvecm delnode`, `lvremove`/`zfs destroy`,
  formatting/wiping disks, and `--force`/`--purge` all cause data loss. Name the exact target
  (VMID/name/disk), state what will be lost, and get explicit go-ahead. In execute mode, stop
  and ask; in advise mode, flag it loudly in the output.
- **Back up before risky changes.** Snapshot or `vzdump` a guest before destructive edits,
  disk resizes that shrink, OS upgrades, or migrations you're unsure about. A 30-second
  snapshot beats an unrecoverable mistake.
- **Prefer reversible + idempotent.** Use `--dry-run` where offered (e.g. `vzdump`, `ha`
  tooling), clone instead of mutating a golden template, and check current state before
  changing it so re-running is safe.
- **Never shrink a disk** with `qm disk resize`/`pct resize` — it only grows; shrinking
  corrupts the filesystem. To reduce, create smaller and migrate data.
- **Edit config via the tools, not by hand, while a guest runs.** `qm set`/`pct set` validate
  and apply correctly. Hand-editing `/etc/pve/qemu-server/<vmid>.conf` is a last resort for a
  stopped guest or recovery — and even then, know what you're changing.
- **Respect quorum.** Don't force cluster changes on a node that's lost quorum unless you're
  deliberately doing recovery (`pvecm expected`), and explain the risk.

## Mental model — where the truth lives

PVE's config is a clustered filesystem (`pmxcfs`) mounted at **`/etc/pve`**, synced across all
nodes and backed by a SQLite DB. Knowing the paths makes you fast and lets you recover when the
UI/API is down:

| What | Path |
|------|------|
| VM config | `/etc/pve/qemu-server/<vmid>.conf` (→ `/etc/pve/nodes/<node>/qemu-server/`) |
| Container config | `/etc/pve/lxc/<vmid>.conf` |
| Storage definitions | `/etc/pve/storage.cfg` |
| Cluster / corosync | `/etc/pve/corosync.conf`, `pvecm status` |
| Users / ACLs / tokens | `/etc/pve/user.cfg` (manage via `pveum`) |
| Firewall (cluster/host/guest) | `/etc/pve/firewall/*.fw`, `/etc/pve/nodes/<node>/host.fw` |
| HA config | `/etc/pve/ha/` (manage via `ha-manager`) |
| Host network | `/etc/network/interfaces` (+ `ifreload -a` to apply) |
| Backup jobs | `/etc/pve/jobs.cfg` (+ `/etc/vzdump.conf` defaults) |

Prefer the CLI tools — they validate input, apply atomically, and notify the cluster. Reach for
raw file edits only for inspection, bulk/scripted changes, or recovery.

## Routing — load the reference for the task

The references hold the dense, command-level detail. **Read the relevant one before composing
commands** rather than working from memory — flag names and storage caveats matter. Each is
self-contained with examples.

| If the task involves… | Read |
|---|---|
| VMs: create, clone, config, disks, snapshots, migrate, templates, cloud-init (`qm`) | `references/vms.md` |
| Containers: create, config, templates, bind mounts, snapshots (`pct`) | `references/containers.md` |
| Storage: add/manage storages, disk ops, ZFS/LVM-thin/dir/NFS, content types (`pvesm`) | `references/storage.md` |
| Ceph: hyper-converged RBD/CephFS, OSDs, pools, monitors (`pveceph`) | `references/ceph.md` |
| Backups & restore: `vzdump`, scheduled jobs, retention, Proxmox Backup Server | `references/backup.md` |
| Clustering: create/join cluster, quorum, corosync, pmxcfs (`pvecm`) | `references/cluster.md` |
| High availability & replication (`ha-manager`, `pvesr`) | `references/ha-replication.md` |
| Networking: bridges, VLANs, bonds, host NICs, SDN basics | `references/network.md` |
| Firewall: datacenter/host/guest rules, security groups, aliases/IPsets | `references/firewall.md` |
| Users, roles, ACLs, auth realms, API tokens, 2FA (`pveum`) | `references/users.md` |
| REST API / automation (`pvesh`, tokens, `curl`) | `references/api.md` |
| Performance tuning & best practices for guests (CPU, memory, disk, net) | `references/performance.md` |
| Something is broken: logs, recovery, common errors | `references/troubleshooting.md` |

When a task spans areas (e.g. "make this VM highly available with replicated storage"), read
each relevant reference. Cross-cutting jobs almost always touch storage + one other domain.

## Fast path — the commands you reach for most

This is orientation, not a substitute for the references. For real work, open the reference and
use the right flags for the storage/cluster you're on.

```bash
# Orientation
pveversion -v                         # PVE + kernel + key package versions
pvecm status                          # cluster + quorum
pvesm status                          # storages, type, enabled, free/used
qm list ; pct list                    # guests on this node
pvesh get /cluster/nextid             # next free VMID (use this, don't guess)

# VM lifecycle (qm) — see references/vms.md
qm create 9000 --name tmpl --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-single
qm start 9000 ; qm shutdown 9000 ; qm stop 9000      # stop = hard power-off
qm clone 9000 101 --name web01 --full                # full clone from template
qm snapshot 101 pre-upgrade ; qm rollback 101 pre-upgrade
qm migrate 101 node2 --online                        # live-migrate

# Container lifecycle (pct) — see references/containers.md
pct create 201 local:vztmpl/debian-12-standard_*.tar.zst --hostname ct01 \
  --memory 1024 --cores 2 --rootfs local-lvm:8 --net0 name=eth0,bridge=vmbr0,ip=dhcp
pct start 201 ; pct enter 201 ; pct exec 201 -- <cmd>

# Backup / restore (vzdump) — see references/backup.md
vzdump 101 --storage backupstore --mode snapshot --compress zstd
qmrestore /path/vzdump-qemu-101-*.vma.zst 110 --storage local-lvm   # restore VM to new VMID

# Anything risky → snapshot or back up first, confirm target, then act.
```

## Output conventions

- **Execute mode:** state what you're about to do, run it, then run a status/verify command
  (`qm status`, `pct status`, `pvesm status`, `pvecm status`) and report the result. Don't claim
  success without verifying.
- **Advise mode:** give copy-pasteable commands with the *node context* made explicit ("on the
  target node:"), and a one-line *why* for non-obvious flags so the user learns, not just copies.
- **Always** call out destructive steps and prerequisites (quorum, storage type, free space,
  guest must be stopped) up front, not after the user has run half of it.
- Keep prose tight; lead with the command, follow with the reasoning that makes it safe to run.
