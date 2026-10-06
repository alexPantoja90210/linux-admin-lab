# Runbooks

One runbook per lab exercise. Each one is written so the exercise can be repeated from the runbook alone, and has the same parts:

| Part | Where |
|---|---|
| Purpose and EX200 objectives | Opening lines |
| Prerequisites | `## Prerequisites` |
| Commands | Numbered steps |
| Verification | `findmnt --verify`, `mount -a` / `swapon -a`, reboot and confirm |
| Rollback | `## Rollback`: snapshot restore, or undo by hand |
| Mistakes made | `## Mistakes made` |

## Storage (Sprint 2, epic LNX-2)

Run them in this order; each one builds on the state left by the previous one.

| Order | Runbook | Lab | VMs | Snapshot before |
|---|---|---|---|---|
| 1 | [GPT partitions and file systems](partitions-and-filesystems.md) | LNX-37 | node1 | `pre-storage` |
| 2 | [LVM](lvm.md) | LNX-38 | node1 | `pre-storage` |
| 3 | [Swap on a partition and an LV](swap.md) | LNX-39 | node1 | (continues from 2) |
| 4 | [NFS and autofs](nfs-autofs.md) | LNX-40 | node2 server, node1 client | node1 `post-swap`, node2 `pre-nfs` |
| 5 | [Recover a boot broken by `fstab`](fstab-boot-recovery.md) | LNX-41 | node1 | `pre-drill` |

## Users, security and systemd (Sprint 3, epic LNX-3)

| Order | Runbook | Lab | VMs | Snapshot before |
|---|---|---|---|---|
| 1 | [Users, groups, password aging and sudo](users-and-groups.md) | LNX-45 | node1 | `pre-w02` |
| 2 | [Default permissions, shared directories, permission problems](permissions.md) | LNX-46 | node1 | (continues from 1) |

Snapshots are listed in [lab setup](../lab-setup.md#snapshots).
