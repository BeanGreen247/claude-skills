# Storage (`pvesm`)

PVE abstracts storage into named **storages**, each with a **type** and allowed **content types**.
What you can do with a guest disk (snapshot? thin? share across nodes? live-migrate?) is decided by
the storage type. Definitions live in `/etc/pve/storage.cfg`; manage with `pvesm`.

- [Content types & the shared flag](#content-types--the-shared-flag)
- [Storage types & capabilities](#storage-types--capabilities)
- [Inspecting storage](#inspecting-storage)
- [Adding storage](#adding-storage)
- [Volumes & disk operations](#volumes--disk-operations)
- [Physical disks, ZFS, LVM-thin](#physical-disks-zfs-lvm-thin)
- [Thin provisioning & TRIM](#thin-provisioning--trim)
- [Gotchas](#gotchas)

## Content types & the shared flag

A storage only accepts the content types it's configured for:

| Content type | Holds |
|---|---|
| `images` | VM disk images |
| `rootdir` | container root volumes |
| `vztmpl` | container OS templates |
| `iso` | ISO install images |
| `backup` | vzdump backup files |
| `snippets` | hook scripts, cloud-init user-data snippets |
| `import` | OVA/OVF and disk images for import (newer PVE) |

`shared 1` marks a storage reachable from all nodes with the same content (NFS, CIFS, Ceph,
shared iSCSI/LVM). Shared storage enables fast live migration (only RAM moves) and is required for
HA. A local storage (LVM-thin, local ZFS, dir) is per-node — guests on it can only run where the
data is, unless you replicate or migrate the disk.

## Storage types & capabilities

| Type | Snapshots | Thin | Shared | Notes |
|------|:---:|:---:|:---:|------|
| `zfspool` (local ZFS) | ✅ | ✅ | ❌ | Great local default: snapshots, compression, checksums, `pvesr` replication |
| `lvmthin` | ✅ | ✅ | ❌ | Common local default on the install disk (`local-lvm`) |
| `lvm` (thick) | ❌ * | ❌ | (shared on shared LUN) | No snapshots for raw volumes (* see PVE 9 note below) |
| `dir` (filesystem path) | ✅ qcow2 only | ✅ qcow2 | ❌ | Flexible; snapshots only with qcow2 images, not raw |
| `btrfs` | ✅ | ✅ | ❌ | Newer; subvolume snapshots |
| `nfs` / `cifs` | ✅ qcow2 | ✅ qcow2 | ✅ | Network file storage; qcow2 for snapshots |
| `cephfs` | (file) | — | ✅ | Shared POSIX FS for ISOs/backups/templates |
| `rbd` (Ceph) | ✅ | ✅ | ✅ | Block storage for VM/CT disks; HA-friendly (see ceph.md) |
| `pbs` | n/a | — | ✅ | Proxmox Backup Server target (dedup, incremental) |
| `iscsi` / `iscsidirect` | ❌ | ❌ | ✅ | Raw LUNs; usually combined with LVM on top |

Rule of thumb: **ZFS or LVM-thin** for local; **Ceph RBD** for clustered/HA; **NFS/PBS** for
backups and shared ISOs/templates.

> **PVE 9 — snapshots on thick/shared LVM (technology preview):** Proxmox VE 9 added
> *snapshots as volume chains*, which can give snapshot support to storages that historically
> couldn't (notably **thick/shared LVM** on iSCSI/FC SANs). It works by chaining **qcow2**
> volumes, so it requires the storage's `snapshot-as-volume-chain` option enabled and
> **qcow2-formatted** disks — **raw** volumes still can't snapshot. Treat it as a preview
> (verify on the user's exact version before relying on it); for protection before risky changes,
> `vzdump` still works on any storage.

## Inspecting storage

```bash
pvesm status                         # all storages: type, status, total/used/avail, %used
pvesm list local                     # contents of a storage (images, ISOs, backups…)
pvesm list local --content backup
pvesm scan nfs 10.0.0.5              # discover NFS exports on a server (also: zfs, lvm, lvmthin, cifs, iscsi)
cat /etc/pve/storage.cfg             # raw definitions
```

## Adding storage

```bash
# Directory on an already-mounted filesystem
pvesm add dir bigdir --path /mnt/bigdir --content images,iso,backup,vztmpl

# NFS share (for backups/ISOs/shared images)
pvesm add nfs nfsbackup --server 10.0.0.5 --export /export/pve \
  --content backup,iso,vztmpl --options vers=4.2

# CIFS/SMB
pvesm add cifs smbstore --server 10.0.0.6 --share data \
  --username svc --password --content backup,iso

# Existing ZFS pool as guest storage
pvesm add zfspool tank --pool tank --content images,rootdir --sparse 1

# Existing LVM thin pool
pvesm add lvmthin vmthin --vgname pve --thinpool data --content images,rootdir

# Proxmox Backup Server
pvesm add pbs pbsbackup --server pbs.lan --datastore main \
  --username backup@pbs --password --fingerprint AA:BB:...   # fingerprint from PBS

pvesm set <storeid> --disable 1      # disable without deleting
pvesm remove <storeid>               # removes the PVE *definition* only (data on disk is untouched)
```

`pvesm remove` only deletes the PVE storage entry, not the underlying data — but the volumes become
inaccessible to PVE. Don't remove a storage that backs running guests.

## Volumes & disk operations

```bash
pvesm alloc local-lvm 101 vm-101-disk-1 32G          # allocate a volume manually
pvesm free local-lvm:vm-101-disk-1                    # free a volume (DATA LOSS)
pvesm path local:iso/debian-12.iso                   # resolve a volume to a filesystem path
# Move/convert a guest disk between storages (online for VMs):
qm disk move 101 scsi0 cephpool --delete             # VM (see vms.md)
pct move-volume 201 rootfs zfslocal --delete         # CT
```

## Physical disks, ZFS, LVM-thin

Always reference disks by stable id (`/dev/disk/by-id/...`), not `/dev/sdX` (which can change).

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,SERIAL      # survey disks
ls -l /dev/disk/by-id/                                # stable device names

# Create a ZFS pool, then register it with PVE
zpool create -o ashift=12 tank mirror /dev/disk/by-id/ata-DISK1 /dev/disk/by-id/ata-DISK2
zfs set compression=lz4 atime=off tank
pvesm add zfspool tank --pool tank --content images,rootdir

# Create an LVM thin pool on a spare disk
pvcreate /dev/sdb && vgcreate vmdata /dev/sdb
lvcreate -l 100%FREE -T vmdata/thinpool
pvesm add lvmthin vmthin --vgname vmdata --thinpool thinpool --content images,rootdir
```

The web UI exposes `Node → Disks → ZFS / LVM-Thin / Directory` for the same operations
(`pveceph`/`pvesm` under the hood). For Ceph see `ceph.md`.

## Thin provisioning & TRIM

Thin storages (ZFS, LVM-thin, Ceph, qcow2) only consume space actually written — but freed space
inside a guest isn't returned unless the guest issues discards/TRIM:

- Give VM disks `discard=on` (+ `ssd=1`) and run `fstrim -av` (or enable the `fstrim.timer`) in the
  guest; mark the volume thin in PVE.
- Over-provisioning is fine but **monitor real usage** (`pvesm status`, `zpool list`,
  `lvs -a`): a full thin pool stalls/errors every guest on it. Set alerts/quotas.

## Gotchas

- **Snapshots depend on the storage type** — plain LVM and raw-on-`dir` can't snapshot (except via
  the PVE 9 qcow2 volume-chain preview noted above). If a user "can't take a snapshot," check the
  storage type first (`pvesm status`); to protect a guest right now, `vzdump` works everywhere.
- **`local` vs `local-lvm`:** by default `local` is a `dir` (ISOs, backups, templates, snippets)
  and `local-lvm` is LVM-thin (guest disks). Put the right content on the right one.
- **A full thin pool is an outage**, not a warning — every guest sharing it can hang. Watch usage.
- **NFS/CIFS need qcow2 for snapshots** (raw can't snapshot on file storage).
- **`pvesm remove` ≠ delete data** — it removes the PVE definition; clean the underlying pool/share
  separately if you truly want the bytes gone.
- **Match `ashift=12`** (4K) for modern disks when creating ZFS pools; wrong ashift can't be changed
  later without rebuilding the pool.
