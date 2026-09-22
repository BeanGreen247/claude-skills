# Troubleshooting & Recovery

Where to look, how to read it, and how to recover. General method: **identify the layer** (host /
cluster / storage / guest / network), read its logs and status, change one thing, re-check. Don't
guess-and-restart blindly on a production host.

- [Logs & status — first stops](#logs--status--first-stops)
- [Cluster / quorum / pmxcfs](#cluster--quorum--pmxcfs)
- [Guest won't start](#guest-wont-start)
- [Storage problems](#storage-problems)
- [Networking / locked out](#networking--locked-out)
- [Locks & stuck tasks](#locks--stuck-tasks)
- [Backups & restore](#backups--restore)
- [Boot / upgrade recovery](#boot--upgrade-recovery)
- [PCI passthrough](#pci-passthrough)

## Logs & status — first stops

```bash
journalctl -xe                                   # recent system errors
journalctl -u pve-cluster -u corosync            # cluster layer
journalctl -u pvedaemon -u pveproxy -u pvestatd  # API / UI / stats daemons
journalctl -u qemu-server@101 ; qm status 101    # a specific VM
pct status 201 ; journalctl -u pve-container@201
tail -f /var/log/pve/tasks/active                # live task log; per-task under /var/log/pve/tasks/
pveversion -v                                    # version mismatch after partial upgrade?
dmesg -T | tail                                  # kernel: OOM, disk, hardware errors
```

The UI's per-task log (and `/var/log/pve/tasks/`) usually contains the exact error for a failed
operation — read it before theorizing.

## Cluster / quorum / pmxcfs

Symptom: can't edit anything, `/etc/pve` is read-only, guests won't start on a clustered node.

```bash
pvecm status                                     # Quorate: No?  ->  you've lost majority
systemctl status pve-cluster corosync
journalctl -u corosync -n 100                    # link down? retransmits? token timeouts?
```

- **No quorum** → fix the underlying cause (node down, network partition). To force a single
  surviving node writable *for recovery only*: `pvecm expected 1` (risks split-brain — never on a
  network partition where the other side is alive).
- **pmxcfs not mounting / corrupt** → `systemctl restart pve-cluster`; last resort single-node
  recovery: stop the service and run `pmxcfs -l` (local mode) to get a writable `/etc/pve`.
- **Corosync flapping** → almost always the network (shared/saturated NIC, MTU mismatch, latency).
  Move corosync to a quiet link (see `network.md`/`cluster.md`).

## Guest won't start

```bash
qm start 101                                     # read the actual error it prints
qm showcmd 101 --pretty                          # the exact QEMU command line PVE builds — spot bad device/path
qm config 101
```

Common causes:
- **Storage offline / volume missing** → `pvesm status`; the disk's storage is down or the volume was
  removed. `qm rescan`.
- **EFI/TPM mismatch** → OVMF VM missing `efidisk0`, or Win11 missing `tpmstate0`.
- **CPU flag / model** not available on this node (after migration to different hardware) → adjust
  `--cpu`.
- **Locked** (`can't lock file ... got timeout`) → see Locks below.
- **Out of memory / hugepages** not reservable on the host → `dmesg`, lower memory or free hugepages.

## Storage problems

```bash
pvesm status                                     # which storage is 'inactive' / unknown?
df -h ; lsblk ; zpool status ; lvs -a            # capacity + health at the host layer
zpool status -v ; ceph -s                        # ZFS errors / Ceph health (see ceph.md)
```

- **Thin pool full** (LVM-thin/ZFS/Ceph) → guests hang or go read-only. Free space, expand the pool,
  or delete old snapshots/backups. This is an outage, treat it as urgent.
- **NFS/CIFS storage inactive** → server unreachable, export changed, or `vers=` mismatch; check
  mount with `pvesm status` and `showmount -e <server>`.
- **Snapshot fails** → storage type doesn't support it (plain LVM, raw-on-dir) — see `storage.md`.

## Networking / locked out

```bash
ifreload -a ; ifquery -a ; ip a ; ip r           # apply/inspect host networking
cat /etc/network/interfaces.new                  # staged-but-unapplied changes
pve-firewall status ; pve-firewall compile        # firewall blocking you? (see firewall.md)
```

- **Locked out after a network/firewall change** → use console/IPMI. Revert the bad stanza in
  `/etc/network/interfaces` and `ifreload -a`, or fix the firewall allow rules.
- **Firewall DROP** locked out SSH/UI → from console, add IN ACCEPT for 22/8006 or disable the
  firewall to regain access, then fix rules.

## Locks & stuck tasks

A crashed operation can leave a guest locked (`lock: backup|snapshot|migrate|...`).

```bash
qm config 101 | grep lock                        # see the lock type
qm unlock 101                                     # clear it — ONLY after confirming the operation truly isn't running
pct unlock 201
# Verify nothing is actually still running first:
ps aux | grep -E 'vzdump|qmrestore|kvm.*101'
```

Unlock only when you're sure the original task is dead — clearing a lock under a live backup/migration
can corrupt the guest. Cancel running tasks from the UI (Tasks → Stop) or by killing the task PID
shown in the task log.

## Backups & restore

- **Restore fails on existing VMID** → restore to a new VMID (`qmrestore ... <newid>`), or `--force`
  only after confirming you can overwrite (DATA LOSS).
- **MAC/IP clashes after restore** → `qmrestore --unique 1` regenerates MACs.
- **PBS unreachable / fingerprint changed** → re-check the storage's `--fingerprint`; verify the PBS
  datastore and credentials.
- See `backup.md` for restore mechanics.

## Boot / upgrade recovery

- **No-subscription repo / upgrade issues** → ensure the correct apt repos (`pve-no-subscription` for
  non-enterprise), `apt update && apt dist-upgrade`, check `pveversion -v` for package mismatch.
- **Won't boot after kernel update** → pick a previous kernel from the bootloader; for ZFS-on-root /
  systemd-boot, `proxmox-boot-tool status` / `refresh`.
- **GRUB/initramfs** → boot rescue media, `update-initramfs -u -k all`, `proxmox-boot-tool refresh`.

## PCI passthrough

Getting `qm set --hostpciN` to work:

```bash
dmesg | grep -e DMAR -e IOMMU                    # confirm IOMMU is active
find /sys/kernel/iommu_groups/ -type l | sort    # device-to-group mapping (pass whole groups)
lspci -nnk                                        # device IDs + which driver is bound
```

- Enable IOMMU: kernel cmdline `intel_iommu=on` / `amd_iommu=on` (+ `iommu=pt`), update bootloader,
  reboot.
- Bind the device to `vfio-pci` (blacklist the host driver or use `driver_override`) so the host
  isn't using it.
- GPUs: pass the whole IOMMU group, add `x-vga=1` for primary GPU, and handle the audio function.
- If a group has unrelated devices, you may need ACS override (has security implications) — call that
  out before recommending it.
