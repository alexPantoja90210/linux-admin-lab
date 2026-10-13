# Runbook: processes, tuning profiles, logs and the persistent journal

Find and stop CPU-heavy processes, change their scheduling priority, work with tuned profiles, read the logs (`rsyslog` files and `journalctl`) and make the journal survive reboots.

- **EX200 objectives:** identify CPU/memory intensive processes and kill processes; adjust process scheduling; manage tuning profiles; locate and interpret system log files and journals; preserve system journals.
- **Practised in:** LNX-49, on `node1` (RHEL 10.2), with `node2` running because `node1` mounts its NFS export at boot.
- **Reset:** restore the `pre-processes` snapshot on `node1`.

## Prerequisites

- `node2` started first, then `node1`. Check from PowerShell on the laptop: `ssh node1 hostname`.
- Snapshot `pre-processes` on `node1` (PowerShell on the laptop):

```powershell
& "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" snapshot "node1" take "pre-processes"
```

- Packages. `procps-ng` and `psmisc` were already installed; `tuned` was **not** (`stress-ng` is optional and was skipped, `dd` is enough as a load):

```bash
rpm -q tuned procps-ng psmisc
sudo dnf install tuned            # 68 packages, 42 MB download, 156 MB installed
sudo systemctl enable --now tuned
```

Wait for `Complete!` from `dnf` **before** running `enable --now`; otherwise it fails with `Unit tuned.service does not exist` (see *Mistakes made*).

- Keep every load bounded with `timeout`, so it stops by itself even if the session dies.

## 1. Find the heavy processes

```bash
dd if=/dev/zero of=/dev/null &
dd if=/dev/zero of=/dev/null &
ps aux --sort=-%cpu | head -5
```

```
apantoja    1843 99.8  0.0   5444  1984 pts/0    R    13:27   1:28 dd if=/dev/zero of=/dev/null
apantoja    1842 99.8  0.1   5444  2000 pts/0    R    13:27   1:28 dd if=/dev/zero of=/dev/null
```

- Each `dd` takes about one whole CPU; both reached ~100% at once, so `node1` has at least 2 vCPUs (`nproc` says 2).
- `dd` to `/dev/null` uses almost no memory (`%MEM` 0.0 to 0.1), so in `top` they leave the top of the list when you sort by memory.
- In `top`: `P` sorts by CPU, `M` by memory, `q` quits.

## 2. Stop processes

```bash
kill 1842                          # TERM, the default
jobs                               # Terminated
```

A process can ignore TERM; KILL cannot be ignored:

```bash
bash -c 'trap "" TERM; while true; do sleep 1; done' &
kill $!                            # nothing happens
ps -p $!                           # still there
kill -9 $!                         # Killed
```

- `kill -9` gives the process no chance to clean up: use it last.
- By name or user:

```bash
pkill -u apantoja -x dd
pgrep -x dd
killall dd
```

- `-x` means **exact name**. Without it `pkill dd` and `pgrep dd` match any process whose name *contains* `dd`:

```
pgrep -a dd
2 [kthreadd]
82 [kworker/R-ipv6_addrconf]
```

So `pgrep dd` is never empty on this system; use `pgrep -x dd`.

- Never run `pkill -u apantoja` alone: it kills **all** your processes, including your SSH session.
- `killall dd` right after launching `timeout ... dd &` can miss a `dd` that has not started yet (the process is still `timeout`). Run it again.

## 3. nice and renice

```bash
nproc                                                   # 2
for i in $(seq "$(nproc)"); do timeout 120 dd if=/dev/zero of=/dev/null & done
timeout 120 nice -n 10 dd if=/dev/zero of=/dev/null &
ps -o pid,ni,%cpu,cmd -C dd --sort=-%cpu
```

```
    PID  NI %CPU CMD
   1960   0  100 dd if=/dev/zero of=/dev/null
   1959  10 99.7 dd if=/dev/zero of=/dev/null
   1958   0  0.0 dd if=/dev/zero of=/dev/null
```

More processes than cores (3 on 2) makes priority matter. Change it:

```bash
P=$(ps -C dd -o pid=,ni= | awk '$2==10{print $1}')
renice -n 15 -p $P                  # 10 -> 15, allowed
renice -n 0 -p $P                   # Permission denied
sudo renice -n 0 -p $P              # 15 -> 0
```

- A normal user can only **raise** the nice value (lower the priority); lowering it again needs root.
- The `%CPU` of `ps` is the **average since the process started**, not the current use (it showed `0.0` for a new process and `72` / `28` later). It is not proof of the effect of `nice`; the `NI` column is. For the live value use `top`.

End of the load:

```bash
pkill -u apantoja -x dd
pgrep -x dd                         # empty
```

## 4. tuned profiles

```bash
tuned-adm active                    # Current active profile: virtual-guest
tuned-adm recommend                 # virtual-guest
tuned-adm list | head -12
sudo tuned-adm profile balanced
tuned-adm active                    # balanced
sudo tuned-adm profile virtual-guest
tuned-adm active                    # virtual-guest
sudo tuned-adm verify
```

`verify` **failed**: `current system settings differ from the preset profile`. Restarting the daemon did not change it. The log names the cause:

```bash
sudo grep -i -E "warn|error|differ|fail" /var/log/tuned/tuned.log | tail -8
```

```
WARNING  tuned.plugins.plugin_cpu: Unable to set boost on cpu 'cpu0'. Neither per-policy boost nor intel_pstate no_turbo is available.
ERROR    tuned.plugins.base: verify: failed: device cpu0: 'boost' = 'None', expected '1'
ERROR    tuned.plugins.base: verify: failed: device cpu1: 'boost' = 'None', expected '1'
```

Only the CPU `boost` setting differs, and a VM has no such control. The profile is active and applied; `verify` cannot pass here. Also `instance video: no matching devices available` is only a warning (no video device).

The profile is stored by the daemon, so it persists across reboots with `tuned` enabled.

## 5. Logs

`rsyslog` is installed, so the classic files exist:

```bash
ls -l /var/log/messages /var/log/secure
rpm -q rsyslog
```

```
-rw-------. 1 root root 1602989 Oct 13 16:53 /var/log/messages
-rw-------. 1 root root   12871 Oct 13 16:53 /var/log/secure
rsyslog-8.2510.0-5.el10_2.2.x86_64
```

journalctl filters:

```bash
sudo journalctl -u sshd -b --no-pager | tail -5        # one unit, this boot
sudo journalctl -p err -b --no-pager | tail -5         # priority err and worse
sudo journalctl --since "10 minutes ago" --no-pager | wc -l
(sleep 2; logger -t lnx49 "follow test") & sudo timeout 6 journalctl -f -t lnx49
```

- `-u` filters by unit, `-p err` by priority, `-b` by boot, `--since` by time, `-f` follows live, `-t` by identifier. `timeout 6` ends the `-f`.
- The sshd lines show `Accepted password for apantoja from 10.10.10.1`: `10.10.10.1` is the NAT gateway, which is how `node1` sees the laptop.
- `-p err -b` showed three `vmwgfx ... unsupported hypervisor` lines (VM graphics driver, not related to this lab), and, from the boot with the network problem, `NetworkManager-wait-online.service: Failed to start` and `Failed to mount mnt-shared.mount` (see [lessons learned](../lessons-learned.md#node1-booted-without-ipv4)).

## 6. Persistent journal

Before: `ls -ld /var/log/journal` said `No such file or directory`, so the journal was only in memory and was lost at every reboot.

```bash
sudo mkdir -p /etc/systemd/journald.conf.d
sudo tee /etc/systemd/journald.conf.d/persistent.conf <<'EOF'
[Journal]
Storage=persistent
EOF
sudo systemctl restart systemd-journald
sudo journalctl --flush
ls -ld /var/log/journal
sudo journalctl --disk-usage
sudo journalctl --list-boots
```

- Check the effective value: `systemd-analyze cat-config systemd/journald.conf | grep -i storage` (last one wins, here `Storage=persistent`).
- After the restart and the flush, `/var/log/journal` existed (`drwxr-xr-x. root root`) and the journal took 16M.
- As a normal user `journalctl` said `No journal files were opened due to insufficient permissions` right after creating it. Use `sudo`; `sudo systemd-tmpfiles --create --prefix /var/log/journal` applies the read permissions, and the message did not appear afterwards.
- Before the reboot `--list-boots` showed one boot. The boots of earlier sessions are gone because the journal was volatile then.

### After a reboot

```bash
sudo systemctl reboot
```

```
IDX BOOT ID                          FIRST ENTRY                 LAST ENTRY
 -4 07573dc27b2a4a01b9681c7289f5fe02 Fri 2026-10-09 13:28:22 CST Mon 2026-10-12 05:24:45 CST
 -3 b6df724cd0574ae1905a36dd67cc4576 Sun 2026-10-11 17:00:13 CST Sun 2026-10-11 17:03:29 CST
 -2 5864f01dc08a4202abad03daf5d09624 Sun 2026-10-11 17:07:41 CST Sun 2026-10-11 17:08:51 CST
 -1 d8d6844e7deb49d6a87c0b8a1ab3f0f8 Sun 2026-10-11 17:06:33 CST Tue 2026-10-13 16:54:52 CST
  0 59e89e23e1aa46c38791f137af64a8eb Tue 2026-10-13 16:54:49 CST Tue 2026-10-13 16:55:45 CST
```

Five boots are listed and they survive reboots. Several of those timestamps are not real times: those boots started with the VM clock behind, and `chronyd` stepped it later (see lessons learned), so the dates overlap and look out of order. Use the boot IDs and indexes, not the dates, to tell boots apart.

Read the previous boot with `journalctl -b -1`.

## Verification (acceptance criteria)

| Criterion | Evidence |
|---|---|
| `journalctl --list-boots` shows more than one boot after the reboot | Five boots, `-4` to `0` |
| `tuned-adm active` shows the chosen profile after a reboot | `Current active profile: virtual-guest` after the reboot |
| The load processes are all gone at the end | `pgrep -x dd` empty (use `-x`: plain `pgrep dd` matches `kthreadd`) |

`tuned-adm verify` does **not** pass on this VM because of the CPU `boost` setting; it is not one of the criteria.

## Rollback

- Whole lab: restore the `pre-processes` snapshot on `node1`.
- By hand: `sudo rm /etc/systemd/journald.conf.d/persistent.conf` and `sudo systemctl restart systemd-journald` (the journal goes back to memory; `sudo rm -r /var/log/journal` also removes the saved logs); `sudo tuned-adm profile virtual-guest` for the profile; `sudo dnf remove tuned` if tuned should go.

## Mistakes made

- **`enable --now tuned` before the install finished:** `Unit tuned.service does not exist`, `not-found`. `dnf` was still waiting for the `y`. Wait for `Complete!`.
- **My download estimate for `tuned` was far too low:** I said "a few MB"; it was 68 packages, 42 MB, 156 MB on disk. Run `dnf` without `-y` and read `Total download size` first.
- **`pgrep dd` is never empty:** it matches kernel threads. Use `pgrep -x dd`.
- **`killall dd` right after launching the loads:** one `dd` had not started yet and survived; the `timeout 120` would have ended it, and a second `killall` did.
- **The VM stopped responding for about 38 minutes** while two `dd` loads were running. Cause unknown; see [lessons learned](../lessons-learned.md#vm-stopped-for-about-38-minutes-cause-unknown). Loads now use `timeout` and the journal is persistent.
- **Network lost at boot:** `node1` had no IPv4 and SSH failed; see [lessons learned](../lessons-learned.md#node1-booted-without-ipv4).

## Quick reference

```bash
ps aux --sort=-%cpu | head -5            # CPU hogs
ps aux --sort=-%mem | head -5            # memory hogs
top                                      # P: CPU, M: memory, q: quit
kill PID; kill -9 PID
pkill -u USER -x NAME; killall NAME; pgrep -x NAME
nice -n 10 CMD; renice -n 15 -p PID      # root needed to lower the value
tuned-adm active|recommend|list
sudo tuned-adm profile NAME; sudo tuned-adm verify
journalctl -u UNIT -b; journalctl -p err -b
journalctl --since "10 minutes ago"; journalctl -f -t TAG
sudo mkdir -p /etc/systemd/journald.conf.d      # then Storage=persistent
sudo systemctl restart systemd-journald; sudo journalctl --flush
sudo journalctl --list-boots; journalctl -b -1
```
