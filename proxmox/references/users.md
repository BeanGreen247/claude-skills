# Users, Roles & Permissions (`pveum`)

PVE access control is **role-based** over a **path hierarchy**, with users living in **authentication
realms**. A permission = (user/group/token) × role × path. Manage it all with `pveum`; config is
`/etc/pve/user.cfg`.

- [The model](#the-model)
- [Realms](#realms)
- [Users & groups](#users--groups)
- [Roles](#roles)
- [ACLs (granting access)](#acls-granting-access)
- [API tokens](#api-tokens)
- [Two-factor auth](#two-factor-auth)
- [Gotchas](#gotchas)

## The model

- **Realm** — where users authenticate: `pam` (Linux users), `pve` (Proxmox's own user DB), or
  external `ldap`/`ad`/`openid`. Users are written `user@realm` (e.g. `alice@pve`, `root@pam`).
- **Role** — a named set of privileges (e.g. `PVEVMAdmin`).
- **Path** — what the permission applies to, hierarchical: `/`, `/vms`, `/vms/101`, `/storage/local`,
  `/nodes/node1`, `/pool/dev`, `/sdn`, `/access`.
- **ACL** — binds a user/group/token to a role at a path, optionally **propagating** to children.

Permissions inherit down the path tree (with propagate on), so grant at the highest sensible level.

## Realms

```bash
pveum realm list
pveum realm add corp-ldap --type ldap --server1 ldap.corp --base-dn "dc=corp,dc=com" \
  --user-attr uid --bind-dn "cn=svc,dc=corp,dc=com"
pveum realm add sso --type openid --issuer-url https://idp.example/.well-known/... \
  --client-id pve --client-key <secret>
pveum realm sync corp-ldap                 # sync users/groups from LDAP/AD
```

`pam` = the node's Linux accounts (root@pam is the superuser). `pve` = self-contained PVE users.
Use LDAP/AD/OIDC to centralize identity for teams.

## Users & groups

```bash
pveum user add alice@pve --firstname Alice --email alice@lan
pveum passwd alice@pve                       # set/change password (pve realm)
pveum user list
pveum group add devops
pveum user modify alice@pve --groups devops
pveum user delete alice@pve
```

Prefer assigning permissions to **groups**, then add users to groups — easier to manage at scale.

## Roles

Built-in roles cover most needs: `Administrator` (all), `PVEAdmin`, `PVEVMAdmin`, `PVEVMUser`,
`PVEDatastoreAdmin`, `PVEDatastoreUser`, `PVEAuditor` (read-only), `PVEPoolAdmin`, `PVESDNAdmin`,
`NoAccess`. Create custom ones from individual privileges when built-ins don't fit:

```bash
pveum role list
pveum role add VMOperator --privs "VM.PowerMgmt VM.Console VM.Audit"
pveum role modify VMOperator --privs "VM.PowerMgmt VM.Console VM.Audit VM.Snapshot" --append
```

Privileges are grouped by area: `VM.*`, `Datastore.*`, `Sys.*`, `Pool.*`, `SDN.*`, `Realm.*`,
`User.Modify`, etc. Grant the minimum that does the job.

## ACLs (granting access)

```bash
# Let the devops group manage all VMs:
pveum acl modify /vms --groups devops --roles PVEVMAdmin
# Read-only audit of the whole datacenter for one user:
pveum acl modify / --users auditor@pve --roles PVEAuditor
# Scope a user to a single VM:
pveum acl modify /vms/101 --users alice@pve --roles PVEVMUser
# Storage-only admin:
pveum acl modify /storage/cephrbd --groups storageops --roles PVEDatastoreAdmin
pveum acl list
pveum acl delete /vms/101 --users alice@pve --roles PVEVMUser
```

**Resource pools** group guests/storage so you can grant access to a set at once:

```bash
pveum pool add dev --comment "Dev environment"
pveum pool modify dev --vms 101,102 --storage local-lvm
pveum acl modify /pool/dev --groups devs --roles PVEVMAdmin
```

Use pools + group ACLs to give a team self-service over just their guests.

## API tokens

Tokens authenticate automation without a password and can be scoped tighter than the owning user —
ideal for scripts/Terraform/monitoring. **The secret is shown once at creation.**

```bash
pveum user token add svc@pve automation --comment "terraform" --privsep 1
# -> prints tokenid 'svc@pve!automation' and a secret value (SAVE IT NOW)
# With privsep=1, the token has NO rights until you grant them explicitly:
pveum acl modify /vms --tokens 'svc@pve!automation' --roles PVEVMAdmin
pveum user token list svc@pve
pveum user token remove svc@pve automation
```

`--privsep 1` (privilege separation) means the token's permissions are independent of and ≤ the
user's — grant it its own ACLs. `--privsep 0` makes it inherit the user's full rights (convenient,
less safe). Used as header: `Authorization: PVEAPIToken=svc@pve!automation=<secret>` (see `api.md`).

## Two-factor auth

```bash
pveum user tfa list
# TOTP/WebAuthn/Recovery keys are usually enrolled per-user in the UI (User → TFA).
# Enforce realm-wide TFA in the realm settings; recovery keys via:
pveum user tfa delete <user> <id>     # remove a TFA factor (admin recovery)
```

Require TFA at least for accounts with broad privileges (and protect `root@pam`).

## Gotchas

- **`root@pam` is the master account** — secure it (strong password, TFA, restrict SSH). It bypasses
  ACLs.
- **Least privilege + propagation:** grant at the right path level with propagate, to groups not
  individuals. Over-granting at `/` is the common mistake.
- **Token secrets are shown once** — capture at creation; you can't retrieve them later, only
  regenerate (which invalidates the old one).
- **`privsep` confusion:** a `privsep=1` token starts with zero access until you add ACLs for the
  *token id*; granting the user roles doesn't help it.
- **LDAP/AD users need a sync** (`pveum realm sync`) and ACLs before they can do anything beyond log
  in.
