# Virtual Machines (`qm` / QEMU-KVM)

Managing KVM VMs. Config lives in `/etc/pve/qemu-server/<vmid>.conf`; `qm` validates and
applies changes. Get a free VMID with `pvesh get /cluster/nextid` — never guess.

- [Creating a VM](#creating-a-vm)
- [Disks](#disks)
- [Cloud images & cloud-init](#cloud-images--cloud-init)
- [Inspecting & changing config](#inspecting--changing-config)
- [Lifecycle](#lifecycle)
- [Snapshots](#snapshots)
- [Clones & templates](#clones--templates)
- [Migration](#migration)
- [Guest agent, console, passthrough](#guest-agent-console-passthrough)
- [Gotchas](#gotchas)

## Creating a VM

```bash
qm create 101 \
  --name web01 \
  --ostype l26 \                       # l26 = modern Linux; win11/win10/... for Windows
  --machine q35 \                      # q35 (modern PCIe) vs i440fx (legacy); use q35 for new VMs
  --bios ovmf \                        # ovmf = UEFI (needs an EFI disk, below); seabios = legacy BIOS
  --efidisk0 local-lvm:1,efitype=4m,pre-enrolled-keys=1 \   # required with ovmf; pre-enrolled keys for Secure Boot
  --cpu host \                         # 'host' = best perf (no live-migrate across differing CPUs); use a model (e.g. x86-64-v2-AES) for mixed clusters
  --cores 2 --sockets 1 \
  --memory 4096 \                      # MiB; add --balloon 2048 to allow reclaim down to 2 GiB
  --scsihw virtio-scsi-single \        # best controller; '-single' enables per-disk iothread
  --scsi0 local-lvm:32,discard=on,ssd=1,iothread=1 \        # 32 GiB system disk
  --net0 virtio,bridge=vmbr0,firewall=1 \                   # virtio = paravirtual NIC (fast)
  --ide2 local:iso/debian-12.iso,media=cdrom \              # install media
  --boot order='scsi0;ide2' \
  --agent enabled=1 \                  # enable QEMU guest agent integration (install agent in guest too)
  --onboot 1                           # auto-start with the host
```

Key choices and *why*:
- **`virtio-scsi-single` + `iothread=1`** gives each disk its own I/O thread — meaningfully better
  throughput/latency than the default. Pair `--scsiN ...,iothread=1`.
- **`--cpu host`** exposes all host CPU features (fastest) but blocks live migration to nodes with
  different CPUs. On a mixed cluster choose a baseline model so migration works.
- **`discard=on` + `ssd=1`** lets the guest TRIM/unmap freed blocks back to thin storage (ZFS/
  LVM-thin/Ceph/qcow2), keeping it thin. Needs a guest that issues discards (`fstrim`).
- **OVMF/UEFI** requires `efidisk0`. Windows 11 also needs a TPM: add
  `--tpmstate0 local-lvm:1,version=v2`.

## Disks

```bash
qm set 101 --scsi1 local-lvm:50,discard=on              # add a 50 GiB data disk
qm disk resize 101 scsi0 +20G                           # GROW only — never shrinks (shrinking corrupts)
qm disk move 101 scsi0 cephpool --delete                # move/convert disk to another storage
qm set 101 --delete scsi1                               # detach (becomes 'unused0'); then:
qm set 101 --delete unused0                             # permanently remove the volume (DATA LOSS)
qm rescan --vmid 101                                    # re-detect volumes after manual storage changes
qm importdisk 101 disk.qcow2 local-lvm                  # import a raw/qcow2 image as an unused disk
```

After `importdisk`, attach it: `qm set 101 --scsi0 local-lvm:vm-101-disk-0` then set boot order.
(Newer PVE: `qm disk import 101 disk.qcow2 local-lvm`.)

## Cloud images & cloud-init

The fast way to provision Linux. Download a distro cloud image, import it, attach a cloud-init
drive, then turn it into a template to clone from.

```bash
# 1. Get + import the cloud image as the boot disk
qm create 9000 --name ubuntu-2404-tmpl --memory 2048 --cores 2 \
  --net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-single --ostype l26
qm importdisk 9000 noble-server-cloudimg-amd64.img local-lvm
qm set 9000 --scsi0 local-lvm:vm-9000-disk-0,discard=on,ssd=1
qm set 9000 --ide2 local-lvm:cloudinit            # cloud-init drive (config is generated, not stored on disk)
qm set 9000 --boot order=scsi0 --serial0 socket --vga serial0   # serial console works with cloud images
# 2. Cloud-init settings
qm set 9000 --ciuser admin --cipassword 'changeme' \
  --sshkeys ~/.ssh/id_ed25519.pub \
  --ipconfig0 ip=dhcp \                            # or ip=10.0.0.50/24,gw=10.0.0.1
  --nameserver 1.1.1.1 --searchdomain lan
# 3. Make it a template, then clone per-VM
qm template 9000
qm clone 9000 150 --name app01 --full
qm set 150 --ipconfig0 ip=10.0.0.150/24,gw=10.0.0.1   # override per clone
qm start 150
```

Cloud-init regenerates its config drive on each boot from the `ci*`/`ipconfig*` settings, so
changing them and rebooting re-applies. Use `--citype nocloud` (Linux default) or `configdrive2`.

## Inspecting & changing config

```bash
qm config 101                    # current config
qm config 101 --current          # ignore pending changes
qm pending 101                   # changes awaiting a reboot (hotplug-dependent)
qm set 101 --memory 8192 --cores 4
qm set 101 --hotplug disk,network,usb,memory,cpu      # allow live add of these device classes
```

Memory/CPU hotplug also need guest support (DIMM hotplug, `--numa 1`). Most settings apply live for
disks/NICs; CPU/RAM model changes may require a full stop/start (not just reboot).

## Lifecycle

```bash
qm start 101
qm shutdown 101                  # ACPI graceful (needs guest ACPI/agent); add --timeout 60 --forceStop 1
qm reboot 101                    # graceful reboot
qm stop 101                      # HARD power off (pulls the plug) — data-loss risk, use when hung
qm reset 101                     # hard reset
qm suspend 101 [--todisk 1]      # pause to RAM, or hibernate to disk
qm resume 101
qm status 101                    # verify
```

## Snapshots

Requires snapshot-capable storage (ZFS, LVM-thin, Ceph RBD, qcow2 on `dir`/NFS). Plain LVM and
raw-on-`dir` cannot snapshot (except via the PVE 9 qcow2 volume-chain preview — see
`storage.md`). If snapshots are greyed out, it's almost always the storage type.

```bash
qm snapshot 101 pre-upgrade --vmstate 1 --description "before kernel update"  # --vmstate also saves RAM (live state)
qm listsnapshot 101
qm rollback 101 pre-upgrade       # VM must usually be stopped; reverts disk (+RAM if vmstate)
qm delsnapshot 101 pre-upgrade
```

Snapshots are not backups — they live on the same storage. For real protection use `vzdump`
(see `backup.md`). Long-lived snapshots on thin storage grow and hurt performance — clean them up.

## Clones & templates

```bash
qm template 9000                 # convert a (stopped) VM to a template; its disks become read-only base
qm clone 9000 101 --name web01 --full          # full clone: independent copy (any storage)
qm clone 9000 102 --name web02                 # linked clone: fast, thin, depends on the template (same storage, needs snapshot-capable)
```

Linked clones share the template's base image (space-efficient, instant) but you must keep the
template. Full clones are self-contained. Templates can't be started; clone them.

## Migration

```bash
qm migrate 101 node2 --online                            # live migration (shared storage, no downtime)
qm migrate 101 node2 --online --with-local-disks         # also live-copy local disks (storage migration)
qm migrate 101 node2 --targetstorage cephpool            # map disks to a storage that exists on the target
```

Live migration needs the **same CPU baseline** (see `--cpu`) and the target storage present.
With shared storage (Ceph/NFS) only RAM/state moves — fast. Offline migration (VM stopped) copies
disks. Check `qm status 101` on the target after.

## Guest agent, console, passthrough

```bash
qm agent 101 ping                                # talk to the QEMU guest agent (must be installed in guest)
qm guest cmd 101 get-osinfo
qm terminal 101                                  # serial terminal (needs --serial0 socket)
qm sendkey 101 ctrl-alt-delete
# PCI / GPU passthrough (needs IOMMU enabled on host; see troubleshooting.md):
qm set 101 --hostpci0 0000:01:00,pcie=1,x-vga=1  # pass a GPU; map -mq for multifunction
# USB passthrough:
qm set 101 --usb0 host=1234:5678                 # by vendor:product, or host=<bus>-<port>
```

## Gotchas

- **`qm stop` is a hard power-off.** Use `qm shutdown` for graceful; `stop` only when the guest is
  hung. Risk of FS corruption otherwise.
- **No live shrink.** `qm disk resize` grows only. To shrink, build a smaller disk and migrate data.
- **Windows needs VirtIO drivers** at install time for virtio-scsi/net (mount the virtio-win ISO as
  a second CD-ROM), plus the guest agent + balloon service.
- **`--cpu host` blocks live migration** across differing CPUs. Pick a model for portability.
- **Ballooning ≠ free RAM.** Set `--balloon` below `--memory` to allow reclaim; install the balloon
  driver in-guest or it won't return memory.
- **Removing a disk is two steps** (`--delete scsiN` detaches → `unusedN`; deleting `unusedN`
  destroys data). Confirm before the second step.
