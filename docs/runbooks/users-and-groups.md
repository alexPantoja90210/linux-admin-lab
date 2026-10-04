# Runbook: local users, groups, password aging and sudo

Create and modify local users and groups, set password aging, give limited privileged access with a `sudoers.d` drop-in, and delete users cleanly.

- **EX200 objectives:** create, delete, and modify local user accounts; change passwords and adjust password aging for local user accounts; create, delete, and modify local groups and group memberships; configure privileged access.
- **Practised in:** LNX-45, on `node1`.
- **Reset:** restore the `pre-w02` snapshot.

## Prerequisites

- `node1` reachable over SSH as a user in `wheel` (here `apantoja`).
- Snapshot `pre-w02` taken on node1 and node2.
- No users or groups named `team`, `ops`, `user1`, `user2`, `user3`, `svc1`, `svc2`, and UID 2001 and GID 3000 free (`getent passwd 2001`, `getent group 3000` return nothing).

## 1. Groups

```bash
sudo groupadd -g 3000 team
sudo groupadd ops
getent group team ops
```

```
team:x:3000:
ops:x:3001:
```

Without `-g`, the next free GID is used.

## 2. Users

```bash
sudo useradd -u 2001 -G team user1
sudo useradd -G team,ops user2
sudo useradd -s /sbin/nologin svc1
id user1; id user2; id svc1
getent passwd user1 user2 svc1
```

```
uid=2001(user1) gid=2001(user1) groups=2001(user1),3000(team)
uid=2002(user2) gid=2002(user2) groups=2002(user2),3000(team),3001(ops)
uid=2003(svc1) gid=2003(svc1) groups=2003(svc1)
user1:x:2001:2001::/home/user1:/bin/bash
user2:x:2002:2002::/home/user2:/bin/bash
svc1:x:2003:2003::/home/svc1:/sbin/nologin
```

- Each user gets a primary group with its own name and GID (user private group).
- `-G` sets **supplementary** groups. Without `-u`, the next UID after the highest in use is taken: `user2` got 2002, after `user1`'s 2001.
- `/sbin/nologin` is for service accounts: the account exists, but nobody can log in with it.

## 3. Passwords and changes to existing users

Set passwords before locking: locking or unlocking an account with no password fails.

```bash
sudo passwd user1
sudo passwd user2
```

### Add a group without losing the others: `-aG`

```bash
sudo usermod -aG ops user1
id user1
```

```
uid=2001(user1) gid=2001(user1) groups=2001(user1),3000(team),3001(ops)
```

What happens without `-a`:

```bash
sudo usermod -G ops user2
id user2
```

```
uid=2002(user2) gid=2002(user2) groups=2002(user2),3001(ops)
```

`-G` alone **replaces** the supplementary groups: `user2` lost `team`. Fix with `sudo usermod -aG team user2`.

Remove one group: `sudo gpasswd -d user1 ops`.

### Comment, lock, unlock

```bash
sudo usermod -c "Second lab user" user2
getent passwd user2
sudo usermod -L user2
sudo passwd -S user2
sudo grep '^user2:' /etc/shadow | cut -c1-20
sudo usermod -U user2
sudo passwd -S user2
```

```
user2:x:2002:2002:Second lab user:/home/user2:/bin/bash
user2 L 2026-10-04 0 99999 7 -1
user2:!$y$j9T$.3I87K
user2 P 2026-10-04 0 99999 7 -1
```

- `passwd -S`: `L` locked, `P` usable password. The numbers are last change, min, max, warn, inactive.
- Locking puts `!` in front of the hash in `/etc/shadow`; `$y$` is the yescrypt hash used by RHEL 10.
- A lock only blocks password logins. SSH keys still work; to block everything, also expire the account (`chage -E 0`).

## 4. Password aging

```bash
sudo chage -d 0 user1                  # must change at next login
sudo chage -M 90 -W 7 user2            # max 90 days, warn 7 days before
sudo chage -E 2026-12-31 user2         # account expires
sudo chage -l user1
sudo chage -l user2
```

```
Last password change                                    : password must be changed
Password expires                                        : password must be changed
...
Last password change                                    : Oct 04, 2026
Password expires                                        : Jan 02, 2027
Password inactive                                       : never
Account expires                                         : Dec 31, 2026
Maximum number of days between password change          : 90
Number of days of warning before password expires       : 7
```

- **Password expiry** (`-M`) forces a new password; **account expiry** (`-E`) disables the account on that date, whatever the password.
- `Password expires` is last change + max days: Oct 04 + 90 = Jan 02.

Forced change on first login:

```
$ su - user1
Password:
You are required to change your password immediately (administrator enforced).
Current password:
New password:
Retype new password:
```

It asks for the **current** password a second time. Getting it wrong there fails with `su: Authentication token manipulation error`.

## 5. Defaults for new users

```bash
sudo cp -p /etc/login.defs /etc/login.defs.bak
grep ^PASS_MAX_DAYS /etc/login.defs                       # 99999
sudo sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS\t60/' /etc/login.defs
sudo useradd user3
sudo chage -l user3 | grep Maximum                        # 60
sudo chage -l user1 | grep Maximum                        # 99999
```

`/etc/login.defs` is read when a user is **created**; existing users keep their values (change them with `chage`). Defaults for home directory and shell are in `useradd -D` / `/etc/default/useradd`.

## 6. Privileged access with sudo

Default rule for administrators:

```bash
sudo grep -E '^%wheel' /etc/sudoers
```

```
%wheel  ALL=(ALL)       ALL
```

A group rule applies to every member. `user1` must leave `ops` before `ops` gets full sudo, or it inherits it:

```bash
sudo gpasswd -d user1 ops
sudo visudo -f /etc/sudoers.d/lab
```

Content of `/etc/sudoers.d/lab`:

```
%ops    ALL=(ALL)   ALL
user1   ALL=(root)  /usr/bin/systemctl restart chronyd
```

```bash
sudo visudo -cf /etc/sudoers.d/lab          # /etc/sudoers.d/lab: parsed OK
sudo ls -l /etc/sudoers.d/                   # sudo needed: the directory is 0750 root
sudo -l -U user1
sudo -l -U user2
```

```
User user1 may run the following commands on node1:
    (root) /usr/bin/systemctl restart chronyd
User user2 may run the following commands on node1:
    (ALL) ALL
```

As `user1`:

```
$ sudo systemctl restart chronyd             # allowed, asks for user1's password
$ sudo whoami
Sorry, user user1 is not allowed to execute '/bin/whoami' as root on node1.
```

- Rule format: `who  where=(as whom)  what`. `%` marks a group. Commands need the full path.
- Never edit `/etc/sudoers` or a drop-in with a plain editor: a syntax error breaks `sudo` for everyone. `visudo` checks before saving.
- Files in `/etc/sudoers.d/` whose name contains a `.` or ends in `~` are **ignored**. Name it `lab`, not `lab.conf`.
- A user who has no rule gets `<user> is not in the sudoers file`, even if they belong to a group that will get one later.

## 7. Deleting users

```bash
sudo useradd svc2
sudo userdel svc1           # keeps home and mail spool
sudo userdel -r svc2        # removes them
ls -ln /home
ls /var/spool/mail/
```

```
drwx------. 2 2003 2003 62 Oct  4 17:37 svc1
...
apantoja  rpc  svc1  user1  user2  user3
```

Without `-r`, `/home/svc1` and its mail spool stay, owned by a UID with no name. A new user created later with UID 2003 would own them. Clean up:

```bash
sudo rm -rf /home/svc1 /var/spool/mail/svc1
```

## Verification

```bash
getent group team ops
id user1; id user2
sudo chage -l user1 | head -2
sudo -l -U user1
```

```
team:x:3000:user1,user2
ops:x:3001:user2
uid=2001(user1) gid=2001(user1) groups=2001(user1),3000(team)
uid=2002(user2) gid=2002(user2) groups=2002(user2),3000(team),3001(ops)
Last password change                                    : Oct 04, 2026
Password expires                                        : never
    (root) /usr/bin/systemctl restart chronyd
```

`user1`, `user2` and `team` are kept: the permissions lab (LNX-46) uses them.

## Rollback

- **Whole exercise:** power off `node1` and restore `pre-w02`.
- **By hand:**

```bash
sudo cp -p /etc/login.defs.bak /etc/login.defs
sudo rm /etc/sudoers.d/lab
sudo userdel -r user1; sudo userdel -r user2; sudo userdel -r user3
sudo groupdel team; sudo groupdel ops
```

`userdel -r` also removes the user's private group. `groupdel` fails on a group that is still some user's **primary** group.

## Mistakes made

- **`-G` without `-a`** removed `user2` from `team` (done on purpose to see it). Then `usermod -aG ops user2` re-added the wrong group; `id` after every change caught it.
- **Wrong current password in the forced change.** `su - user1` failed twice with `Authentication token manipulation error`: after the login password, the forced change asks for the current one again.
- **`ls -l /etc/sudoers.d/lab` as a normal user:** `Permission denied`, because the directory is `0750 root`. Use `sudo ls`.
- **`chage -M 90 -W user2`:** `invalid numeric argument 'user2'`; `-W` needs a number.
- **Group membership is not access by itself.** `user1` was in `ops` but got `user1 is not in the sudoers file` before the `ops` rule existed; after the rule, it would have had full sudo. That is why it is removed from `ops` before step 6.

## Quick reference

| Task | Command |
|---|---|
| Group with GID | `groupadd -g 3000 team` |
| User with UID and groups | `useradd -u 2001 -G team user1` |
| Service account | `useradd -s /sbin/nologin svc1` |
| Add a group | `usermod -aG ops user1` (never `-G` alone) |
| Remove from a group | `gpasswd -d user1 ops` |
| Lock / unlock | `usermod -L` / `usermod -U`, check `passwd -S` |
| Force change at next login | `chage -d 0 user1` |
| Max age, warning, expiry | `chage -M 90 -W 7 -E 2026-12-31 user2` |
| Show aging | `chage -l user2` |
| Defaults for new users | `/etc/login.defs`, `useradd -D` |
| Sudo drop-in | `visudo -f /etc/sudoers.d/lab`, check `visudo -cf` |
| What can a user run | `sudo -l -U user1` |
| Delete with home | `userdel -r user` |
