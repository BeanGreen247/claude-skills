---
name: linux-systems-engineer
description: |
  TRIGGER — read before any Linux infrastructure, systems administration, or
  on-prem ops task: RHEL/Linux server administration, systemd services,
  Ansible playbooks/roles, Cloudera/Hadoop cluster ops (HDFS, YARN, Kafka,
  Hive, Impala, HBase, Spark, Cloudera Manager), Apache Airflow deployment
  and operations (not just DAG authoring), Prometheus/Grafana/Zabbix
  monitoring stacks, nginx + TLS (incl. self-signed CA), LDAP/AD auth
  integration, SMTP relay config, Proxmox VE/KVM/LXC/Docker/ZFS
  virtualization and homelab infra, backup/restore design (rclone, DB-native
  backup like sqlite3 .backup / pgBarman), Tailscale networking, or
  Zabbix/Grafana alerting rules. This is the user's own professional domain
  (Systems Engineer / Data Platforms Specialist, 4+ yrs, Cloudera CDH
  production clusters + homelab Proxmox) — match their actual house style
  below, don't default to generic cloud-native advice.
  SKIP for cloud-managed equivalents (GKE/Cloud Run/managed Airflow —
  use gcloud/cloud-run-basics/managed-airflow-* skills instead) or for
  pure application code with no systems/infra component.
---

# Linux Systems Engineer

Ground infrastructure work in the same discipline this profile was built on: factory-floor process rigor (Hyundai/OPmobility background) applied to servers — reliable, documented, zero-surprise changes over clever ones.

## House style (derived from this user's actual production work)

- **Prefer stdlib/no-dependency tooling when it's a good fit.** Their `cm-tool-pid` monitoring tool is Python stdlib-only (no Flask/Django) with its own `http.server`-based web GUI. Default to this for small internal ops tools — a new framework dependency needs to earn its place over `http.server`, `sqlite3`, `configparser`, and the standard library. See the `python-engineer` skill for the stdlib-web patterns this implies.
- **Zero-downtime by construction, not by luck.** Their Airflow SQLite backup system waits for a schedule-aware idle window (queries DAG run state directly from SQLite, 10-minute idle check) before running `sqlite3 .backup`, with no Airflow CLI dependency. Any backup/migration/restart design should follow the same shape: detect a genuinely safe window from real state, don't assume one or force a maintenance window unnecessarily. Their 1.5TB ZFS pool migration was zero-downtime with scripted validation — validate the target state programmatically, don't eyeball it.
- **TLS and auth are not optional extras.** Production Airflow here runs behind nginx with a self-signed CA and LDAP auth via `FabAirflowSecurityManagerOverride`; the homelab uses Tailscale for private network access instead of exposing ports. Default new internal services to the same posture: TLS in front (nginx + real or self-signed CA), auth integrated (LDAP/AD where enterprise, otherwise don't skip auth just because it's "internal").
- **Monitor everything, alert on the thing that matters.** Standard stack here is Prometheus + Grafana + Zabbix, with specific attention to failure correlation (their Impala JVM heap/GC dashboards alert on GC saturation *and* multi-node failure correlation, not just single-host thresholds). When adding monitoring, ask what the alert should catch (a cascading failure, not just "CPU high") before writing the rule. See the `observability-and-instrumentation` skill for the general framework; apply it with Prometheus/Grafana/Zabbix as the default stack, not a generic APM.
- **Ansible for anything repeated more than once.** Both enterprise (ČEZ, TietoEVRY) and homelab (Proxmox VM/LXC provisioning, open-sourced as `ansible-proxmox-ve-usage-status` / `proxmox-ve-vms-ansible`) work runs through Ansible playbooks/roles, not one-off shell scripts left behind. A manual fix applied twice should become a playbook the third time.
- **Document for handover, in the audience's language.** Internal docs at ČEZ are maintained in Czech for compliance/handover (TSD). When asked to document ops work, ask/confirm the target audience and language rather than assuming English-only — this user actually operates bilingually for this purpose.
- **Web GUIs for ops tools follow a specific shape**, per `cm-tool-pid`: environment-colored banners (dev/test/prod visually distinct), per-host resource cards (CPU/MEM/JVM heap), drill-down detail views with time-series charts, configurable refresh/time-range, and outbound alerting (Teams/Zabbix) with per-alert ack/assign/snooze — not just a read-only dashboard. Use this as the template when building an internal monitoring/ops UI from scratch.

## Stack reference (what "normal" looks like for this user)

- **OS/infra:** RHEL 8/9, Debian/Ubuntu/Kubuntu, systemd, nginx, Proxmox VE, KVM, LXC, Docker, ZFS (incl. ARC tuning), Tailscale
- **Big data / orchestration:** Cloudera CDH 7.1.9 (HDFS, YARN, Kafka, Hive, Impala, HBase, Spark), Apache Airflow 3.x (deployment/ops — for DAG authoring specifics defer to `managed-airflow-dag-authoring`/`-troubleshooting`, but note this user runs self-hosted Airflow with a SQLite metadata DB + systemd, not managed Airflow, so cloud-managed guidance doesn't apply directly), JupyterHub
- **Monitoring/automation:** Prometheus, Grafana, Zabbix, Ansible, Bash, cron, Cloudera Manager API, general REST APIs
- **Dev:** Python (stdlib-first: `http.server`, `sqlite3`, `configparser`), Bash, PHP, JavaScript, SQL (PostgreSQL, MariaDB, SQLite)
- **Security/auth:** TLS/SSL (nginx, self-signed CA, openssl), LDAP/Active Directory, SMTP relay
- **Homelab specifically:** Proxmox REST API for automated provisioning, rclone for offsite backup, Home Assistant + Node-RED + Zigbee2MQTT (local-only, no cloud dependency) on Raspberry Pi with CPU governor/ZRAM/Docker resource-limit tuning

## When to defer to other skills

- Writing/debugging actual Python code against this stack (Cloudera Manager API clients, stdlib web tools, Bash automation) → `python-engineer`
- Airflow DAG content itself (not the platform ops around it) → `managed-airflow-dag-authoring` / `managed-airflow-dag-troubleshooting`
- General logging/metrics/tracing framework beyond "which stack" → `observability-and-instrumentation`
- Cloud-managed equivalents of any of the above (GKE instead of on-prem RHEL, Cloud Composer instead of self-hosted Airflow) → the `gcloud`/`cloud-run-basics`/Google skills, and flag the mismatch since this user's real environment is on-prem/self-hosted first
