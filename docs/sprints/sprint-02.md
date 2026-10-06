# Sprint 2: RHCSA storage

- **Dates:** 2026-10-02 to 2026-10-04 (planned to 2026-10-09; closed early with every item resolved)
- **Goal:** Storage objectives practised and documented.
- **Committed:** 24 story points, 10 work items

## Work items

| Key | Work item | Type | Points | Status |
|---|---|---|---|---|
| LNX-33 | Jira: custom workflow and workflow scheme for LNX | Task | 5 | Done |
| LNX-34 | Jira: refine backlog (cancel duplicates of LNX-23, re-home useful items) | Task | 2 | Done |
| LNX-35 | Attach two 2 GB practice disks to node1 and snapshot `pre-storage` | Lab | 1 | Done |
| LNX-36 | Review EX200 storage objectives and self-assess | Study | 1 | Done (shows *Cancelled* in Jira, see below) |
| LNX-37 | Partitions and file systems: GPT, xfs/ext4/vfat, persistent mounts | Lab | 3 | Done |
| LNX-38 | LVM: PV, VG, LV and online extension | Lab | 3 | Done |
| LNX-39 | Swap on a partition and on an LV, persistent | Lab | 2 | Done |
| LNX-40 | NFS and autofs: node2 as server, node1 as client | Lab | 3 | Done |
| LNX-41 | Drill: break `/etc/fstab` and recover the boot | Lab | 2 | Done |
| LNX-42 | Storage runbooks in the repo | Task | 2 | Done |

## Delivered

- Five storage runbooks, indexed in [`docs/runbooks/`](../runbooks/README.md), each with prerequisites, commands, verification, rollback and mistakes made.
- [EX200 storage self-assessment](../study/ex200-storage-objectives.md): 10 of 11 objectives practised in LNX-37 to LNX-41.
- LNX workflow (Backlog, Ready, In Lab, Documenting, Blocked, Done, Cancelled), board columns and quick filters. See [Jira project](../jira-project.md).
- Five new storage entries in [lessons learned](../lessons-learned.md#storage).

## What went well

- All five labs were finished in two days, each closed with a runbook and a Jira comment pointing to the commit.
- The `fstab` drill was recovered twice from the console without restoring the snapshot.
- `findmnt --verify` caught the stray `$` in a swap line with the system still up.
- Using UUID and label in `fstab` was proven, not assumed: the practice disk changed from `sdb` to `sdc` across a reboot and every mount came back.

## What to improve

- A tool's behaviour was written down from one observation (LVM allocation) and had to be corrected a lab later. Check with `lvs -o +devices` before documenting.
- `findmnt --verify` was treated as a full check. It does not test mount options: `umount` + `mount -a` after changing the line of a mounted file system.
- Some runbooks first lacked rollback steps and the drill setup, which were added in LNX-42. Write them during the lab, not after.

## Jira notes

- **LNX-36** was closed with the sprint in status *Cancelled* (resolution *Won't Do*), although the work is done (commit bba6a47). The sprint report counts it as completed, because Cancelled maps to the Done column, but its resolution is wrong. Lesson: check resolutions with `sprint = "LNX Sprint 2" AND resolution != Done` before completing a sprint.

## Open at sprint end

- Re-rate the EX200 storage objectives after a run of each task without notes (see [Review after the sprint](../study/ex200-storage-objectives.md#review-after-the-sprint)).
- *Diagnose and correct file permission problems* moves to W02 (LNX-3).
