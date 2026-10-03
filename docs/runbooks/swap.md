# Runbook: swap on a partition and on a logical volume

Add swap space without touching the existing system swap, make it persistent by UUID, and control which swap is used first with priorities.

- **EX200 objective:** add new partitions and logical volumes, and swap to a system non-destructively.
- **Practised in:** LNX-39, on `node1`, after the LVM lab (uses free space on `/dev/sdB` and in `vg_lab`).
- **Reset:** restore the `pre-storage` snapshot (see [lab setup](../lab-setup.md#resetting-the-practice-disks)).

## 0. Current state

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
sudo swapon --show
free -h
sudo vgs vg_lab
```

The system swap is the LV `rhel_rhel10-template/swap` (2 GiB). `swapon --show` lists it as `/dev/dm-1`, its device-mapper name, with priority `-2`. It is not changed in this exercise.

## 1. Swap on a partition

```bash
sudo parted /dev/sdB mkpart swap-part linux-swap 1025MiB 1281MiB   # 256 MiB after the LVM partition
sudo mkswap /dev/sdB2
sudo swapon /dev/sdB2
sudo swapon --show
```

## 2. Swap on a logical volume

```bash
sudo lvcreate -n lv_swap -L 256M vg_lab
sudo mkswap /dev/vg_lab/lv_swap
sudo swapon /dev/vg_lab/lv_swap
sudo swapon --show
```

`mkswap` only formats; nothing is in use until `swapon`. If `mkswap` is run twice it warns `wiping old swap signature`, which is harmless.

## 3. Persistent by UUID, with priorities

Read the UUIDs into variables instead of copying them by hand:

```bash
P_UUID=$(sudo blkid -s UUID -o value /dev/sdB2)
L_UUID=$(sudo blkid -s UUID -o value /dev/vg_lab/lv_swap)
echo "$P_UUID / $L_UUID"
sudo cp -p /etc/fstab /etc/fstab.bak
echo "UUID=$P_UUID  none  swap  defaults,pri=10  0 0" | sudo tee -a /etc/fstab
echo "UUID=$L_UUID  none  swap  defaults,pri=5   0 0" | sudo tee -a /etc/fstab
tail -3 /etc/fstab
```

Watch the `$`: `"UUID=$P_UUID"` is correct; `"$UUID=$P_UUID"` expands an unset variable `$UUID` to nothing and writes a line starting with `=` (see [lessons learned](../lessons-learned.md)).

Test the `fstab` lines without rebooting by turning the new swaps off and back on from `fstab`:

```bash
sudo swapoff /dev/sdB2 /dev/vg_lab/lv_swap
sudo systemctl daemon-reload
sudo findmnt --verify      # expect 0 errors
sudo swapon -a
sudo swapon --show
```

`findmnt --verify` warns `target specified more than once` for swap lines, because every swap uses `none` as its target. That warning is expected; errors are not.

## 4. Priorities

| Swap | Priority | Order of use |
|---|---|---|
| Partition | 10 | first |
| LV | 5 | second |
| System | -2 | last |

- The kernel uses the highest priority first. Swaps with the **same** priority are used in parallel (round-robin).
- Without `pri=`, the kernel assigns negative priorities in activation order (`-2`, `-3`, `-4`...), so a swap added later is used last.

## 5. Reboot and confirm

```bash
sudo systemctl reboot
# after reconnecting
sudo swapon --show
free -h
```

Result in the lab:

```
NAME      TYPE      SIZE USED PRIO
/dev/dm-1 partition   2G   0B   -2
/dev/sdb2 partition 256M   0B   10
/dev/dm-4 partition 256M   0B    5
```

## Removing a swap area

```bash
sudo swapoff /dev/vg_lab/lv_swap
# remove its line from /etc/fstab, then:
sudo systemctl daemon-reload
sudo lvremove /dev/vg_lab/lv_swap
```

Never `swapoff` the only swap on a system under memory pressure: the pages in it must fit back in RAM.

## Quick reference

| Task | Command |
|---|---|
| Format as swap | `mkswap /dev/sdX2` |
| Turn on / off | `swapon /dev/sdX2` / `swapoff /dev/sdX2` |
| Turn on everything in `fstab` | `swapon -a` |
| Show swaps and priorities | `swapon --show` |
| Total memory and swap | `free -h` |
| `fstab` line | `UUID=<uuid>  none  swap  defaults,pri=10  0 0` |
