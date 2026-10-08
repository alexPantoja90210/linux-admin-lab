# Runbook: systemd services, targets, at, cron, timers and chrony

Manage services and their boot state, boot into a target (live and from GRUB), schedule tasks three ways (`at`, `cron`, systemd timer) and point `chronyd` at a specific time server.

- **EX200 objectives:** boot, reboot and shut down normally; boot into different targets manually; boot into a specific target automatically; start, stop and check the status of network services; start and stop services and enable them at boot; schedule tasks using at, cron and systemd timer units; configure time service clients.
- **Practised in:** LNX-48, on `node1` (RHEL 10.2), with `node2` running because `node1` mounts its NFS export at boot.
- **Reset:** restore the `pre-systemd` snapshot on `node1`.

## Prerequisites

- `node2` started first, then `node1`. Check from PowerShell on the laptop: `ssh node1 hostname`.
- Snapshot `pre-systemd` on `node1` (PowerShell on the laptop):

```powershell
& "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" snapshot "node1" take "pre-systemd"
```

- Packages. `at` is **not** in the RHEL 10 minimal install (`cronie` and `chrony` are):

```bash
rpm -q at cronie chrony
sudo dnf install -y at          # under 1 MB
```

- Internet access from `node1` (UDP 123) for the time server step.
- The GRUB and rescue steps need the **VirtualBox console** of `node1`; it cannot paste, so type the commands.

## 1. Services: enabled is not active

```bash
systemctl status atd
systemctl is-enabled atd
systemctl is-active atd
```

Right after installing `at` the result was:

```
Loaded: loaded (/usr/lib/systemd/system/atd.service; enabled; preset: enabled)
Active: inactive (dead)
enabled
inactive
```

*Enabled* means "starts at boot"; *active* means "running now". They are independent:

```bash
sudo systemctl start atd
sudo systemctl disable atd          # does NOT stop it
systemctl is-active atd             # active
systemctl is-enabled atd            # disabled
sudo systemctl stop atd
systemctl is-active atd             # inactive
sudo systemctl enable --now atd     # enable and start in one command
```

`enable` prints `Created symlink '/etc/systemd/system/multi-user.target.wants/atd.service' → ...`; `disable` prints `Removed ...`.

### restart, reload and mask

```bash
sudo systemctl restart atd
sudo systemctl reload atd
```

```
Failed to reload atd.service: Job type reload is not applicable for unit atd.service.
```

`atd` has no reload action. Check which units support it:

```bash
systemctl show -p CanReload atd chronyd sshd
```

Result: `atd` `no`, `chronyd` `no`, `sshd` `yes`. Use `restart` for services that cannot reload.

```bash
sudo systemctl mask atd             # symlink /etc/systemd/system/atd.service -> /dev/null
sudo systemctl start atd            # Failed to start atd.service: Unit atd.service is masked.
systemctl is-enabled atd            # masked
sudo systemctl unmask atd
```

A masked unit cannot be started by hand or as a dependency. After `unmask`, `atd` was `enabled` again but still had to be checked with `is-active`.

## 2. Targets

```bash
systemctl get-default
sudo systemctl set-default multi-user.target
systemctl list-units --type=target --no-pager
```

The default was already `multi-user.target`, so `set-default` printed nothing. `graphical.target` is not loaded on this minimal install. To switch to a graphical default on another system: `sudo systemctl set-default graphical.target`.

### Isolate rescue.target (VirtualBox console of node1, as root)

```bash
systemctl isolate rescue.target
systemctl is-active sshd
ip -br a
```

- `sshd` is `inactive`, so SSH sessions drop.
- `enp0s3` stayed `UP` with `10.10.10.3/24`: rescue keeps the kernel address, it only stops the services (including `sshd`).
- Console lines such as `audit: type=1131 ... res=failed` and `prog-id ... op=UNLOAD` appear while systemd stops services. They were noise here; the text was cut off, so the unit was not identified.

Go back without rebooting:

```bash
systemctl isolate multi-user.target
systemctl is-active sshd           # active
```

## 3. Boot into a target from GRUB (one boot only)

1. `sudo systemctl reboot` from SSH.
2. In the VirtualBox console press a key (or Esc) to stop the GRUB countdown.
3. Select the first entry and press `e`.
4. Go to the end of the line that starts with `linux` and append ` systemd.unit=rescue.target`.
5. `Ctrl+X` to boot, enter the root password.

Verify (as root in the rescue shell):

```bash
cat /proc/cmdline
systemctl get-default
```

```
... rd.lvm.lv=rhel_rhel10-template/swap systemd.unit=rescue.target
multi-user.target
Note: found "systemd.unit" on the kernel command line, which overrides the default unit.
```

The kernel argument overrides the default for this boot only; the stored default stays `multi-user.target`. `clocksource: Long readout interval, skipping watchdog check` is VM noise under Hyper-V.

Return with `systemctl reboot`. Afterwards `cat /proc/cmdline` no longer has `systemd.unit=rescue.target`, `get-default` is `multi-user.target` and `atd` is `enabled` and `active`.

## 4. Reboot and power off

```bash
sudo systemctl reboot
sudo systemctl poweroff
```

Power off `node1` before `node2` (`node1` mounts the NFS export of `node2`). Both VMs were powered off this way at the end of the lab.

## 5. at

```bash
echo 'date >> ~/at-run2.txt' | at now + 2 minutes
atq
sleep 130
cat ~/at-run2.txt
atq
```

```
job 7 at Wed Oct  7 23:07:00 2026
7       Wed Oct  7 23:07:00 2026 a apantoja
Wed Oct  7 11:07:00 PM CST 2026
```

After the run `atq` is empty: a job leaves the queue when it executes. `at` rounds to the minute and warns `commands will be executed using /bin/sh`.

Remove a job that has not run yet:

```bash
echo 'echo second >> ~/at-second.txt' | at now + 10 minutes
atq
atrm <job-number>
atq
```

## 6. cron

User entry (crontab of `apantoja`):

```bash
systemctl is-enabled crond; systemctl is-active crond
( crontab -l 2>/dev/null; echo '*/5 * * * * date >> ~/cron-user.txt' ) | crontab -
crontab -l
```

System entry, in `/etc/cron.d/`. It has an **extra field, the user**, that a user crontab does not have:

```bash
echo '*/5 * * * * root date >> /tmp/cron-system.txt' | sudo tee /etc/cron.d/lab-test
```

Both ran at `23:10:01`, the next minute that is a multiple of 5 (`crond` picks up new files in `/etc/cron.d/` by itself). Check the runs:

```bash
cat ~/cron-user.txt /tmp/cron-system.txt
sudo journalctl --since "15 minutes ago" --no-pager | grep CMD
```

```
Oct 07 23:10:01 node1 CROND[1336]: (root) CMD (date >> /tmp/cron-system.txt)
Oct 07 23:10:01 node1 CROND[1340]: (apantoja) CMD (date >> ~/cron-user.txt)
```

`journalctl -u crond` showed only the `(root)` line; without `-u` both appeared. The cause was not verified, so use the unfiltered form with `grep CMD`.

Cleanup:

```bash
crontab -r
sudo rm /etc/cron.d/lab-test
crontab -l                          # no crontab for apantoja
ls /etc/cron.d/                     # 0hourly stays
```

RHEL 10 saves a backup of the removed crontab in `~/.cache/crontab/crontab.bak`.

## 7. systemd timer

Test the expression first:

```bash
systemd-analyze calendar '*:0/5'
```

```
Normalized form: *-*-* *:00/5:00
    Next elapse: Wed 2026-10-07 23:15:00 CST
```

The service (a oneshot) and the timer share the base name `lab-date`:

```bash
sudo tee /etc/systemd/system/lab-date.service <<'EOF'
[Unit]
Description=Write the current date to a test file

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'date >> /tmp/timer-test.txt'
EOF

sudo tee /etc/systemd/system/lab-date.timer <<'EOF'
[Unit]
Description=Run lab-date every 5 minutes

[Timer]
OnCalendar=*:0/5
Persistent=true

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now lab-date.timer
systemctl list-timers lab-date.timer --no-pager
```

- Enable the **timer**: it is the unit that fires at a time and must start at boot. The `.service` is only the task it launches and has no `[Install]` section.
- `Persistent=true` stores when the timer last ran; if a scheduled time was missed while the machine was off, the task runs after the next boot.
- Check a run:

```bash
cat /tmp/timer-test.txt
sudo journalctl -u lab-date.service --since "10 minutes ago" --no-pager | tail -10
systemctl list-timers lab-date.timer --no-pager
```

The first run was at `23:15:19`, not `23:15:00`: `AccuracySec` defaults to 1 minute, so systemd may fire anywhere in that minute.

### After a reboot

The timer was still listed (`NEXT 23:25:00`), and `atd` was still `enabled` and `active`. The journal showed a run at `23:20:47`, 47 seconds after boot and off the 5-minute grid. This is **consistent with `Persistent=true`** catching up the `23:20:00` run missed while the VM was off; the journal does not label it as a catch-up, so it is not proven.

Cleanup:

```bash
sudo systemctl disable --now lab-date.timer
sudo rm /etc/systemd/system/lab-date.timer /etc/systemd/system/lab-date.service
sudo systemctl daemon-reload
systemctl list-timers lab-date.timer --no-pager     # 0 timers listed
sudo rm -f /tmp/cron-system.txt /tmp/timer-test.txt # written by root, see Mistakes made
```

## 8. Time service client (chrony)

Before:

```bash
grep -E '^(pool|server)' /etc/chrony.conf
chronyc sources -v
timedatectl
```

The default was `pool 2.rhel.pool.ntp.org iburst`, with four sources and `^*` on `xalli.cie.unam.mx`.

Change to one specific server:

```bash
sudo cp /etc/chrony.conf /etc/chrony.conf.bak
sudo sed -i 's/^pool/#pool/' /etc/chrony.conf
echo 'server time.cloudflare.com iburst' | sudo tee -a /etc/chrony.conf
sudo systemctl restart chronyd
sleep 90
chronyc sources -v
timedatectl
```

```
^* time.cloudflare.com           3   6    37    18   -213us[+4505us] +/-   31ms
System clock synchronized: yes
NTP service: active
```

- `^*` = the source currently selected; `^?` right after the restart only means "not yet usable", wait a little.
- `Reach 37` (octal) is normal 90 seconds after a restart; it climbs to `377`.
- After the reboot `time.cloudflare.com` was still `^*`.
- Roll back: `sudo cp /etc/chrony.conf.bak /etc/chrony.conf && sudo systemctl restart chronyd`.

## Verification (acceptance criteria)

| Criterion | Evidence |
|---|---|
| Enable/disable state survives a reboot | `atd` `enabled` and `active` after two reboots |
| `at` job, both cron entries and the timer seen running | `at-run2.txt` at `23:07:00`; two `CMD` lines at `23:10:01`; `lab-date.service` `Finished` at `23:15:19` |
| Timer still listed after a reboot | `list-timers` showed `lab-date.timer` with `NEXT 23:25:00` |
| `chronyc sources` shows the server selected | `^* time.cloudflare.com` |
| Rescue target once from GRUB, then multi-user | `cmdline` ended in `systemd.unit=rescue.target`; next boot normal, default `multi-user.target` |

## Rollback

- Whole lab: restore the `pre-systemd` snapshot on `node1`.
- By hand: remove the timer and unit files (section 7), `crontab -r` and `rm /etc/cron.d/lab-test` (section 6), restore `/etc/chrony.conf.bak` (section 8), `systemctl unmask atd` if it is masked.

## Mistakes made

- **Typos in the console:** `sistemctl` and, over SSH, `hostame` returned `command not found`. The shell answering proved the connection worked; read the error before assuming a failure.
- **`atrm` on the wrong job:** the second job was meant to be removed but the first (2 minutes) was, so it never ran, and a stale `at-test.txt` looked like proof. Fix: new job with a new file name (`at-run2.txt`) and check the time inside the file.
- **Root-owned files in `/tmp`:** `rm` of `/tmp/cron-system.txt` and `/tmp/timer-test.txt` failed with `Operation not permitted`. Root wrote them (cron.d entry and the service run as root) and `/tmp` has the sticky bit, so use `sudo rm`.
- **Wrong assumption about `/tmp`:** it is not wiped at reboot on RHEL (`systemd-tmpfiles` removes by age), so `timer-test.txt` kept its earlier lines.
- **Commands pasted twice:** the first `is-enabled` after `start` already said `disabled` because the block had run before; keep one block per paste and compare with the previous state.

## Quick reference

```bash
systemctl status|start|stop|restart|reload|enable|disable|mask|unmask <unit>
systemctl enable --now <unit>
systemctl is-enabled <unit>; systemctl is-active <unit>
systemctl show -p CanReload <unit>
systemctl get-default; systemctl set-default <target>
systemctl isolate rescue.target
# GRUB, one boot: press e, append  systemd.unit=rescue.target  to the linux line, Ctrl+X
echo 'cmd' | at now + 2 minutes; atq; atrm <n>
crontab -l|-e|-r;   /etc/cron.d/<file> has a user field
systemd-analyze calendar '*:0/5'
systemctl list-timers --no-pager
chronyc sources -v; timedatectl
sudo systemctl reboot; sudo systemctl poweroff
```
