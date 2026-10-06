# Runbook: NFS server, static NFS mount and autofs

Export directories over NFS from one node, mount one of them permanently on another node through `fstab`, and mount the other on demand with an autofs indirect map. Firewalld and SELinux stay enabled.

- **EX200 objectives:** mount and unmount network file systems using NFS; configure autofs.
- **Practised in:** LNX-40. `node2` (10.10.10.4) is the server, `node1` (10.10.10.3) the client.
- **Reset:** restore `pre-nfs` on node2 and `post-swap` on node1 (see [lab setup](../lab-setup.md#resetting-the-practice-disks)).

Node addresses come from DHCP: check them with `ip -4 -br addr` before starting.

## Prerequisites

- `node1` and `node2` running on `labnet`, each reachable over SSH as a user with `sudo`.
- The same user with the same UID on both nodes (`id apantoja` shows 1000 on both clones). Replace `apantoja` below with your lab user.
- Both nodes registered, so `dnf` can install `nfs-utils` and `autofs`.
- Snapshots taken: `pre-nfs` on node2, `post-swap` on node1.
- firewalld running and SELinux `Enforcing` on both nodes; this runbook keeps them that way.

## Server (node2)

### 1. Directories and exports

```bash
rpm -q nfs-utils || sudo dnf -y install nfs-utils
sudo mkdir -p /srv/nfs/shared /srv/nfs/home/user1
sudo chown apantoja:apantoja /srv/nfs/shared /srv/nfs/home/user1
echo "shared export on node2"  > /srv/nfs/shared/readme.txt       # test files read by the client
echo "user1 export on node2"   > /srv/nfs/home/user1/readme.txt

sudo tee /etc/exports <<'EOF'
/srv/nfs/shared      10.10.10.0/24(rw,sync)
/srv/nfs/home/user1  10.10.10.0/24(rw,sync)
EOF

sudo systemctl enable --now nfs-server
sudo exportfs -rv
```

- **No space between the client and the options.** `10.10.10.0/24(rw)` gives read-write to that network. `10.10.10.0/24 (rw)` gives the default read-only to that network **and read-write to everyone**.
- `exportfs -rv` re-reads `/etc/exports` and lists what is exported; no restart needed after editing.
- NFS identifies users by UID, not by name. Writing works here because `apantoja` is UID 1000 on both nodes (both cloned from the same template). Remote `root` is mapped to `nobody` (`root_squash`, the default).

### 2. Firewall

```bash
sudo firewall-cmd --permanent --add-service={nfs,rpc-bind,mountd}
sudo firewall-cmd --reload
sudo firewall-cmd --list-services
```

`nfs` (2049/tcp) is enough to mount with NFSv4. `rpc-bind` and `mountd` are needed for `showmount -e` on the client.

### 3. SELinux

```bash
getenforce                                       # Enforcing
getsebool nfs_export_all_rw nfs_export_all_ro    # both on (RHEL default)
```

These booleans allow the NFS server to export any directory. Nothing to change; do not disable SELinux.

## Client (node1)

### 4. Discover and test by hand

```bash
sudo dnf -y install nfs-utils autofs
showmount -e 10.10.10.4

sudo mkdir -p /mnt/shared
sudo mount -t nfs 10.10.10.4:/srv/nfs/shared /mnt/shared
cat /mnt/shared/readme.txt
sudo umount /mnt/shared
```

Always test a manual mount before writing `fstab`.

### 5. Static mount in `fstab`

```bash
echo '10.10.10.4:/srv/nfs/shared  /mnt/shared  nfs  defaults,_netdev  0 0' | sudo tee -a /etc/fstab
tail -1 /etc/fstab
sudo systemctl daemon-reload
sudo findmnt --verify
sudo mount -a
df -hT /mnt/shared        # type nfs4
```

- `_netdev` marks the mount as needing the network, so systemd waits for it at boot instead of trying before the interface has an address.
- `df` shows the size of the server file system that holds the export (here node2's root file system, 16G).

### 6. autofs, indirect map

```bash
echo '/remote  /etc/auto.remote  --timeout=60' | sudo tee /etc/auto.master.d/remote.autofs
echo 'user1  -rw,sync  10.10.10.4:/srv/nfs/home/user1' | sudo tee /etc/auto.remote
sudo systemctl enable --now autofs
```

| File | Line | Meaning |
|---|---|---|
| `/etc/auto.master.d/remote.autofs` | `/remote  /etc/auto.remote  --timeout=60` | autofs controls `/remote`, keys are in `/etc/auto.remote`, unmount after 60 s idle (default 300) |
| `/etc/auto.remote` | `user1  -rw,sync  10.10.10.4:/srv/nfs/home/user1` | `/remote/user1` mounts this export on access |

- Do not create `/remote` or `/remote/user1`; autofs manages them.
- After editing a map: `sudo systemctl reload autofs`.
- Several users with one line (wildcard map): `*  -rw,sync  10.10.10.4:/srv/nfs/home/&`, where `&` is replaced by the key.
- A **direct map** uses `/-` in the master map and absolute paths as keys, for mounting at arbitrary locations.

### 7. Test on demand mounting

```bash
ls /remote                 # empty: nothing mounted yet
cd /remote/user1           # triggers the mount
cat readme.txt
mount | grep user1         # nfs4 on /remote/user1
cd ~
sleep 75; mount | grep user1 || echo "unmounted"
```

## Reboot test (node1)

With node2 running:

```bash
sudo systemctl reboot
# after reconnecting
df -hT /mnt/shared
systemctl is-active autofs
cat /remote/user1/readme.txt
```

Result in the lab: `/mnt/shared` mounted as nfs4 at boot, autofs active, `/remote/user1` mounted on access.

**Boot order:** start node2 before node1. The default NFS mount option is `hard`: if the server is down, processes reading the mount wait until it returns, and commands such as `df` or `ls` on the mount point appear to hang.

## Rollback

- **Whole exercise:** power off both nodes, restore `post-swap` on node1 and `pre-nfs` on node2.
- **By hand, client first** (a client with the server gone can hang on the `hard` mount):

```bash
# node1
sudo umount /mnt/shared
sudo sed -i '\|10.10.10.4:/srv/nfs/shared|d' /etc/fstab
sudo systemctl daemon-reload
sudo findmnt --verify
sudo systemctl disable --now autofs
sudo rm /etc/auto.master.d/remote.autofs /etc/auto.remote
sudo rmdir /mnt/shared

# node2
sudo systemctl disable --now nfs-server
sudo truncate -s 0 /etc/exports
sudo firewall-cmd --permanent --remove-service={nfs,rpc-bind,mountd}
sudo firewall-cmd --reload
sudo rm -rf /srv/nfs
```

## Mistakes made

None in the lab run: the static mount and autofs worked on the first try. The traps to watch, all listed above, are a space between client and options in `/etc/exports`, a missing `_netdev`, and starting node1 while node2 is down.

## Quick reference

| Task | Command |
|---|---|
| Reload exports | `exportfs -rv` |
| List exports from a client | `showmount -e <server>` |
| Manual mount | `mount -t nfs <server>:/path /mnt/point` |
| `fstab` line | `<server>:/path  /mnt/point  nfs  defaults,_netdev  0 0` |
| autofs master entry | `/remote  /etc/auto.remote  --timeout=60` in `/etc/auto.master.d/*.autofs` |
| autofs map entry | `key  -rw,sync  <server>:/path` |
| Reload autofs maps | `systemctl reload autofs` |
