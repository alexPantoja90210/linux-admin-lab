# Linux Admin Lab

A home lab for Linux system administration practice, built around the **RHCSA (EX200) exam on RHEL 10** and the day-to-day work of an enterprise Linux administrator: OS upgrades, patch management, vulnerability remediation, high availability and monitoring.

Everything runs on a single Windows laptop with VirtualBox. Every step is documented so the lab can be rebuilt from scratch, and every problem hit along the way is recorded with its root cause and fix.

## Lab topology

```
Windows 11 host (Ryzen 7 5700U, 16 GB RAM)
└── VirtualBox 7.2.20  (running on top of Hyper-V, see ADR 0001)
    └── NAT Network "labnet"  10.10.10.0/24, gateway 10.10.10.1, DHCP
        ├── rhel10-template   RHEL 10.2 minimal   snapshot: base   (golden image, never booted after cloning)
        │   ├── node1         linked clone        10.10.10.3   ssh 127.0.0.1:2221   + 2 x 2 GB practice disks
        │   └── node2         linked clone        10.10.10.4   ssh 127.0.0.1:2222
        └── rhel9-template    RHEL 9.8 minimal    snapshot: base   (source for the RHEL 9 -> 10 upgrade lab)
```

| VM | OS | vCPU | RAM | Disk | Role |
|---|---|---|---|---|---|
| `rhel10-template` | RHEL 10.2 | 2 | 2 GB | 20 GB dynamic | Golden image for all RHEL 10 nodes |
| `node1`, `node2` | RHEL 10.2 | 2 | 2 GB | Linked clone | Exam objectives, clustering, patching |
| `rhel9-template` | RHEL 9.8 | 2 | 2 GB | 20 GB dynamic | Leapp in-place upgrade practice |

IP addresses come from DHCP and can change. Static addressing with `nmcli` is part of the roadmap. The VMs are reached from Windows over SSH through NAT Network port forwarding (see [lab setup](docs/lab-setup.md#8-ssh-from-windows)).

## Repository layout

| Path | Contents |
|---|---|
| [`docs/lab-setup.md`](docs/lab-setup.md) | Step-by-step build of the lab, reproducible from zero |
| [`docs/lessons-learned.md`](docs/lessons-learned.md) | Problems hit during the build, root cause and fix |
| [`docs/decisions/`](docs/decisions/) | Architecture decision records (ADR) |
| [`docs/jira-project.md`](docs/jira-project.md) | How the lab is tracked in Jira, and Jira administration lessons |
| [`docs/sprints/`](docs/sprints/) | Sprint logs: goal, work items, retrospective |
| [`docs/study/`](docs/study/) | Exam objective self-assessments |
| [`docs/runbooks/`](docs/runbooks/) | Step-by-step procedures from each lab exercise |
| [`scripts/new-template-vm.ps1`](scripts/new-template-vm.ps1) | Creates a VM ready to install from a boot ISO |
| [`scripts/new-linked-clones.ps1`](scripts/new-linked-clones.ps1) | Creates linked clones from a template snapshot |
| [`scripts/generalize-clone.sh`](scripts/generalize-clone.sh) | Gives a fresh clone its own identity (hostname, machine-id, subscription) |

## Roadmap

Work is planned in one-week sprints and tracked in Jira (project `LNX`). Each week adds both a Linux skill and a Jira administration skill.

| Week | Linux | Status |
|---|---|---|
| W00 | Lab setup: VirtualBox, templates, linked clones, network | Done |
| W01 | RHCSA: storage, partitions, LVM, persistent mounts | In progress (Sprint 2) |
| W02 | RHCSA: systemd, users and groups, permissions, SELinux | Planned |
| W03 | RHCSA: networking with nmcli, firewalld, dnf, podman, boot recovery | Planned |
| W04 | RHCSA mock exams and EX200 | Planned |
| W05 | OS upgrade RHEL 9 to 10 with Leapp, snapshot rollback | Planned |
| W06 | Patch management, kernel updates, kpatch, Ansible batch patching | Planned |
| W07 | Vulnerability remediation with OpenSCAP, CIS hardening | Planned |
| W08 | High availability: Pacemaker/Corosync, floating IP, nginx | Planned |
| W09 | Monitoring and troubleshooting: Prometheus, Grafana, induced failures | Planned |
| W10 | Ubuntu administration differences | Planned |

## Ground rules

- No credentials, subscription details or VM disks in this repository.
- Every lab exercise ends with a runbook in `docs/`.
- Take a snapshot before any exercise that touches storage, boot or the firewall.
- Do not run heavy disk workloads on the host while lab VMs are running (see [lessons learned](docs/lessons-learned.md)).
