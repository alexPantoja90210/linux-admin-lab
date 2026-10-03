# Runbook: LVM physical volumes, volume groups and logical volumes

Create PVs on a whole disk and on a partition, group them in a VG with a custom extent size, create LVs by size and by extents, mount them persistently, and extend them while mounted.

- **EX200 objectives:** create and remove physical volumes; assign physical volumes to volume groups; create and delete logical volumes; extend existing logical volumes; add new logical volumes non-destructively.
- **Practised in:** LNX-38, on `node1`.
- **Reset:** restore the `pre-storage` snapshot (see [lab setup](../lab-setup.md#resetting-the-practice-disks)).

## Layout built in the lab

```
disk A (2 GiB, whole disk)  ─► PV ─┐
                                   ├─► VG vg_lab (2.98 GiB, PE 8 MiB, 382 extents)
disk B, partition 1 (1 GiB) ─► PV ─┘      ├─► lv_data  800 MiB → 1200 MiB   xfs   /data
disk B, rest (~1 GiB)  free                └─► lv_logs   50 PE →   75 PE   ext4  /logs
```

## 0. Identify the disks

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
sudo pvs
```

Pick the practice disks by size (2 GB, empty); `sdX` names change between boots. `pvs` shows the PVs that already exist: the system VG (`rhel_rhel10-template` on the system disk) is never touched. Below, `/dev/sdA` is the whole-disk PV and `/dev/sdB` holds the partition PV.

## 1. Physical volumes

A partition used for LVM gets the `lvm` flag. LVM works without it, but the flag tells tools and people what the partition holds.

```bash
sudo parted /dev/sdB mklabel gpt
sudo parted /dev/sdB mkpart lvm-part 1MiB 1025MiB
sudo parted /dev/sdB set 1 lvm on

sudo pvcreate /dev/sdA /dev/sdB1
sudo pvs
```

A whole disk can be a PV directly, with no partition table.

## 2. Volume group

```bash
sudo vgcreate -s 8M vg_lab /dev/sdA /dev/sdB1
sudo vgs vg_lab
sudo vgdisplay vg_lab | grep -E "PE Size|Total PE|Free  PE"
```

- The **physical extent (PE)** is the allocation unit: every LV is a whole number of extents. Default is 4 MiB; `-s 8M` sets 8 MiB.
- Result: 382 extents of 8 MiB (2 GiB + 1 GiB, minus LVM metadata).
- `vgdisplay` labels have two spaces in `Free  PE`.

## 3. Logical volume by size, XFS, persistent

```bash
sudo lvcreate -n lv_data -L 800M vg_lab
sudo mkfs.xfs /dev/vg_lab/lv_data
sudo mkdir /data
echo '/dev/vg_lab/lv_data  /data  xfs  defaults  0 0' | sudo tee -a /etc/fstab
sudo systemctl daemon-reload
sudo findmnt --verify
sudo mount -a
df -hT /data
```

- An LV path is safe in `fstab`: LVM builds it from the VG and LV names, so it does not change between boots like `sdX` does. UUID also works.
- `/dev/vg_lab/lv_data` and `/dev/mapper/vg_lab-lv_data` are the same device; `df` shows the second.

## 4. Extend while mounted

```bash
sudo lvextend -r -L +400M /dev/vg_lab/lv_data
df -h /data
```

`-r` grows the LV and then the file system in one step (`xfs_growfs` for XFS, `resize2fs` for ext4). Without it, two steps are needed, and forgetting the second leaves `df` showing the old size:

```bash
sudo lvextend -L +400M /dev/vg_lab/lv_data
sudo xfs_growfs /data        # XFS takes the mount point
# ext4: sudo resize2fs /dev/vg_lab/lv_logs
```

Verified in the lab: 200 MiB of random data with a SHA-256 checksum, written before the extension, still matched after it (`sha256sum -c`: `OK`).

## 5. Logical volume by extents, ext4

```bash
sudo lvcreate -n lv_logs -l 50 vg_lab          # 50 x 8 MiB = 400 MiB
sudo mkfs.ext4 /dev/vg_lab/lv_logs
sudo mkdir /logs
echo '/dev/vg_lab/lv_logs  /logs  ext4  defaults  0 0' | sudo tee -a /etc/fstab
sudo systemctl daemon-reload && sudo findmnt --verify && sudo mount -a

sudo lvextend -r -l +25 /dev/vg_lab/lv_logs    # +200 MiB, now 600 MiB
```

Size forms for `-l`:

| Option | Meaning |
|---|---|
| `-l 50` | 50 extents |
| `-l +25` | 25 more extents |
| `-l +50%FREE` | half of the free space in the VG |
| `-l 100%FREE` | all the free space in the VG |

## 6. Inspect

```bash
sudo pvs            # PFree per PV shows where the space went
sudo vgs vg_lab
sudo lvs vg_lab
sudo lvs -o +devices  # PV and starting extent of each LV
sudo pvdisplay -m     # segment map: which extents of which PV each LV uses
lsblk
df -hT /data /logs
```

Observed: both LVs were allocated entirely on the first PV given to `vgcreate` (`/dev/sdA`, 240 MiB left), and the partition PV stayed unused (`PFree` 1016 MiB).

LVM does not simply fill PVs in order. With the default `normal` allocation policy, a new LV is placed on a single PV that can hold it whole whenever one exists. In LNX-39, a 256 MiB (32-extent) LV did not fit in the 30 extents left on `/dev/sdA`, so LVM put all of it on `/dev/sdB1` instead of splitting it. `lvs -o +devices` shows the PV and starting extent of every LV:

```
lv_data  1.17g   /dev/sdA(0)
lv_logs  600.00m /dev/sdA(150)
lv_swap  256.00m /dev/sdB1(0)
```

## Shrinking: XFS cannot, ext4 can (unmounted)

- **XFS cannot be shrunk.** There is no `xfs_shrinkfs`, and `lvreduce -r` on XFS fails. To make an XFS file system smaller: back it up (`xfsdump` or a file copy), recreate the LV smaller, `mkfs.xfs`, restore.
- **ext4 can be shrunk, unmounted only.** `lvreduce -r` runs `e2fsck` and `resize2fs` before shrinking the LV:

```bash
sudo umount /logs
sudo lvreduce -r -L 400M /dev/vg_lab/lv_logs
sudo mount /logs
```

Shrinking the LV without shrinking the file system first destroys data. Always use `-r`, or shrink the file system first by hand.

## Removing (reverse order)

```bash
sudo umount /logs                      # and remove its fstab line
sudo lvremove /dev/vg_lab/lv_logs
sudo vgreduce vg_lab /dev/sdB1         # take a PV out of the VG (it must be empty)
sudo pvremove /dev/sdB1
# whole VG: remove all LVs, then: sudo vgremove vg_lab
```

## Quick reference

| Task | Command |
|---|---|
| Create PV | `pvcreate /dev/sdX` |
| Create VG with 8 MiB extents | `vgcreate -s 8M vg_name /dev/sdX /dev/sdY1` |
| Add a PV to a VG | `vgextend vg_name /dev/sdZ` |
| Create LV by size / by extents | `lvcreate -n lv -L 800M vg` / `lvcreate -n lv -l 50 vg` |
| Grow LV and file system | `lvextend -r -L +400M /dev/vg/lv` |
| Grow XFS only | `xfs_growfs /mount/point` |
| Grow ext4 only | `resize2fs /dev/vg/lv` |
| Show everything | `pvs; vgs; lvs; lsblk` |
