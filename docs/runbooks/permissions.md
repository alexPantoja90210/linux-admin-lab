# Runbook: default permissions, shared directories and permission problems

Control default permissions with `umask`, build a group-shared directory with set-GID, a default ACL and the sticky bit, and diagnose four common permission problems.

- **EX200 objectives:** manage default file permissions (Manage security); diagnose and correct file permission problems (Create and configure file systems).
- **Practised in:** LNX-46, on `node1`, right after the [users and groups runbook](users-and-groups.md).
- **Reset:** restore `pre-w02` (this also undoes LNX-45).

## Prerequisites

- `user1` (member of `team`), `user2` (member of `team` and `ops`) and group `team` (GID 3000) from LNX-45, each with a password.
- The `acl` package, for `setfacl` and `getfacl`. It is **not** in the RHEL 10 minimal install:

```bash
rpm -q acl || sudo dnf -y install acl
```

XFS supports ACLs without any mount option; only the tools were missing.

### Working as the test users

Administration is done as the admin user (`apantoja`) with `sudo`; tests run as `user1` / `user2` with **one command per `su`**:

```bash
su - user1 -c 'command; other command'
```

Do not paste a block of commands after `su - user1`: the password prompt discards the rest of the paste, so the commands never run, and an `exit` that is lost leaves nested sessions (see *Mistakes made*).

## 1. umask

```bash
umask                                         # 0022
mkdir ~/umask-test && cd ~/umask-test
for m in 022 027 002; do (umask $m; touch f$m; mkdir d$m); done
ls -l
```

```
drwxrwxr-x. 2 apantoja apantoja 6 Oct  4 17:58 d002
drwxr-xr-x. 2 apantoja apantoja 6 Oct  4 17:58 d022
drwxr-x---. 2 apantoja apantoja 6 Oct  4 17:58 d027
-rw-rw-r--. 1 apantoja apantoja 0 Oct  4 17:58 f002
-rw-r--r--. 1 apantoja apantoja 0 Oct  4 17:58 f022
-rw-r-----. 1 apantoja apantoja 0 Oct  4 17:58 f027
```

- New files start from 666 and directories from 777; the umask **removes** bits. Files never get `x` by default.
- `( )` runs a subshell, so the umask change does not stay in the session.
- RHEL 10 gives regular users **0022**, even with user private groups (older RHEL used 002 for them).

Persistent umask for one user:

```bash
echo 'umask 027' | sudo tee -a /home/user2/.bashrc
su - user2 -c umask                           # 0027
```

System-wide: `UMASK` in `/etc/login.defs`, or a script in `/etc/profile.d/`.

## 2. Shared directory: set-GID

```bash
sudo mkdir /srv/team
sudo chgrp team /srv/team
sudo chmod 2770 /srv/team
ls -ld /srv/team                              # drwxrws---. root team
```

Each user writes a file, and `user2` tries to append to `user1`'s:

```bash
su - user1 -c 'umask; echo "from user1" > /srv/team/u1.txt'
su - user2 -c 'umask; echo "from user2" >> /srv/team/u1.txt'
su - user2 -c 'echo "from user2" > /srv/team/u2.txt; ls -l /srv/team'
```

```
0027
-bash: line 1: /srv/team/u1.txt: Permission denied
-rw-r--r--. 1 user1 team 11 Oct  4 18:07 u1.txt
-rw-r-----. 1 user2 team 11 Oct  4 18:07 u2.txt
```

- **Set-GID on a directory** makes new files inherit the directory's **group** (`team`) instead of the creator's primary group.
- It does **not** give the group write permission: that comes from each creator's umask (022 for `user1`, 027 for `user2`). So the users cannot edit each other's files.

Without set-GID, for comparison (`/srv/nosgid`, mode `0770`, group `team`):

```
-rw-r--r--. 1 user1 user1 0 Oct  4 18:12 x.txt
```

### Fix: default ACL

```bash
sudo setfacl -d -m g:team:rwx /srv/team
sudo sh -c 'chmod g+w /srv/team/*.txt'        # files that already existed
sudo getfacl /srv/team
ls -ld /srv/team
```

```
# flags: -s-
user::rwx
group::rwx
other::---
default:user::rwx
default:group::rwx
default:group:team:rwx
default:mask::rwx
default:other::---

drwxrws---+ 2 root team 34 Oct  4 18:07 /srv/team
```

```bash
su - user2 -c 'echo new2 > /srv/team/u2b.txt'
su - user1 -c 'echo edit-by-user1 >> /srv/team/u2b.txt && cat /srv/team/u2b.txt'
su - user2 -c 'echo "from user2" >> /srv/team/u1.txt && echo OK'
sudo ls -l /srv/team
```

```
new2
edit-by-user1
OK
-rw-rw-r--. 1 user1 team 22 Oct  4 18:11 u1.txt
-rw-rw----+ 1 user2 team 19 Oct  4 18:11 u2b.txt
-rw-rw----. 1 user2 team 11 Oct  4 18:07 u2.txt
```

- When a directory has a **default ACL**, new files get their permissions from it and the creator's **umask is not applied**: `u2b.txt` is `rw-rw----` although `user2` has umask 027.
- The default ACL only applies to **new** files; existing ones needed `chmod g+w`.
- `+` at the end of the mode means the file has an ACL. `# flags: -s-` is setuid / **setgid** / sticky.

## 3. Sticky bit

Before: write permission on the directory is enough to delete anyone's file.

```bash
su - user1 -c 'touch /srv/team/tmp1.txt'
su - user2 -c 'rm -f /srv/team/tmp1.txt && echo deleted'      # deleted
```

After:

```bash
sudo chmod 3770 /srv/team
ls -ld /srv/team                              # drwxrws--T+ 2 root team
su - user1 -c 'touch /srv/team/tmp2.txt'
su - user2 -c 'rm /srv/team/tmp2.txt'
```

```
rm: cannot remove '/srv/team/tmp2.txt': Operation not permitted
```

- With the sticky bit, only the file's owner, the directory's owner or root can delete or rename a file.
- `T` (upper case): sticky set, `x` for others not set. `/tmp` shows `t` (`drwxrwxrwt`) because others have `x`.

## 4. chmod, chown, chgrp

```bash
cd ~ && touch modes.txt
chmod 664 modes.txt;          stat -c '%a %A' modes.txt
chmod u+x,g-w,o= modes.txt;   stat -c '%a %A' modes.txt
chmod 750 modes.txt;          stat -c '%a %A' modes.txt
sudo chown user1:team modes.txt; ls -l modes.txt
sudo chgrp user2 modes.txt;      ls -l modes.txt
sudo chown apantoja: modes.txt;  ls -l modes.txt
```

```
664 -rw-rw-r--
740 -rwxr-----
750 -rwxr-x---
-rwxr-x---. 1 user1 team 0 Oct  4 18:14 modes.txt
-rwxr-x---. 1 user1 user2 0 Oct  4 18:14 modes.txt
-rwxr-x---. 1 apantoja apantoja 0 Oct  4 18:14 modes.txt
```

`chown user:` (colon, no group) also sets the group to that user's login group. Special bits in octal: 4000 setuid, 2000 setgid, 1000 sticky.

## 5. Diagnosing permission problems

Tools: `ls -l`, `ls -ld`, `namei -l <path>` (permissions of every directory on the path), `getfacl`, `id`.

### Case A: directory without `x`

Setup: `/srv/cases/docs` is `root:team`, mode `760`; `a.txt` inside is `644`.

```
$ su - user1 -c 'cat /srv/cases/docs/a.txt'
cat: /srv/cases/docs/a.txt: Permission denied
$ su - user1 -c 'ls -l /srv/cases/docs'
ls: cannot access '/srv/cases/docs/a.txt': Permission denied
-????????? ? ? ? ?            ? a.txt
$ su - user1 -c 'namei -l /srv/cases/docs/a.txt'
dr-xr-xr-x root root /
drwxr-xr-x root root srv
drwxr-xr-x root root cases
drwxrw---- root team docs
                      a.txt - Permission denied
```

- **Cause:** on a directory, `r` lists the names and `x` lets you enter and reach what is inside. The group has `rw-` without `x`, so `user1` sees the name (`?????????` for the rest) but cannot open a file that is itself readable.
- **Fix:** `sudo chmod g+x /srv/cases/docs`.

### Case B: script without `x`

Setup: `/srv/cases/run.sh`, mode `644`.

```
$ su - user1 -c '/srv/cases/run.sh'
-bash: line 1: /srv/cases/run.sh: Permission denied
$ su - user1 -c 'bash /srv/cases/run.sh'
case B ok
```

- **Cause:** running a file directly needs `x`. `bash script` only needs `r`, because the program being run is `bash`. Removing `x` does not stop anyone who can read the script from running it.
- **Fix:** `sudo chmod 755 /srv/cases/run.sh`.

### Case C: file moved in with the wrong group

`user1` creates a file in its home and moves it into the shared directory:

```
$ su - user1 -c 'echo "case C" > ~/c.txt && chmod 660 ~/c.txt && mv ~/c.txt /srv/team/ && ls -l /srv/team/c.txt'
-rw-rw----. 1 user1 user1 7 Oct  4 18:18 /srv/team/c.txt
$ su - user2 -c 'cat /srv/team/c.txt'
cat: /srv/team/c.txt: Permission denied
```

- **Cause:** `mv` within a file system only renames: the file keeps its owner, group and mode. Set-GID and the default ACL apply only to **new** files. `user2` is neither owner nor in group `user1`, so it gets `other` (`---`). `cp` would have created a new file with group `team`.
- **Fix** (by `user1` itself, as owner and member of `team`): `chgrp team /srv/team/c.txt`.

### Case D: an ACL entry that overrides the group

Setup: `sudo setfacl -m u:user1:--- /srv/team/d.txt`.

```
$ su - user1 -c 'cat /srv/team/d.txt'
cat: /srv/team/d.txt: Permission denied
$ su - user1 -c 'id; ls -l /srv/team/d.txt'
uid=2001(user1) gid=2001(user1) groups=2001(user1),3000(team) ...
-rw-rwx---+ 1 root team 7 Oct  4 18:19 /srv/team/d.txt
$ sudo getfacl /srv/team/d.txt
user::rw-
user:user1:---
group::rwx
group:team:rwx
mask::rwx
other::---
```

- **Cause:** entries are checked in order (owner, **named users**, groups, other) and the first match wins. `user:user1:---` matches before `group:team:rwx`. `ls -l` alone does not show it; the `+` is the only hint.
- **Fix:** `sudo setfacl -x u:user1 /srv/team/d.txt`.
- With an ACL, the group column of `ls -l` shows the **mask**, not `group::`. `setfacl -m` recalculates the mask as the union of the group entries, which here gave the file group `x`; `sudo setfacl -m m::rw /srv/team/d.txt` removes it. `getfacl` then shows `#effective:rw-` next to each group entry.

## Verification

```bash
ls -ld /srv/team
sudo getfacl /srv/team | grep default
su - user1 -c 'cat /srv/team/d.txt /srv/cases/docs/a.txt; /srv/cases/run.sh'
su - user2 -c 'cat /srv/team/c.txt'
```

```
drwxrws--T+ 2 root team 91 Oct  4 18:19 /srv/team
default:user::rwx
default:group::rwx
default:group:team:rwx
default:mask::rwx
default:other::---
case D
case A
case B ok
case C
```

## Rollback

- **Whole exercise:** restore `pre-w02` (also undoes the users lab).
- **By hand:**

```bash
sudo rm -rf /srv/team /srv/nosgid /srv/cases
rm -rf ~/umask-test ~/modes.txt
sudo sed -i '/^umask 027$/d' /home/user2/.bashrc
```

## Mistakes made

- **Pasted a block after `su - user1`.** The password prompt discarded the rest of the paste; the commands did not run, a pasted line counted as a failed login, and the lost `exit` left `su - user2` running inside `user1`'s session. Files were then created by the wrong users. Fixed by running one `su - user -c '...'` per line.
- **`sudo rm -f /srv/team/*` deleted nothing.** The `*` is expanded by the calling shell, as `apantoja`, who cannot read `/srv/team`; `rm` got the literal `/srv/team/*` and `-f` hid the error. Fix: `sudo sh -c 'rm -f /srv/team/*'`, so root expands it. Same for `chmod` with a glob.
- **`umask 027` appended to `.bashrc` at least three times**, because the `tee -a` step ran more than once. `sed '$d'` removed one copy and two were still there. Fix: delete every copy with `sed -i '/^umask 027$/d'`, append once, check with `grep -c`.
- **`setfacl: command not found`:** the `acl` package is not in the minimal install.
- **Expected set-GID alone to make the directory shared.** It sets the group, not the group's write permission. A default ACL (or a umask of 002 for every user) is needed as well.

## Quick reference

| Task | Command |
|---|---|
| Show / set umask | `umask`, `umask 027` |
| Persistent umask for one user | `umask 027` in `~/.bashrc` |
| Shared directory | `chgrp team dir; chmod 2770 dir` |
| Group write for new files, whatever the umask | `setfacl -d -m g:team:rwx dir` |
| Only owners delete their files | `chmod +t dir` (or `3770`) |
| Permissions along a path | `namei -l /path/to/file` |
| Show ACL | `getfacl file` (`+` in `ls -l`) |
| Remove one ACL entry | `setfacl -x u:user1 file` |
| Remove all ACLs | `setfacl -b file` |
| Glob in a directory you cannot read | `sudo sh -c 'cmd /dir/*'` |
