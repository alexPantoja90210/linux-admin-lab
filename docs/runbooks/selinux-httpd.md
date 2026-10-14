# Runbook: SELinux modes, file labels, port labels and booleans (httpd example)

Use Apache (`httpd`) as the example service to practise the five SELinux objectives: modes, contexts, restoring default file contexts, port labels and booleans. Every fix is done with labels and booleans; SELinux is never switched off to make something work.

- **EX200 objectives:** set enforcing and permissive modes; list and identify SELinux file and process context; restore default file contexts; manage SELinux port labels; use Boolean settings to modify system SELinux settings.
- **Practised in:** LNX-50, on `node2` (RHEL 10.2, policy `targeted`, Enforcing).
- **Reset:** restore the `pre-selinux` snapshot on `node2`. `node1` mounts the NFS export of `node2`, so avoid touching `/mnt/shared` on `node1` while `node2` restarts.

## Prerequisites

- Snapshot `pre-selinux` on `node2` (PowerShell on the laptop):

```powershell
& "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" snapshot "node2" take "pre-selinux"
```

- Check mode and packages (on `node2`, via `ssh node2`):

```bash
getenforce
sestatus | head -4
rpm -q policycoreutils-python-utils setools-console httpd
```

`policycoreutils-python-utils` (it provides `semanage`) was installed; `httpd` was not; `setools-console` is not needed.

```bash
sudo dnf install httpd             # read "Total download size" before confirming
sudo useradd user1                 # for step 6
sudo systemctl enable --now httpd
```

- The firewall is W03. Test locally with `curl` on `node2`.
- `semanage` needs `sudo` also to **list**: as a normal user, `semanage port -l` fails with `ValueError: SELinux policy is not managed or store cannot be accessed`.

## 1. Modes

```bash
getenforce                          # Enforcing
sudo setenforce 0
getenforce                          # Permissive
sudo setenforce 1
getenforce                          # Enforcing
grep '^SELINUX=' /etc/selinux/config   # SELINUX=enforcing
```

- `setenforce` changes the mode **now** only; `SELINUX=` in `/etc/selinux/config` decides the mode at the next boot.
- Permissive was used here only to show the mode. It is not used to fix anything in this lab.

## 2. Contexts

```bash
ls -dZ /var/www/html
ps -eZ | grep httpd | head -3
id -Z
```

```
system_u:object_r:httpd_sys_content_t:s0 /var/www/html
system_u:system_r:httpd_t:s0       2846 ?        00:00:00 httpd
unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023
```

The third field is the **type**. The process runs in the domain `httpd_t`; the policy lets it read `httpd_sys_content_t` files. An SSH login is `unconfined_t`.

## 3. A document root outside `/var/www`

Create the site and point `httpd` to it:

```bash
sudo mkdir -p /srv/web
echo 'LNX-50 served from /srv/web' | sudo tee /srv/web/index.html
sudo tee /etc/httpd/conf.d/lab-web.conf <<'EOF'
DocumentRoot "/srv/web"
<Directory "/srv/web">
    Require all granted
</Directory>
EOF
sudo apachectl configtest
sudo systemctl restart httpd
```

`conf.d/*.conf` is read after `httpd.conf`, so this `DocumentRoot` wins. `AH00558 ... ServerName` is only a warning.

Before labelling it, the page is blocked:

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://localhost/      # 403
ls -dZ /srv/web /srv/web/index.html
sudo ausearch -m avc -ts recent | tail -3
```

```
unconfined_u:object_r:var_t:s0 /srv/web
type=AVC ... avc:  denied  { getattr } for  pid=3093 comm="httpd" path="/srv/web/index.html" ... scontext=system_u:system_r:httpd_t:s0 tcontext=unconfined_u:object_r:var_t:s0 tclass=file permissive=0
```

New files under `/srv` get the generic `var_t`, and `httpd_t` may not even read their attributes. Fix it with a persistent rule and apply it:

```bash
sudo semanage fcontext -a -t httpd_sys_content_t "/srv/web(/.*)?"
sudo restorecon -Rv /srv/web
curl -s http://localhost/                  # LNX-50 served from /srv/web
ls -dZ /srv/web /srv/web/index.html
sudo restorecon -Rnv /srv/web              # prints nothing: nothing left to change
```

`restorecon -Rv` printed `Relabeled /srv/web from ...var_t... to ...httpd_sys_content_t...` (and the same for `index.html`).

## 4. `chcon` against `semanage fcontext`

On a demo directory without a rule:

```bash
sudo mkdir /srv/demo
echo demo | sudo tee /srv/demo/index.html
ls -dZ /srv/demo                                       # var_t
sudo chcon -R -t httpd_sys_content_t /srv/demo
ls -dZ /srv/demo                                       # httpd_sys_content_t
sudo restorecon -Rv /srv/demo                          # Relabeled ... back to var_t
sudo semanage fcontext -a -t httpd_sys_content_t "/srv/demo(/.*)?"
sudo restorecon -Rv /srv/demo
ls -dZ /srv/demo                                       # httpd_sys_content_t, stays
sudo semanage fcontext -l -C                           # your local rules
sudo semanage fcontext -d "/srv/demo(/.*)?"
sudo rm -r /srv/demo
```

- `chcon` changes only the label on disk; `restorecon` (and a full relabel) puts back what the **policy** says, so the change is lost.
- `semanage fcontext` stores the rule in the policy, and `restorecon` then applies it. This is the persistent way.

## 5. Port label

```bash
echo 'Listen 82' | sudo tee -a /etc/httpd/conf.d/lab-web.conf
sudo systemctl restart httpd                           # fails
sudo journalctl -u httpd -n 6 --no-pager
```

```
(13)Permission denied: AH00072: make_sock: could not bind to address 0.0.0.0:82
no listening sockets available, shutting down
```

```bash
sudo ausearch -m avc -ts recent | grep name_bind | tail -1
```

```
avc:  denied  { name_bind } for  pid=3380 comm="httpd" src=82 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:reserved_port_t:s0 tclass=tcp_socket permissive=0
```

Port 82 is `reserved_port_t`. Label it and retry:

```bash
sudo semanage port -a -t http_port_t -p tcp 82
sudo semanage port -l | grep -w http_port_t
sudo systemctl restart httpd
curl -s http://localhost:82/                           # LNX-50 served from /srv/web
```

```
http_port_t                    tcp      82, 80, 81, 443, 488, 8008, 8009, 8443, 9000
http_port_t                    udp      80, 443
```

## 6. Booleans

```bash
getsebool httpd_enable_homedirs                        # off
```

Prepare the user site and enable `UserDir`:

```bash
sudo -u user1 mkdir -p /home/user1/public_html
echo 'user1 page' | sudo -u user1 tee /home/user1/public_html/index.html
sudo chmod o+x /home/user1
sudo sed -i -e 's/^\(\s*\)UserDir disabled/\1#UserDir disabled/' -e 's/^\(\s*\)#UserDir public_html/\1UserDir public_html/' /etc/httpd/conf.d/userdir.conf
grep -n '^ *UserDir' /etc/httpd/conf.d/userdir.conf    # 24:    UserDir public_html
sudo apachectl configtest
sudo systemctl restart httpd
```

With the boolean **off** the page is blocked, although the label is already right:

```bash
curl -s -o /dev/null -w '%{http_code}\n' 'http://localhost:82/~user1/'     # 403
ls -dZ /home/user1/public_html                         # httpd_user_content_t
sudo ausearch -m avc -ts recent | grep denied | tail -1
```

```
avc:  denied  { getattr } for  pid=3645 comm="httpd" path="/home/user1/public_html/index.html" ... tcontext=unconfined_u:object_r:httpd_user_content_t:s0 tclass=file permissive=0
```

`public_html` already gets `httpd_user_content_t` from the default rules, so this is not a wrong label: the policy rule is gated by the boolean. Turn it on:

```bash
sudo setsebool -P httpd_enable_homedirs on
getsebool httpd_enable_homedirs                        # on
curl -s 'http://localhost:82/~user1/'                  # user1 page
sudo semanage boolean -l -C
```

```
httpd_enable_homedirs          (on   ,   on)  Allow httpd to enable homed
```

`-P` writes the value into the policy: the pair is *(current, default)*. Without `-P` the change would be gone after a reboot.

## After a reboot

`sudo systemctl reboot` (boot at 21:30, `uptime -p` said `up 7 minutes` when checked):

```bash
getenforce                                  # Enforcing
curl -s http://localhost:82/                # LNX-50 served from /srv/web
sudo restorecon -Rnv /srv/web               # prints nothing
curl -s 'http://localhost:82/~user1/'       # user1 page
sudo semanage port -l | grep -w http_port_t | head -1   # 82 is there
getsebool httpd_enable_homedirs             # on
systemctl is-enabled httpd; systemctl is-active httpd   # enabled, active
```

## Verification (acceptance criteria)

| Criterion | Evidence |
|---|---|
| The page is served from `/srv/web` on port 82 with SELinux Enforcing, and still after a reboot | `curl http://localhost:82/` returned the page, `getenforce` said `Enforcing`, after the reboot too |
| `restorecon -Rnv /srv/web` reports nothing to change | It printed nothing, before and after the reboot |
| MUST NOT: fix anything with permissive or disabled | The only `setenforce 0` was the mode demo in step 1, followed by `setenforce 1`; every fix used a label or a boolean |

## Rollback

- Whole lab: restore the `pre-selinux` snapshot on `node2`.
- By hand (these commands were not run in this lab):

```bash
sudo rm /etc/httpd/conf.d/lab-web.conf
sudo semanage port -d -t http_port_t -p tcp 82
sudo semanage fcontext -d "/srv/web(/.*)?"
sudo setsebool -P httpd_enable_homedirs off
sudo sed -i -e 's/^\(\s*\)#UserDir disabled/\1UserDir disabled/' -e 's/^\(\s*\)UserDir public_html/\1#UserDir public_html/' /etc/httpd/conf.d/userdir.conf
sudo chmod o-x /home/user1
sudo rm -r /srv/web
sudo systemctl restart httpd
```

Remove `user1` with `sudo userdel -r user1`, and `httpd` with `sudo systemctl disable --now httpd && sudo dnf remove httpd`.

## Mistakes made

- **`semanage port -l` without `sudo`:** `ValueError: SELinux policy is not managed or store cannot be accessed`. The `-a` worked (the next `restart` started); the listing needs root too.
- **I expected `user_home_t` for `public_html`:** the default rules label it `httpd_user_content_t`. The 403 there came from the boolean, not from the label.
- **The `Total download size` of `httpd`** was not written down, so this runbook does not give it.

## Quick reference

```bash
getenforce; sestatus; sudo setenforce 0|1       # runtime; SELINUX= in /etc/selinux/config for boot
ls -Z FILE; ls -dZ DIR; ps -eZ | grep NAME; id -Z
sudo semanage fcontext -a -t TYPE "/path(/.*)?"; sudo restorecon -Rv /path
sudo restorecon -Rnv /path                      # dry run, prints what would change
sudo semanage fcontext -l -C                    # local rules only
sudo semanage port -a -t http_port_t -p tcp PORT; sudo semanage port -l | grep -w http_port_t
getsebool -a | grep httpd; sudo setsebool -P NAME on|off; sudo semanage boolean -l -C
sudo ausearch -m avc -ts recent | grep denied | tail -3
```
