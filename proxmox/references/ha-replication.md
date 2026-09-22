# High Availability & Storage Replication (`ha-manager`, `pvesr`)

**HA** restarts guests on another node when their node fails. **Replication** (`pvesr`) keeps ZFS
guest volumes copied to other nodes on a schedule so HA/migration has recent local data without
shared storage. They're often used together: replication shrinks the data-loss window when HA
recovers a guest on a peer.

- [How HA works](#how-ha-works)
- [Requirements](#requirements)
- [Managing HA resources](#managing-ha-resources)
- [HA groups](#ha-groups)
- [Fencing](#fencing)
- [Storage replication (pvesr)](#storage-replication-pvesr)
- [Gotchas](#gotchas)

## How HA works

The cluster's HA stack (`pve-ha-crm` on the manager node, `pve-ha-lrm` on each node) watches HA-managed
guests. If a node dies, the surviving majority **fences** it (ensures it's really down) and restarts
its HA guests elsewhere. HA needs **quorum** to act — a minority partition won't (and must not) start
guests.

## Requirements

- A **cluster with quorum** (3+ nodes recommended; see `cluster.md`).
- Guest storage reachable on the recovery node: either **shared storage** (Ceph/NFS — best, no data
  loss) or **ZFS + `pvesr` replication** (local storage, recovers to the last replicated point).
- A working **fencing** path (watchdog) so a failed node can't keep running the guest (split-brain).

## Managing HA resources

```bash
ha-manager add vm:101 --state started --max_restart 3 --max_relocate 3   # bring VM 101 under HA
ha-manager add ct:201 --state started --group rack-a
ha-manager status                                  # current HA state of all resources
ha-manager config                                  # HA config
ha-manager set vm:101 --state stopped              # HA keeps it stopped (managed but off)
ha-manager set vm:101 --state disabled             # stop managing without removing
ha-manager migrate vm:101 node2                     # HA-aware live migration
ha-manager relocate vm:101 node2                     # HA-aware offline move
ha-manager remove vm:101                            # take VM out of HA management
```

States: `started` (keep running, restart/relocate on failure), `stopped` (keep off), `disabled`
(ignore), `ignored` (fully unmanaged). `--max_restart` / `--max_relocate` bound recovery attempts
before the resource goes to the `error` state.

## HA groups

Groups pin resources to preferred nodes with priorities — e.g. "run on node1/node2, prefer node1,
and (with `nofailback=0`) move back when it returns."

```bash
ha-manager groupadd rack-a --nodes "node1:2,node2:1" --restricted 0 --nofailback 0
ha-manager groupconfig
ha-manager set vm:101 --group rack-a
```

- `--nodes "n1:2,n2:1"` → priorities (higher = preferred).
- `--restricted 1` → only ever run on listed nodes (else they're just preferred).
- `--nofailback 1` → don't automatically move back to a higher-priority node when it recovers
  (avoids a second disruption).

## Fencing

PVE fences via a hardware/softdog **watchdog**: an HA node must keep petting the watchdog; if it
loses quorum or hangs, the watchdog reboots it after the timeout, guaranteeing the guest isn't
running in two places. The softdog is enabled automatically when HA is configured; a hardware
watchdog (IPMI/iTCO) is more robust — configure it in `/etc/default/pve-ha-manager`. Don't disable
fencing; it's what prevents split-brain corruption.

## Storage replication (pvesr)

ZFS-based asynchronous replication of guest volumes to other nodes — gives local-storage clusters a
recent copy for fast migration and lower-RPO HA recovery. **Requires ZFS** (zfspool) on source and
target.

```bash
pvesr create-local-job 101-0 node2 --schedule "*/15"     # replicate VM 101 to node2 every 15 min
pvesr create-local-job 201-0 node2 --schedule "*/5" --rate 50   # CT, every 5 min, 50 MB/s cap
pvesr list                                                # all replication jobs
pvesr status                                              # last/next run, state, duration
pvesr run --id 101-0                                     # run a job now
pvesr update 101-0 --schedule "*/30"
pvesr delete 101-0
```

Job id is `<vmid>-<N>`. The first sync is a full send; later ones are incremental ZFS deltas. After
HA failover or migration to the replication target, the guest starts from the **last replicated
snapshot** — anything written since is lost (that's your RPO; tighten the schedule to reduce it).

## Gotchas

- **HA needs quorum** — a node in the minority won't recover guests (by design, to avoid
  split-brain). HA on a 2-node cluster without a QDevice is unsafe.
- **Replication ≠ zero data loss.** Recovery rolls back to the last replicated snapshot; size the
  schedule to your acceptable RPO. For zero loss, use shared storage (Ceph/NFS).
- **Replication requires ZFS** on both ends with matching pool/dataset availability.
- **Don't disable fencing/watchdog** — without it, a hung-but-alive node can run a guest that HA also
  started elsewhere, corrupting shared data.
- **Test failover** in a maintenance window before relying on it; confirm guests actually start on a
  peer and that fencing behaves.
- **HA + local-only storage without replication** can't recover (no data on the peer) — pair them or
  use shared storage.
