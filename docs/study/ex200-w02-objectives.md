# EX200 W02 objectives: self-assessment

Objectives for the RHCSA exam (EX200, RHEL 10) practised in W02: users and groups, security (except the firewall), and the systemd, process, log and scheduling objectives.

Source: [official EX200 objectives](https://www.redhat.com/en/services/training/ex200-red-hat-certified-system-administrator-rhcsa-exam?section=objectives).

| Section | Wording |
|---|---|
| Manage users and groups | Checked against the official page on 2026-10-04 |
| Manage security | Checked against the official page on 2026-10-04 |
| Operate running systems | Checked against the official page on 2026-10-04 |
| Deploy, configure, and maintain systems | **Draft**, written from memory: check before rating (LNX-43) |

Ratings, as in the [storage self-assessment](ex200-storage-objectives.md):

- **Confident:** done in real work, can do it without looking anything up.
- **Rusty:** done before, needs to review commands and options.
- **New:** never done.

## Manage users and groups

| Objective | Rating | Practised in |
|---|---|---|
| Create, delete, and modify local user accounts | | LNX-45 |
| Change passwords and adjust password aging for local user accounts | | LNX-45 |
| Create, delete, and modify local groups and group memberships | | LNX-45 |
| Configure privileged access | | LNX-45 |

## Manage security

| Objective | Rating | Practised in |
|---|---|---|
| Manage default file permissions | | LNX-46 |
| Diagnose and correct file permission problems (from W01) | | LNX-46 |
| Configure key-based authentication for SSH | | LNX-47 |
| Set enforcing and permissive modes for SELinux | | LNX-50 |
| List and identify SELinux file and process context | | LNX-50 |
| Restore default file contexts | | LNX-50, LNX-51 |
| Manage SELinux port labels | | LNX-50, LNX-51 |
| Use Boolean settings to modify system SELinux settings | | LNX-50, LNX-51 |

- *Diagnose and correct file permission problems* is in the **Create and configure file systems** section of the exam; it is practised here because it fits with permissions.
- *Configure firewall settings using firewall-cmd/firewalld* is in this section but practised in W03.
- The RHEL 10 list has no separate objective for diagnosing SELinux policy violations. The drill (LNX-51) stays: it practises the three objectives above starting from a denial, which is how they show up in real work.

## Operate running systems

| Objective | Rating | Practised in |
|---|---|---|
| Boot, reboot, and shut down a system normally | | LNX-48 |
| Boot systems into different targets manually | | LNX-48 |
| Identify CPU/memory intensive processes and kill processes | | LNX-49 |
| Adjust process scheduling | | LNX-49 |
| Manage tuning profiles | | LNX-49 |
| Locate and interpret system log files and journals | | LNX-49 |
| Preserve system journals | | LNX-49 |
| Start, stop, and check the status of network services | | LNX-48 |
| Securely transfer files between systems | | LNX-47 |

## Deploy, configure, and maintain systems

| Objective | Rating | Practised in |
|---|---|---|
| Schedule tasks using at and cron | | LNX-48 |
| Start and stop services and configure services to start automatically at boot | | LNX-48 |
| Configure systems to boot into a specific target automatically | | LNX-48 |
| Configure time service clients | | LNX-48 |

## Out of scope for W02

Listed so they are not lost; practised in W03 (LNX-4):

- Configure firewall settings using firewall-cmd/firewalld (Manage security).
- Interrupt the boot process in order to gain access to a system (Operate running systems).
- Modify the system bootloader.
- Install and update software packages; package repositories.
- Networking, hostname resolution, containers.

## Review after the sprint

Re-rate each objective at the end of Sprint 3, after running each lab again without notes.
