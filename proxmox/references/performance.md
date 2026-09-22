# Performance Tuning & Best Practices (Guests + Host)

Defaults are safe, not optimal. Most guest performance comes down to: use **paravirtual (virtio)
devices**, match the **CPU model** to your migration needs, pick the right **disk cache + iothread**,
and don't starve the host. Measure before and after — `qm config`, in-guest `iostat`/`mpstat`, and
host `pveperf`/`zpool iostat`.

- [VM CPU](#vm-cpu)
- [VM memory & ballooning](#vm-memory--ballooning)
- [VM disk / storage](#vm-disk--storage)
- [VM networking](#vm-networking)
- [Windows guests](#windows-guests)
- [Containers](#containers)
- [Host & storage](#host--storage)
- [Quick checklist](#quick-checklist)

## VM CPU

- **CPU type** (`--cpu`): `host` passes through all host features = fastest, but the VM can only
  live-migrate to identical CPUs. On a mixed cluster pick the highest common model
  (`x86-64-v2-AES`, `x86-64-v3`, or a named model) so migration still works. Single node → `host`.
- **Topology:** prefer **cores over sockets** (`--cores 8 --sockets 1`) unless the guest licenses
  per-socket or you're modeling NUMA. Don't allocate more vCPUs than the workload uses — overcommit
  causes scheduling contention (high CPU steal in-guest).
- **NUMA:** on multi-socket hosts set `--numa 1` and align cores to expose host NUMA topology;
  required for memory hotplug and helps big guests keep memory local.
- **Mitigations/flags:** add features like `+aes`, `+pdpe1gb` via the CPU args only when needed.
- Avoid massive overcommit; check in-guest **CPU steal %** — high steal means the host is oversold.

## VM memory & ballooning

- **Ballooning:** set `--balloon` *below* `--memory` to let the host reclaim idle RAM (e.g.
  `--memory 8192 --balloon 4096` → 4–8 GiB range). Requires the balloon driver in-guest (virtio,
  Windows needs the service). Without the driver it won't give memory back.
- Don't overcommit RAM hard — unlike CPU, hitting the wall means swapping/OOM. Leave headroom for
  the host (ZFS ARC especially, below).
- **Hugepages** (`--hugepages 2|1024`) reduce TLB pressure for large, latency-sensitive guests
  (databases); reserve them on the host first. Niche — only when you've measured a need.

## VM disk / storage

This is where most "my VM is slow" problems live.

- **Controller:** `--scsihw virtio-scsi-single` and attach disks as `scsiN`. `-single` gives each
  disk its own controller so `iothread=1` actually parallelizes I/O.
- **`iothread=1`** on each disk moves its I/O off the main QEMU thread — big win under load.
- **Cache mode** (`cache=`):
  - `none` (default, recommended) — uses O_DIRECT, host page cache bypassed, safe with barriers.
  - `writeback` — faster writes by caching in host RAM, **risk of data loss on host crash**; only
    with a UPS/BBU and when you accept the risk.
  - `writethrough` — safe but slow writes; `directsync` — safest, slowest.
  - Leave at `none` unless you have a measured reason and understand the durability tradeoff.
- **`discard=on` + `ssd=1`** keeps thin storage thin (guest TRIM) and tells the guest it's SSD
  (disables defrag/optimizes scheduler). Run `fstrim` / enable the timer in-guest.
- **`aio=`**: `io_uring` (modern default, good) vs `native` (needs `cache=none`, strong for
  high-IOPS block storage) vs `threads`. Default is usually right.
- **Format:** raw (on LVM-thin/ZFS/Ceph) is fastest; qcow2 only where you need file-based snapshots.
- **Don't put guest disks on the same spindle as the host OS** under heavy I/O; separate fast storage
  for guests (NVMe/SSD).

## VM networking

- Use the **virtio (paravirtual) NIC** (`--net0 virtio,bridge=vmbr0`) — far faster than emulated
  e1000/rtl8139. Install virtio-net drivers in Windows.
- **MTU / jumbo frames:** for storage/replication networks, set MTU 9000 end-to-end (host bridge +
  switch + guest) to cut overhead — only if every hop supports it.
- **Multiqueue:** for high-throughput multi-core guests set `--net0 virtio,...,queues=N` (N ≈ vCPUs)
  so the NIC scales across cores; enable the queues in-guest (`ethtool -L`).
- **`firewall=1`** adds per-NIC filtering (see `firewall.md`); negligible cost, real safety.
- Disable hardware offloads only to debug; normally leave them on.

## Windows guests

- Install **VirtIO drivers** (virtio-win ISO) at install time for `virtio-scsi`/`virtio-net`, plus
  the **QEMU guest agent** and **balloon service** afterward.
- Use `--ostype win10`/`win11`, `--machine q35`, `--bios ovmf` (+ `--tpmstate0` for Win11).
- Set the disk `cache=none`, `discard=on`, `iothread=1`; NIC `virtio`. Disable unneeded visual
  effects/telemetry in-guest. Consider `--cpu host,hidden=1` for some workloads.

## Containers

- CTs already run near-native (shared kernel) — overhead is mostly I/O and limits, not CPU virt.
- Set realistic `--cores`/`--memory`/`--swap`; CPU is enforced via cgroups, so over-allocating is
  less harmful than for VMs but still causes contention.
- Put CT root volumes on fast, snapshot-capable storage (ZFS/LVM-thin) and use `pct fstrim <vmid>`
  to reclaim space on thin storage.
- `--features nesting=1` only when needed (Docker/systemd-in-CT). Avoid privileged unless required.

## Host & storage

- **ZFS ARC:** ZFS caches in RAM and by default can take up to 50% of host memory — which competes
  with guests. Cap it: set `zfs_arc_max` (bytes) in `/etc/modprobe.d/zfs.conf` and `update-initramfs
  -u`, sizing for your guest RAM needs. `arc_summary` / `arcstat` to monitor.
- **ZFS layout:** `ashift=12`, `compression=lz4` (free win), `atime=off`; mirrors/RAIDZ per your
  IOPS vs capacity needs; add a fast SLOG/L2ARC only for measured workloads. Avoid RAIDZ for
  high-IOPS random VM workloads (mirrors are better there).
- **Don't run guests on consumer SSDs without PLP** for sync-heavy workloads (DBs, Ceph) — they
  tank under fsync. Enterprise/datacenter SSDs matter for Ceph and ZFS SLOG.
- **Separate networks** for cluster/corosync, storage/Ceph, and VM traffic so latency-sensitive
  corosync isn't starved (see `network.md`); corosync hates jitter.
- **`pveperf`** gives a quick host baseline (CPU bogomips, fsync/s, DNS, buffered reads). Low
  fsync/s ⇒ slow storage ⇒ slow guests.
- Keep the host lean — it's a hypervisor, not a workstation. Don't install extra services on it.

## Quick checklist

For a new Linux VM that should be fast:

```bash
qm set <vmid> \
  --scsihw virtio-scsi-single \
  --scsi0 <storage>:<size>,iothread=1,discard=on,ssd=1,cache=none \
  --net0 virtio,bridge=vmbr0,firewall=1 \
  --cpu host \                # or a model on a mixed cluster
  --cores 4 --sockets 1 \
  --memory 8192 --balloon 4096 \
  --agent enabled=1
# then in-guest: install qemu-guest-agent, enable fstrim.timer, install virtio drivers (Windows)
```
