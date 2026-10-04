# Runbook: recover a boot broken by `/etc/fstab`

A bad line in `/etc/fstab` can stop the boot and drop the system into emergency mode. This runbook covers how to read the failure, fix it from the console, and avoid it in the first place.

- **EX200 objectives:** configure systems to mount file systems at boot; diagnose boot problems; work in emergency mode.
- **Practised in:** LNX-41, on `node1`, twice, recovered both times without restoring the `pre-drill` snapshot.

## Before you need it

- **Know the root password.** Emergency mode asks for root's password, not yours. Check it while the system is healthy: `su - root -c whoami`.
- **Recovery happens on the console.** In emergency mode there is no network and no SSH. In VirtualBox, open the VM window (**Show**). The console cannot paste: commands are typed by hand.
- **Take a snapshot** before changing storage or boot configuration.

## What a broken `fstab` looks like

The screen ends with:

```
You are in emergency mode. After logging in, type "journalctl -xb" to view
system logs, "systemctl reboot" to reboot, or "exit"
to continue bootup.
Give root password for maintenance
(or press Control-D to continue):
```

**The last `[FAILED]` line on screen is often not the cause.** In both drills the last error shown was the NFS mount (`Failed to mount mnt-shared.mount`, `Dependency failed for remote-fs.target`). Emergency mode does not start the network, so the NFS mount fails as a side effect. The real cause had already scrolled off the screen. Always read the journal.

## Read the cause

```
journalctl -xb | grep -iE 'timeout|dependency failed'
journalctl -xb -u <unit>.mount --no-pager | tail -20
```

Mount units are named after the mount point: `/logs` is `logs.mount`, `/mnt/broken` is `mnt-broken.mount`. Device units escape `-` as `\x2d`, so `dev-disk-by\x2duuid-0000...` is `/dev/disk/by-uuid/0000...`.

### Case 1: the device does not exist (wrong UUID or label)

Line added for the drill:

```
UUID=00000000-0000-0000-0000-000000000000  /mnt/broken  xfs  defaults  0 0
```

On the console during boot:

```
[ ***] Job dev-disk-by\x2duuid-00000000\x2d0000...device/start running (26s / 1min 30s)
```

In the journal, the chain of failures:

```
dev-disk-by\x2duuid-00000000\x2d0000...device: Job ... start failed with result 'timeout'.
Dependency failed for mnt-broken.mount - /mnt/broken.
Dependency failed for local-fs.target - Local File Systems.
Dependency failed for selinux-autorelabel-mark.service - Mark the need to relabel after reboot.
Dependency failed for remote-fs.target - Remote File Systems.
```

systemd waits 90 seconds for the device, gives up (`timeout`), the mount fails, and because a **local** mount failed, `local-fs.target` fails. A failed `local-fs.target` sends the system to emergency mode.

### Case 2: the device exists, the mount fails (wrong option or type)

Line changed for the drill: `defaults` mistyped as `defualts` on `/logs`.

No 90-second wait: the device is there, and `mount` itself fails.

```
logs.mount: Mount process exited, code=exited, status=32/n/a
logs.mount: Failed with result 'exit-code'.
Failed to mount logs.mount - /logs.
```

The detail, from `mount`:

```
mount: /logs: fsconfig system call failed: ext4: Unknown parameter 'defualts'.
```

`status=32` is `mount`'s exit code for "mount failure".

### Telling them apart

| systemd result | Meaning | Check |
|---|---|---|
| `'timeout'` on a `dev-disk-...device` unit | The device never appeared | UUID, label, device path, whether the disk is attached |
| `'exit-code'` on a `....mount` unit, `status=32` | The device is there, `mount` failed | File system type, mount options, mount point |

## Fix it (console, as root)

```
mount | grep ' / '              # is / rw or ro?
mount -o remount,rw /           # only if it says ro
vi /etc/fstab                   # fix or comment out (#) the bad line
systemctl daemon-reload
mount -a                        # must report no errors for local mounts
reboot
```

- In both drills `/` was already `rw` in emergency mode. `remount,rw` is needed when it is `ro`, for example after booting with `rd.break`.
- In `vi`: `G` goes to the last line, `dd` deletes a line, `:%s/defualts/defaults/` fixes a word everywhere, `:wq` saves.
- `mount -a` in emergency mode still fails for NFS (`Network is unreachable`), because there is no network. That is expected; what matters is that local mounts succeed.
- After the reboot: `systemctl is-system-running` must say `running`, not `degraded`.

## Prevent it

1. Read the line back after editing: `tail /etc/fstab`.
2. Validate before rebooting:

```bash
sudo systemctl daemon-reload
sudo findmnt --verify
sudo umount /mount/point       # if the line changed an existing mount
sudo mount -a
```

3. Know what each check catches:

| Check | Wrong UUID / missing device | Mistyped mount option |
|---|---|---|
| `findmnt --verify` | **Caught** (`[E]` error) | **Not caught** (0 errors) |
| `mount -a` with the file system already mounted | Caught | **Not caught**: `mount -a` skips mounted file systems |
| `umount` then `mount -a` | Caught | **Caught**: `Unknown parameter 'defualts'` |

4. Use `nofail` for mounts the system does not need to boot (`defaults,nofail`): if the device is missing, the boot continues and the failure is only logged. Use `_netdev` for network file systems.

## Quick reference

| Task | Command |
|---|---|
| Why did the boot fail | `journalctl -xb \| grep -iE 'timeout\|dependency failed'` |
| Details for one mount | `journalctl -xb -u logs.mount` |
| Failed units | `systemctl --failed` |
| Is / writable | `mount \| grep ' / '` |
| Make / writable | `mount -o remount,rw /` |
| Test `fstab` | `findmnt --verify`, then `umount` + `mount -a` |
| Leave emergency mode | `reboot` (or `exit` to continue booting) |
