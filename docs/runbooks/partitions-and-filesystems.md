# Runbook: GPT partitions and file systems

Create GPT partitions, format them as XFS, ext4 and VFAT, mount them persistently by UUID or label, and remove one cleanly.

- **EX200 objectives:** list, create and delete partitions on GPT disks; create, mount, unmount and use VFAT, ext4 and XFS file systems; mount file systems at boot by UUID or label.
- **Practised in:** LNX-37, on `node1`.
- **Reset:** restore the `pre-storage` snapshot (see [lab setup](../lab-setup.md#resetting-the-practice-disks)).

## 0. Identify the disk

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS
```

Pick the disk by **size and content**, never by name: `sdX` names can change between boots. In this lab the practice disks are 2 GB and empty; the system disk is 20 GB with `/boot` and LVM. Below, `/dev/sdX` is the practice disk found here.

Packages: `parted`, `xfsprogs` and `e2fsprogs` are in the minimal install; `mkfs.vfat` and `fatlabel` need `dosfstools`.

## 1. Partition (GPT)

```bash
sudo parted /dev/sdX mklabel gpt
sudo parted /dev/sdX mkpart xfs-part  xfs   1MiB    501MiB
sudo parted /dev/sdX mkpart ext4-part ext4  501MiB  1001MiB
sudo parted /dev/sdX mkpart vfat-part fat32 1001MiB 1501MiB
sudo parted /dev/sdX print
```

- In GPT, the first word after `mkpart` is the partition **name**. The file system type is only a hint; the real format comes from `mkfs`.
- Starting at `1MiB` keeps partitions aligned.

## 2. Format

```bash
sudo mkfs.xfs  /dev/sdX1
sudo mkfs.ext4 /dev/sdX2
sudo mkfs.vfat /dev/sdX3
lsblk -f /dev/sdX
```

`mkfs.vfat` picks FAT16 for a 500 MB partition; it still mounts as `vfat`. Its "UUID" is the short volume serial (`FB82-9A25`), used the same way in `fstab`.

## 3. Label (optional, for mounting by label)

| File system | Set label | Notes |
|---|---|---|
| ext4 | `sudo e2label /dev/sdX2 EXT4LAB` | Works mounted or not |
| XFS | `sudo xfs_admin -L XFSLAB /dev/sdX1` | File system must be unmounted; 12 characters max |
| VFAT | `sudo fatlabel /dev/sdX3 VFATLAB` | Upper case recommended |

## 4. Mount persistently

```bash
sudo mkdir -p /mnt/xfs /mnt/ext4 /mnt/vfat
sudo cp -p /etc/fstab /etc/fstab.bak
sudo blkid /dev/sdX1 /dev/sdX2 /dev/sdX3
```

Add to `/etc/fstab` (UUIDs from `blkid`):

```
UUID=<xfs-uuid>   /mnt/xfs   xfs   defaults  0 0
LABEL=EXT4LAB     /mnt/ext4  ext4  defaults  0 0
UUID=<vfat-uuid>  /mnt/vfat  vfat  defaults  0 0
```

Never use `/dev/sdX1` in `fstab`.

## 5. Validate before rebooting

```bash
sudo systemctl daemon-reload
sudo findmnt --verify        # expect: Success, no errors or warnings detected
sudo mount -a
df -hT /mnt/xfs /mnt/ext4 /mnt/vfat
```

`daemon-reload` is needed because systemd turns each `fstab` line into a mount unit. Never reboot after editing `fstab` without `findmnt --verify` and `mount -a`: a broken line can stop the boot (see the LNX-41 drill).

Expected sizes for 500 MB partitions: XFS shows ~436M (space reserved for its log), ext4 ~459M (inode tables, plus 5% reserved for root), VFAT ~500M.

## 6. Reboot and confirm

```bash
sudo systemctl reboot
# after reconnecting
findmnt /mnt/xfs; findmnt /mnt/ext4; findmnt /mnt/vfat
```

Observed in this lab: the practice disk was `sdb` before the reboot and `sdc` after it. All three mounts came back because `fstab` used UUID and label.

## 7. Remove a partition cleanly

Order matters: unmount, remove from `fstab`, then delete. Deleting first leaves a boot-time mount pointing at nothing.

```bash
sudo umount /mnt/vfat
sudo sed -i '\|/mnt/vfat|d' /etc/fstab      # or edit with vi
sudo systemctl daemon-reload
sudo findmnt --verify
sudo parted /dev/sdX print                  # confirm the partition number
sudo parted /dev/sdX rm 3
sudo rmdir /mnt/vfat
lsblk /dev/sdX
```

## Quick reference

| Task | Command |
|---|---|
| List disks and file systems | `lsblk -f` |
| Show UUID, label, type | `blkid /dev/sdX1` |
| Partition table | `parted /dev/sdX print` |
| Check `fstab` | `findmnt --verify` |
| What is mounted where | `findmnt /mnt/xfs`, `df -hT` |
