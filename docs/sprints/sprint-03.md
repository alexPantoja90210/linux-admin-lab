# Sprint 3: RHCSA users, security and systemd

- **Dates:** 2026-10-09 to 2026-10-16 (planned)
- **Goal:** Users, permissions, SSH keys, systemd and SELinux objectives practised and documented.
- **Epic:** LNX-3 (W02)
- **Planned:** 21 story points, 10 work items

## Work items

Ordered as they should be done. Each lab builds on the state left by the one before it.

| Key | Work item | Type | Points | VM | Status |
|---|---|---|---|---|---|
| LNX-43 | Review EX200 W02 objectives and self-assess | Study | 1 | | Backlog |
| LNX-44 | Jira: custom fields and separate create / edit / transition screens | Task | 3 | | Backlog |
| LNX-45 | Users and groups: accounts, password aging and sudo rules | Lab | 2 | node1 | Backlog |
| LNX-46 | Permissions: umask, set-GID shared directory, diagnose permission problems | Lab | 2 | node1 | Backlog |
| LNX-47 | SSH key-based authentication and secure file transfer between nodes | Lab | 1 | node1 → node2 | Backlog |
| LNX-48 | systemd: services, boot targets, at and cron, time service client | Lab | 3 | node1 | Backlog |
| LNX-49 | Processes, tuning profiles, logs and persistent journal | Lab | 2 | node1 | Backlog |
| LNX-50 | SELinux: modes, contexts, restorecon, port labels and booleans | Lab | 3 | node2 | Backlog |
| LNX-51 | Drill: diagnose and fix SELinux denials | Lab | 2 | node2 | Backlog |
| LNX-52 | W02 runbooks in the repo | Task | 2 | | Backlog |

## Before the sprint starts

- Close Sprint 2 and re-rate the storage objectives.
- Fix LNX-36 (shows *Cancelled* although done; see [Sprint 2](sprint-02.md#jira-notes)).
- Create **LNX Sprint 3** on the board, move LNX-43 to LNX-52 into it, and refine them to Ready.
- Snapshots: `pre-w02` on node1 and node2 before LNX-45; `pre-selinux` on node2 before LNX-50.

## Scope decisions

- **Firewall stays in W03.** The SELinux labs test with `curl localhost` on node2 instead of opening ports.
- **Boot interruption and bootloader changes stay in W03.** LNX-48 only boots into a target from GRUB for one boot.
- *Diagnose and correct file permission problems*, carried over from W01, is in LNX-46.

## Risks

- The objective list in [the W02 self-assessment](../study/ex200-w02-objectives.md) was drafted without the official page; LNX-43 checks it first, and may add or move labs.
- GRUB editing (LNX-48) needs the VirtualBox console, which cannot paste.

## Retrospective

To fill at the end of the sprint: what went well, what to improve, unplanned work.
