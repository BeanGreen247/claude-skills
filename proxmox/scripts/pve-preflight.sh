#!/usr/bin/env bash
# pve-preflight.sh — safe, READ-ONLY orientation snapshot of a Proxmox VE host/cluster.
#
# Run this FIRST, before creating/changing anything, so you know what already exists
# (versions, cluster/quorum, storages + free space, guests + used VMIDs, next free VMID).
# It makes no changes. If a command isn't applicable (e.g. standalone node, no Ceph),
# that section is simply skipped.
#
# Usage:
#   bash scripts/pve-preflight.sh                 # run locally on the node
#   ssh root@NODE 'bash -s' < scripts/pve-preflight.sh   # run over SSH
set -uo pipefail

have() { command -v "$1" >/dev/null 2>&1; }
section() { printf '\n=== %s ===\n' "$1"; }

if ! have pveversion; then
  echo "NOT a Proxmox VE node (pveversion not found)."
  echo "You are likely in ADVISE mode: generate commands for the user to run on their node."
  exit 0
fi

section "Version"
pveversion -v 2>/dev/null | head -n 20

section "Host"
echo "hostname: $(hostname -f 2>/dev/null || hostname)"
echo "uptime:  $(uptime -p 2>/dev/null)"
have free && { echo "memory:"; free -h | sed 's/^/  /'; }
echo "root fs:"; df -h / 2>/dev/null | sed 's/^/  /'

section "Cluster / quorum"
if have pvecm && [ -f /etc/pve/corosync.conf ]; then
  pvecm status 2>/dev/null || echo "(pvecm status failed — node may lack quorum)"
  echo "members:"; cat /etc/pve/.members 2>/dev/null | sed 's/^/  /'
else
  echo "Standalone node (not in a cluster)."
fi

section "Storages (pvesm status)"
pvesm status 2>/dev/null || echo "(pvesm status failed)"

section "Storage config (/etc/pve/storage.cfg)"
cat /etc/pve/storage.cfg 2>/dev/null | sed 's/^/  /' || echo "(unreadable)"

section "Virtual machines (qm list — this node)"
qm list 2>/dev/null || echo "(none / qm unavailable)"

section "Containers (pct list — this node)"
pct list 2>/dev/null || echo "(none / pct unavailable)"

section "Next free VMID"
if have pvesh; then
  nextid=$(pvesh get /cluster/nextid 2>/dev/null)
  echo "pvesh get /cluster/nextid -> ${nextid:-unknown}"
else
  echo "(pvesh unavailable — pick an unused VMID >= 100 not shown above)"
fi

section "Ceph (if configured)"
if have ceph && [ -f /etc/pve/ceph.conf ]; then
  ceph -s 2>/dev/null || echo "(ceph status failed)"
else
  echo "No Ceph configured on this node."
fi

section "HA status (if configured)"
if have ha-manager; then
  ha-manager status 2>/dev/null || echo "(no HA resources / not configured)"
fi

section "Recent cluster/task issues"
echo "Last 5 tasks:"; pvesh get /cluster/tasks 2>/dev/null | head -n 12 | sed 's/^/  /' || true

printf '\nPreflight complete. Use the next-free VMID above; never reuse an in-use one.\n'
