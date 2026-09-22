# Backup & Restore (`vzdump`, Proxmox Backup Server)

Backups are full guest images (config + disks) written by `vzdump`. They protect against deletion,
corruption, and bad upgrades — unlike snapshots, which sit on the same storage. Schedule them, test
restores, and keep copies off the host.

- [Backup modes](#backup-modes)
- [One-off backups](#one-off-backups)
- [Scheduled backup jobs](#scheduled-backup-jobs)
- [Retention / pruning](#retention--pruning)
- [Restore](#restore)
- [Proxmox Backup Server (PBS)](#proxmox-backup-server-pbs)
- [Gotchas](#gotchas)

## Backup modes

| Mode | Downtime | Consistency | When |
|------|----------|-------------|------|
| `snapshot` | none | uses storage snapshot / fsfreeze (best with guest agent) | default; live backups |
| `suspend` | brief pause | freezes guest during copy | when snapshot isn't available |
| `stop` | full | cleanest (guest off) | when you need a guaranteed-quiescent image |

For VMs, install the **QEMU guest agent** and the backup will `fsfreeze` the filesystem for an
application-consistent `snapshot` backup. Without it, snapshot mode is crash-consistent.

## One-off backups

```bash
vzdump 101 --storage backupstore --mode snapshot --compress zstd --notes-template '{{guestname}}'
vzdump 101 102 201 --storage pbsbackup --mode snapshot           # several guests
vzdump --all 1 --exclude 9000 --storage backupstore             # everything except templates/excluded
vzdump 101 --dumpdir /mnt/usb --mode stop                       # to a path instead of a storage
```

Useful flags: `--compress zstd` (fast, good ratio; `--zstd N` for thread count), `--mode`,
`--bwlimit KBPS` (throttle), `--mailto admin@lan --mailnotification failure`, `--protected 1`
(exempt from pruning), `--notes-template`. Target storage needs the **`backup`** content type.

## Scheduled backup jobs

Jobs live in `/etc/pve/jobs.cfg`; manage in the UI (`Datacenter → Backup`) or `pvesh`. Schedule uses
systemd calendar syntax.

```bash
# Create a daily 02:00 backup of all guests to PBS, keep a retention ladder
pvesh create /cluster/backup --schedule "02:00" --storage pbsbackup --mode snapshot \
  --all 1 --compress zstd --mailto admin@lan --mailnotification failure \
  --prune-backups "keep-daily=7,keep-weekly=4,keep-monthly=6"
pvesh get /cluster/backup                      # list jobs
pvesh delete /cluster/backup/<job-id>
```

Per-guest tuning: `--exclude-path` for files, `--exclude` for whole guests, `--pool <poolid>` to
back up a resource pool. Schedule examples: `"02:00"`, `"mon..fri 22:00"`, `"*-*-* 03:30"`.

## Retention / pruning

Retention keeps the newest N per bucket and prunes the rest. Set it on the job or storage with
`--prune-backups`:

```
keep-last=N        keep the N most recent
keep-hourly=N      keep-daily=N    keep-weekly=N    keep-monthly=N    keep-yearly=N
```

```bash
vzdump 101 --storage backupstore --prune-backups keep-daily=7,keep-weekly=4
pvesm set backupstore --prune-backups keep-daily=14,keep-monthly=6   # default retention for that storage
prune-backups ...    # mark a critical backup --protected 1 so it's never pruned
```

PBS does pruning on the server (Datastore → Prune & GC) plus garbage collection to reclaim chunks.

## Restore

```bash
# VM
qmrestore /mnt/backupstore/dump/vzdump-qemu-101-2026_06_21-02_00_01.vma.zst 110 \
  --storage local-lvm --unique 1            # --unique regenerates MAC(s) to avoid clashes
# Container
pct restore 210 /mnt/backupstore/dump/vzdump-lxc-201-*.tar.zst \
  --storage local-lvm --unprivileged 1
# From PBS (list snapshots first)
pvesm list pbsbackup
qmrestore pbsbackup:backup/vm/101/2026-06-21T02:00:01Z 110 --storage cephpool
```

Restore to a **new VMID** to keep the original safe while you verify. Use `--unique 1` to avoid MAC
collisions when both will run. Single-file recovery: PBS supports file-level restore from the UI;
otherwise mount the backup/restore to a scratch VMID and copy out.

## Proxmox Backup Server (PBS)

PBS is a dedicated dedup + incremental backup server — far more space-efficient than plain vzdump
dumps, with client-side encryption and verification. Add it as a storage (`pbs` type) and point
backup jobs at it:

```bash
pvesm add pbs pbsbackup --server pbs.lan --datastore main \
  --username backup@pbs --password --fingerprint <PBS-FINGERPRINT> \
  --encryption-key autogen                  # client-side encryption (back up the key!)
```

After the first full backup, subsequent backups send only changed chunks (incremental, deduped).
On the PBS side, schedule **verify** (integrity), **prune** (retention), and **garbage collection**
(reclaim space). Get the fingerprint from the PBS UI or `proxmox-backup-manager cert info`.

## Gotchas

- **Snapshots are not backups.** They share the guest's storage; a dead disk takes both. Use
  `vzdump`/PBS for real protection, and keep a copy off the host.
- **Test restores.** A backup you've never restored is a hope, not a backup. Periodically restore to
  a throwaway VMID.
- **Install the guest agent** for application-consistent VM backups (fsfreeze). Without it, you get
  crash-consistent images (usually fine for Linux, riskier for databases).
- **Watch backup-target capacity** and set retention, or the store fills and jobs start failing.
- **`--mode stop` for databases** if you don't trust crash consistency and can afford the downtime,
  or quiesce the DB via a hook script (`snippets`).
- **Encryption keys for PBS are not recoverable** — if you lose the key, the encrypted backups are
  gone. Store it safely off-box.
