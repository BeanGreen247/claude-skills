# REST API & Automation (`pvesh`, tokens, curl)

Everything the UI and CLI tools do goes through the same REST API (`pveproxy`, port 8006). `pvesh`
is the local CLI wrapper over it — great for scripting and for discovering exactly what endpoint a UI
action uses. For remote automation, use an **API token** (see `users.md`).

- [pvesh — the local API CLI](#pvesh--the-local-api-cli)
- [Discovering endpoints](#discovering-endpoints)
- [Common calls](#common-calls)
- [Remote access with curl](#remote-access-with-curl)
- [Tasks (async operations)](#tasks-async-operations)
- [Gotchas](#gotchas)

## pvesh — the local API CLI

`pvesh` maps HTTP verbs to subcommands on API paths, run locally as root (no auth needed on-box):

```bash
pvesh get /version
pvesh get /nodes
pvesh get /cluster/resources --type vm           # all VMs across the cluster
pvesh get /cluster/nextid                        # next free VMID
pvesh get /nodes/<node>/qemu/101/status/current  # live status of a VM
pvesh create /nodes/<node>/qemu/101/status/start # start it (POST)
pvesh set /nodes/<node>/qemu/101/config --memory 8192
pvesh delete /nodes/<node>/qemu/101 --purge 0    # destroy (DESTRUCTIVE — confirm)
```

Verb mapping: `get`=GET, `create`=POST, `set`=PUT, `delete`=DELETE. Add `--output-format json`
for machine-readable output.

## Discovering endpoints

```bash
pvesh ls /nodes/<node>/qemu/101                  # list child paths of an endpoint
pvesh usage /nodes/<node>/qemu --verbose         # show parameters for the calls under a path
pvesh help /cluster/backup                       # help for an endpoint
```

Use the **full API reference** at `https://pve.proxmox.com/pve-docs/api-viewer/` to see every
endpoint, parameter, type, and required privilege. When you don't know the path, do a UI action and
check `journalctl`/`/var/log/pveproxy/access.log`, or browse with `pvesh ls`.

## Common calls

```bash
# Create a VM via the API
pvesh create /nodes/<node>/qemu --vmid 120 --name api-vm --memory 2048 --cores 2 \
  --net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-single --scsi0 local-lvm:16
# Clone, snapshot, migrate
pvesh create /nodes/<node>/qemu/9000/clone --newid 121 --name web --full 1
pvesh create /nodes/<node>/qemu/121/snapshot --snapname pre --vmstate 0
pvesh create /nodes/<node>/qemu/121/migrate --target node2 --online 1
# Storage / cluster
pvesh get /nodes/<node>/storage --content images
pvesh get /cluster/ha/status/current
```

## Remote access with curl

Use an API token (no login ticket needed; tokens don't require the CSRF token that
password-cookie auth does):

```bash
TOKEN='PVEAPIToken=svc@pve!automation=<secret>'
PVE='https://pve.lan:8006/api2/json'

curl -s -H "Authorization: $TOKEN" "$PVE/cluster/resources?type=vm" | jq
curl -s -H "Authorization: $TOKEN" -X POST "$PVE/nodes/node1/qemu/121/status/start"
curl -s -H "Authorization: $TOKEN" -X PUT  "$PVE/nodes/node1/qemu/121/config" \
  --data-urlencode 'memory=4096'
```

Add `-k`/`--cacert` depending on whether you trust the node's cert. For password auth instead, POST
to `/access/ticket` to get a ticket + CSRFPreventionToken, then send both — but tokens are simpler
and safer for automation. Higher-level tooling (the Proxmox **Terraform/OpenTofu** provider,
**Ansible** modules) wraps all of this.

## Tasks (async operations)

Long operations (clone, migrate, backup) return a **UPID** task id and run asynchronously. Poll it:

```bash
upid=$(pvesh create /nodes/node1/qemu/9000/clone --newid 121 --full 1)
pvesh get /nodes/node1/tasks/$upid/status        # status: running / stopped + exitstatus
pvesh get /nodes/node1/tasks/$upid/log           # task log output
pvesh get /cluster/tasks                          # recent tasks cluster-wide
```

Wait for `status: stopped` with `exitstatus: OK` before assuming success — don't chain dependent
calls (e.g. start a clone) until the task finishes.

## Gotchas

- **Tokens vs password auth:** tokens use the `Authorization: PVEAPIToken=...` header and skip CSRF;
  password/cookie auth needs a ticket *and* the `CSRFPreventionToken` header on writes. Tokens are
  the right call for scripts.
- **`privsep` tokens have no rights** until you grant ACLs to the token id (see `users.md`).
- **Operations are async** — honor the UPID/task status instead of assuming immediate completion.
- **`/api2/json` vs `/api2/extjs`:** use the `json` base for scripting.
- **Don't hardcode the node** when a guest can move — resolve its current node via
  `/cluster/resources?type=vm` first.
- **Rate/connection limits:** `pveproxy` isn't a high-QPS API gateway; batch sensibly and reuse
  connections.
