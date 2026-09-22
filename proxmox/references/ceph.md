# Hyper-converged Ceph (`pveceph`)

Ceph turns the cluster's local disks into shared, self-healing, replicated storage — enabling HA and
live migration without an external SAN. PVE integrates it via `pveceph`; guest disks live on **RBD**
pools, shared files on **CephFS**. Ceph is powerful but unforgiving of under-provisioning — plan
network, disks, and node count before deploying.

- [Prerequisites](#prerequisites)
- [Install & init](#install--init)
- [Monitors & managers](#monitors--managers)
- [OSDs (disks)](#osds-disks)
- [Pools & PGs](#pools--pgs)
- [Use as PVE storage (RBD / CephFS)](#use-as-pve-storage-rbd--cephfs)
- [Health & maintenance](#health--maintenance)
- [Gotchas](#gotchas)

## Prerequisites

- **At least 3 nodes** (so the default 3× replication and monitor quorum work). Fewer means no real
  redundancy.
- A **dedicated, fast, low-latency Ceph network** (10 GbE+ strongly recommended; ideally a separate
  cluster/replication network too). Ceph saturates slow networks and latency hurts everything.
- **Enterprise SSD/NVMe with power-loss protection.** Consumer SSDs collapse under Ceph's sync
  writes. One OSD per physical disk; no hardware RAID (give Ceph the raw disks).
- Plan capacity for replication overhead: usable ≈ raw ÷ replica count (default 3) and keep
  utilization well under 80%.

## Install & init

Run on each node that will participate:

```bash
pveceph install                                  # install Ceph packages (pick the offered release)
# On the first node, initialize the cluster network:
pveceph init --network 10.30.30.0/24 --cluster-network 10.40.40.0/24
```

`--network` is the public Ceph network (clients/monitors); `--cluster-network` (optional) carries
OSD replication traffic separately for performance.

## Monitors & managers

Monitors (MONs) maintain the cluster map and need quorum; run an **odd number, 3 for HA**. Managers
(MGRs) provide metrics/dashboard; run 2+.

```bash
pveceph mon create                               # create a MON on the current node (repeat on 3 nodes)
pveceph mgr create                               # create a MGR (run on 2 nodes for failover)
pveceph mon destroy <monid>                      # remove a MON (keep an odd quorum)
ceph mon stat ; ceph quorum_status
```

## OSDs (disks)

Each OSD = one physical disk dedicated to Ceph. Wipe-and-add raw disks:

```bash
lsblk -o NAME,SIZE,TYPE,SERIAL                   # identify the target disk
pveceph osd create /dev/disk/by-id/nvme-...      # add a disk as an OSD (optionally --db_dev / --wal_dev on faster media)
ceph osd tree                                    # view OSDs by host
# Removing an OSD (DATA REBALANCE — do one at a time, wait for HEALTH_OK between):
ceph osd out <id> ; # wait for rebalance to finish
pveceph osd destroy <id>                         # removes the OSD and frees the disk
```

For HDD OSDs, putting the DB/WAL on a fast NVMe (`--db_dev`) dramatically improves performance.

## Pools & PGs

Pools store the data; placement groups (PGs) shard it across OSDs. PVE's autoscaler handles PG
counts by default — leave it on unless you know better.

```bash
pveceph pool create vmpool --pg_autoscale_mode on --application rbd   # size defaults to 3/2 (replica/min)
pveceph pool create vmpool --size 3 --min_size 2 --pg_autoscale_mode on
pveceph pool ls
pveceph pool destroy vmpool                        # DELETES ALL DATA in the pool
```

`size 3 / min_size 2` means 3 replicas and the pool stays writable as long as ≥2 are present —
the standard safe default. Don't run `min_size 1` (risks data loss on a single failure during
recovery).

## Use as PVE storage (RBD / CephFS)

Creating a pool via `pveceph` usually auto-registers an RBD storage. To add manually or add CephFS:

```bash
# RBD block storage for VM/CT disks (shared, snapshot-capable, HA-ready)
pvesm add rbd cephrbd --pool vmpool --content images,rootdir --krbd 0
# CephFS for ISOs / templates / backups (shared filesystem)
pveceph fs create --name cephfs --pg_num 128      # creates the MDS-backed filesystem
pvesm add cephfs cephfs --content iso,vztmpl,backup
ceph mds stat                                      # CephFS needs at least one MDS (pveceph mds create)
```

Guests on RBD can live-migrate freely and are eligible for HA, since every node sees the same data.

## Health & maintenance

```bash
ceph -s                                            # one-line health + capacity + activity
ceph health detail                                 # explain HEALTH_WARN/ERR
ceph osd df tree                                    # per-OSD utilization (watch for nearfull)
ceph osd perf
# Planned maintenance on a node: pause rebalancing so a reboot doesn't trigger a storm
ceph osd set noout                                  # don't mark OSDs out during the maintenance window
# ... reboot / work on the node ...
ceph osd unset noout
```

Aim to keep the cluster at `HEALTH_OK`. `HEALTH_WARN` about PG autoscaling or a single OSD nearfull
is your early warning to add capacity.

## Gotchas

- **3 nodes minimum** for real redundancy; 1–2 node "Ceph" gives you a fragile single point of
  failure. For tiny setups, ZFS + replication (see `ha-replication.md`) is often saner.
- **Network is everything.** A slow/shared Ceph network makes the whole cluster feel broken. Dedicate
  fast NICs; separate cluster (replication) traffic.
- **Consumer SSDs ruin Ceph** — no PLP means abysmal sync performance and possible data loss. Use
  enterprise drives.
- **Never `min_size 1`** in production; never give Ceph disks behind hardware RAID.
- **Remove OSDs/MONs one at a time**, waiting for `HEALTH_OK` between — yanking several triggers a
  rebalance storm or data loss.
- **Don't let it fill** — Ceph stops writes near full and recovery needs free space. Watch
  `ceph osd df` and expand before ~80%.
- **`pveceph pool destroy` / `osd destroy` are irreversible data loss** — confirm the target.
