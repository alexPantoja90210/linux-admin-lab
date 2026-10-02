# EX200 storage objectives: self-assessment

Objectives for the RHCSA exam (EX200, RHEL 10), sections *Configure local storage* and *Create and configure file systems*, copied from the official Red Hat exam page on 2026-10-02.

Each objective is rated from past work (RHEL/CentOS administration, EMC NAS) before starting the Sprint 2 labs:

- **Confident:** done in real work, can do it without looking anything up.
- **Rusty:** done before, needs to review commands and options.
- **New:** never done.

## Configure local storage

| Objective | Rating | Practised in |
|---|---|---|
| List, create, and delete partitions on GPT disks | Rusty | LNX-37 |
| Create and remove physical volumes | Rusty | LNX-38 |
| Assign physical volumes to volume groups | Rusty | LNX-38 |
| Create and delete logical volumes | Rusty | LNX-38 |
| Configure systems to mount file systems at boot by universally unique ID (UUID) or label | Rusty | LNX-37 (UUID and label), LNX-41 |
| Add new partitions and logical volumes, and swap to a system non-destructively | Rusty | LNX-37, LNX-38, LNX-39 |

## Create and configure file systems

| Objective | Rating | Practised in |
|---|---|---|
| Create, mount, unmount, and use VFAT, ext4, and XFS file systems | Rusty | LNX-37 |
| Mount and unmount network file systems using NFS | Rusty | LNX-40 |
| Configure autofs | Rusty | LNX-40 |
| Extend existing logical volumes | Rusty | LNX-38 |
| Diagnose and correct file permission problems | Rusty | W02 (LNX-3), permissions and SELinux |

## Summary

- 11 objectives, all rated **Rusty**: none is new, and none can be done from memory yet.
- 10 of 11 are covered by the Sprint 2 labs (LNX-37 to LNX-41).
- **Mount by label** was not in LNX-37, which used UUID only; it is added to that lab as an extra step.
- **File permission problems** is listed under file systems but belongs with users, permissions and SELinux, so it is practised in W02.

## Review after the sprint

Re-rate each objective at the end of Sprint 2. The target is **Confident** on everything practised in LNX-37 to LNX-41, measured by doing each task once more without notes in the LNX-41 drill.
