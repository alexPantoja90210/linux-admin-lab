# Sprint 1: lab setup

- **Dates:** 2026-10-01 to 2026-10-08
- **Goal:** Home lab running and LNX configured.
- **Committed:** 21 story points, 10 work items

## Work items

| Key | Work item | Type | Points | Status |
|---|---|---|---|---|
| LNX-12 | Install VirtualBox on the Windows host | Lab | 1 | Done |
| LNX-13 | Red Hat Developer account and Boot ISOs | Task | 1 | Done |
| LNX-14 | NAT Network `labnet` | Lab | 1 | Done |
| LNX-15 | Build `rhel10-template` | Lab | 5 | Done |
| LNX-16 | Build `rhel9-template` | Lab | 2 | Done |
| LNX-17 | Linked clones `node1` and `node2` | Lab | 3 | Done |
| LNX-18 | Decide on Hyper-V / VBS | Task | 2 | Done |
| LNX-19 | GitHub repo and lab documentation | Task | 3 | In progress |
| LNX-20 | Jira: issue type scheme | Task | 2 | Done |
| LNX-21 | Jira: rename project, create and start Sprint 1 | Task | 1 | Done |

## What went well

- The full lab (two templates, two clones, network) was built in the first day of the sprint.
- Every problem was logged with its root cause instead of worked around. See [lessons learned](../lessons-learned.md).
- The Hyper-V decision was made on measurements, not assumptions. See [ADR 0001](../decisions/0001-keep-hyper-v.md).

## What to improve

- An early misdiagnosis (AVX2) almost led to an unnecessary platform change. Check logs and wait for slow boots before changing the plan.
- Running a large host copy in parallel with a VM install caused a failed install. Schedule heavy host work outside lab time.
- Typos in chained commands (`&&`) silently skipped steps. Run critical commands one at a time and verify each.

## Unplanned work

- Board estimation fix: two story point fields (see [Jira project](../jira-project.md)).
- Host disk cleanup to make room for the VMs.

## Backlog refinement for Sprint 2

- Epic `LNX-23` (*Lab environment on VirtualBox*) and its items `LNX-24` to `LNX-32` describe an alternative lab design. Useful ideas to merge: host-only network with static IPs, SSH from Windows, two practice disks for LVM, `server1` / `server2` naming. Items that duplicate finished work get closed as duplicates.
- `LNX-22` (test item) to be cancelled once the `Cancelled` status exists.
