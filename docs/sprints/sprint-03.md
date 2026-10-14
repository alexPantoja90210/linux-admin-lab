# Sprint 3: RHCSA users, security and systemd

- **Dates:** 2026-10-04 to 2026-10-11
- **Goal:** Users, permissions, SSH keys, systemd and SELinux objectives practised and documented.
- **Epic:** LNX-3 (W02)
- **Planned:** 21 story points, 10 work items
- **Result:** 17 of 21 points done (81%), 8 of 10 work items. LNX-51 and LNX-52 (2 points each) carried over to the next sprint.

## Work items

Ordered as they should be done. Each lab builds on the state left by the one before it.

| Key | Work item | Type | Points | VM | Status |
|---|---|---|---|---|---|
| LNX-43 | Review EX200 W02 objectives and self-assess | Study | 1 | | Done |
| LNX-44 | Jira: custom fields and separate create / edit / transition screens | Task | 3 | | Done |
| LNX-45 | Users and groups: accounts, password aging and sudo rules | Lab | 2 | node1 | Done |
| LNX-46 | Permissions: umask, set-GID shared directory, diagnose permission problems | Lab | 2 | node1 | Done |
| LNX-47 | SSH key-based authentication and secure file transfer between nodes | Lab | 1 | node1 → node2 | Done |
| LNX-48 | systemd: services, boot targets, at, cron and timers, time service client | Lab | 3 | node1 | Done |
| LNX-49 | Processes, tuning profiles, logs and persistent journal | Lab | 2 | node1 | Done |
| LNX-50 | SELinux: modes, contexts, restorecon, port labels and booleans | Lab | 3 | node2 | Done |
| LNX-51 | Drill: diagnose and fix SELinux denials | Lab | 2 | node2 | Carried over |
| LNX-52 | W02 runbooks in the repo | Task | 2 | | Carried over |

## Sprint start

- Sprint 2 closed and **LNX Sprint 3** started on 2026-10-04, with LNX-43 to LNX-52.
- Still to do: re-rate the storage objectives (carried over from [Sprint 2](sprint-02.md#open-at-sprint-end)).
- Snapshots: `pre-w02` on node1 and node2 before LNX-45; `pre-selinux` on node2 before LNX-50.

## Scope decisions

- **Firewall stays in W03.** The SELinux labs test with `curl localhost` on node2 instead of opening ports.
- **Boot interruption and bootloader changes stay in W03.** LNX-48 only boots into a target from GRUB for one boot.
- *Diagnose and correct file permission problems*, carried over from W01, is in LNX-46.

## Risks

- All W02 objectives in [the self-assessment](../study/ex200-w02-objectives.md) were checked against the official page on 2026-10-04. RHEL 10 adds *systemd timer units* to task scheduling; it is in LNX-48.
- GRUB editing (LNX-48) needs the VirtualBox console, which cannot paste.

## Outcome

The sprint was **not completed, on purpose**: I let it end with two items open instead of rushing them, because an unfinished sprint is a normal case and it has to be handled, not hidden.

| Done | Carried over |
|---|---|
| LNX-43 to LNX-50 (17 points) | LNX-51 Drill: diagnose and fix SELinux denials (2); LNX-52 W02 runbooks in the repo (2) |

- **Carry-over decision (2026-10-13):** both items move to the next sprint unchanged. Nothing is cancelled or re-estimated.
- LNX-52 is partly done in practice: the runbooks for LNX-48, LNX-49 and LNX-50 are already in [`docs/runbooks/`](../runbooks/README.md). What remains is checking the whole W02 set and the index.
- LNX-51 depends on the state left by LNX-50 on node2 (snapshot `pre-selinux`).
- Still open from Sprint 2: re-rate the storage objectives.

## Retrospective

Written as lessons, not as a score.

### What went well

- Each lab ended with a runbook committed to the repo, with real outputs, rollback and the mistakes made.
- A snapshot before every lab (`pre-systemd`, `pre-processes`, `pre-selinux`) made experiments cheap to undo.
- SELinux issues were fixed with labels and booleans each time; permissive mode was only used to demonstrate the mode.

### What to improve

- Plan the last lab days with spare time: the sprint closed with the two smallest-risk items undone because the unplanned work below used the time.
- Check package size and wait for `dnf` to finish before the next command (`tuned` failed once because of that).
- Run long or CPU-bound tests (`dd if=/dev/zero of=/dev/null`) with a limit, such as `timeout 10`, and take a snapshot before them.
- Write down numbers when they appear (the download size of `httpd` was not recorded).

### Unplanned work

- **2026-10-09, VM stall of about 38 minutes** during LNX-49: node1 stopped answering; cause unknown. See [lessons learned](../lessons-learned.md).
- **2026-10-13, node1 booted without IPv4**: fixed by restarting the `labnet` NAT network and bringing the connection up; root cause unknown. node1 keeps a temporary fixed `10.10.10.3/24` until it returns to DHCP (see [lab setup](../lab-setup.md)).
