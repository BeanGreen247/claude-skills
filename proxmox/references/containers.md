# Containers (`pct` / LXC)

LXC system containers share the host kernel — lighter and denser than VMs, start in seconds, but
no separate kernel and weaker isolation. Use them for Linux services where you don't need a custom
kernel, kernel modules, or non-Linux OSes. Config: `/etc/pve/lxc/<vmid>.conf`.

- [VM vs container — choosing](#vm-vs-container--choosing)
- [Templates](#templates)
- [Creating a container](#creating-a-container)
- [Privileged vs unprivileged](#privileged-vs-unprivileged)
- [Lifecycle & entering](#lifecycle--entering)
- [Config, resize, mounts](#config-resize-mounts)
- [Snapshots, clones, templates](#snapshots-clones-templates)
- [Migration & backup](#migration--backup)
- [Gotchas](#gotchas)

## VM vs container — choosing

| Want | Use |
|------|-----|
| Custom/older kernel, kernel modules, non-Linux, strong isolation, GPU/PCI passthrough | VM (`qm`) |
| Many lightweight Linux services, fast start, high density, low overhead | Container (`pct`) |

Containers can't run a different kernel and have caveats for Docker-in-CT, NFS mounts, and some
systemd units. When in doubt for an appliance-like Linux workload, a CT is fine; for anything
needing kernel control, use a VM.

## Templates

CTs are created from OS template tarballs (appliance images), not ISOs.

```bash
pveam update                                  # refresh the template catalog
pveam available --section system              # list available distro templates
pveam download local debian-12-standard_12.7-1_amd64.tar.zst   # download into storage 'local' (vztmpl content)
pveam list local                              # show downloaded templates
```

Templates need a storage with **`vztmpl`** content type (default `local`).

## Creating a container

```bash
pct create 201 local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
  --hostname ct-web01 \
  --cores 2 --memory 1024 --swap 512 \
  --rootfs local-lvm:8 \                       # 8 GiB root volume on a rootdir-capable storage
  --net0 name=eth0,bridge=vmbr0,ip=dhcp,firewall=1 \   # or ip=10.0.0.20/24,gw=10.0.0.1
  --nameserver 1.1.1.1 --searchdomain lan \
  --unprivileged 1 \                           # default & recommended (see below)
  --features nesting=1 \                        # needed for systemd-in-systemd, Docker, etc.
  --password \                                  # prompt for root pw; or --ssh-public-keys keys.pub
  --onboot 1 --start 1
```

Notes:
- `--rootfs storage:SIZE` — the storage must support `rootdir` content (LVM-thin, ZFS, dir, Ceph).
- `--ip=dhcp` or a static CIDR with `gw=`. IPv6: `ip6=auto|dhcp|<cidr>`.
- `--features`: `nesting=1` (run containers/systemd inside), `keyctl=1` (some apps), `fuse=1`,
  `mount=nfs;cifs` (allow those mount types inside an unprivileged CT, with care).

## Privileged vs unprivileged

- **Unprivileged (`--unprivileged 1`, default):** container root is mapped to an unprivileged host
  UID (UID shift). Much safer — prefer this. Some operations need extra `--features` or break
  (notably bind-mounting host dirs without matching ownership, certain NFS use).
- **Privileged:** container root == host root namespace-wise. Only when something genuinely needs
  it; treat the CT as if it can affect the host. You cannot convert a running CT between modes —
  restore a backup into the other mode.

For bind mounts into unprivileged CTs, account for the UID offset (host UID `100000` ↔ CT UID `0`).

## Lifecycle & entering

```bash
pct start 201 ; pct shutdown 201 ; pct stop 201 ; pct reboot 201
pct status 201
pct enter 201                      # interactive root shell inside the CT
pct exec 201 -- apt-get update     # run a single command inside
pct console 201                    # attach to the CT console (Ctrl-a q to detach)
pct push 201 ./file /root/file ; pct pull 201 /var/log/syslog ./syslog   # copy in/out
```

## Config, resize, mounts

```bash
pct config 201
pct set 201 --memory 2048 --cores 4
pct set 201 --net0 name=eth0,bridge=vmbr0,ip=10.0.0.21/24,gw=10.0.0.1   # reconfigure NIC
pct resize 201 rootfs +10G                       # GROW the root volume (online on most storages); never shrinks
# Additional mount point (its own volume):
pct set 201 --mp0 local-lvm:20,mp=/data          # 20 GiB volume mounted at /data inside CT
# Bind-mount a host directory into the CT:
pct set 201 --mp1 /host/path,mp=/mnt/host        # bind mount (mind UID shift on unprivileged CTs)
```

## Snapshots, clones, templates

Same storage rules as VMs — snapshots need ZFS/LVM-thin/Ceph/btrfs.

```bash
pct snapshot 201 before-change ; pct listsnapshot 201
pct rollback 201 before-change ; pct delsnapshot 201 before-change
pct clone 201 205 --hostname ct-web02 --full     # full or (omit --full) linked clone
pct template 201                                 # turn into a template to clone from
```

## Migration & backup

```bash
pct migrate 201 node2 --restart        # CTs migrate via stop/move/start (--restart); --online needs shared storage
vzdump 201 --storage backupstore --mode snapshot --compress zstd   # see backup.md
pct restore 210 /path/vzdump-lxc-201-*.tar.zst --storage local-lvm --unprivileged 1
```

CT live migration is limited; the practical path is `--restart` (brief downtime) or a
backup/restore. With shared storage, migration only moves the config + restarts.

## Gotchas

- **Unprivileged + bind mounts:** files appear owned by `nobody`/high UIDs due to the UID shift.
  Set ownership on the host side accounting for the `100000` offset, or use a dedicated volume.
- **Docker inside a CT** needs `--features nesting=1` (and often `keyctl=1`); fuse/overlay quirks
  apply. For heavy container workloads a VM is often cleaner.
- **NFS/CIFS mounts inside an unprivileged CT** require `--features mount=nfs` and may still be
  restricted by AppArmor; mounting on the host and bind-mounting in is more reliable.
- **`pct stop` is forceful** (like pulling power). Prefer `pct shutdown`.
- **Can't switch privileged↔unprivileged in place** — backup and restore into the target mode.
- **Some systemd units fail** in containers (those needing real devices/kernel features); usually
  harmless, but check `systemctl --failed` if a service won't start.
