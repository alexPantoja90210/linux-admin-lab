# Runbook: SSH key-based authentication and secure file transfer

Log in from `node1` to `node2` with an ed25519 key, type the passphrase once with `ssh-agent`, see what `sshd` does when the permissions are wrong, and move files with `scp`, `rsync` and `sftp`.

- **EX200 objectives:** configure key-based authentication for SSH; securely transfer files between systems (Manage security / Operate running systems).
- **Practised in:** LNX-47, from `node1` (client) to `node2` (server), as the lab user `apantoja`.
- **Reset:** no snapshot needed. To undo: remove the line from `~/.ssh/authorized_keys` on `node2` and delete `~/.ssh/id_ed25519*` on `node1`.

## Prerequisites

- Both VMs running (start `node2` first). All commands run on `node1` unless a step says `node2`.
- `node1` must resolve `node2`. The lab only had the name on the Windows host, so add it once on `node1`:

```bash
getent hosts node2 || echo "10.10.10.4 node2" | sudo tee -a /etc/hosts
ping -c 2 node2
```

- `rsync` must be installed on **both** VMs (it runs a process at each end). It was missing on `node1`:

```bash
rpm -q rsync || sudo dnf -y install rsync
```

## 1. Generate the key pair

```bash
ssh-keygen -t ed25519
ls -l ~/.ssh
```

Accept the default path and set a passphrase. Expected: `id_ed25519` (`-rw-------`) and `id_ed25519.pub` (`-rw-r--r--`). The private key never leaves `node1`; only the public key is copied.

## 2. Install the public key on node2

```bash
ssh-copy-id node2
ssh node2 'ls -ld ~/.ssh; ls -l ~/.ssh/authorized_keys'
```

`ssh-copy-id` asks for the **account password** once (no key is installed yet). Expected: `Number of key(s) added: 1`, `~/.ssh` is `drwx------` (700) and `authorized_keys` is `-rw-------` (600).

## 3. Type the passphrase only once

```bash
eval "$(ssh-agent -s)"
ssh-add
ssh-add -l
ssh -v node2 hostname 2>&1 | grep -i authenticated
```

Expected: the key is listed, then `Authenticated to node2 ([10.10.10.4]:22) using "publickey".` The agent only lives in that shell; after `exit` repeat the `eval` and `ssh-add`.

## 4. Break it on purpose

On `node2`:

```bash
chmod 777 ~/.ssh
```

On `node1`, force key authentication only, so it does not fall back to the password:

```bash
ssh -o PreferredAuthentications=publickey node2 hostname
```

Result: `Permission denied (publickey,gssapi-keyex,gssapi-with-mic,password)`. That list is what the server **offers**, not what was tried.

On `node2`, find the cause:

```bash
sudo journalctl -u sshd -n 15 --no-pager
```

The log line:

```
sshd-session[1427]: Authentication refused: bad ownership or modes for directory /home/apantoja/.ssh
```

Fix on `node2`, then test again from `node1`:

```bash
chmod 700 ~/.ssh
ssh node2 hostname
```

Why: `sshd` runs with `StrictModes yes`. If `~/.ssh` (or the home directory, or `authorized_keys`) is writable by anyone else, it refuses the key even when the key is correct, because someone else could have altered `authorized_keys`.

## 5. Transfer files

Prepare test files on `node1`:

```bash
mkdir -p ~/xfer/src
echo "hello from node1" > ~/xfer/hello.txt
for i in 1 2 3; do echo "file $i" > ~/xfer/src/f$i.txt; done
```

**scp**, both directions:

```bash
scp ~/xfer/hello.txt node2:~/
scp node2:~/hello.txt ~/xfer/hello-back.txt
cmp ~/xfer/hello.txt ~/xfer/hello-back.txt && echo identical
```

**rsync**, run twice:

```bash
rsync -av ~/xfer/src node2:~/
rsync -av ~/xfer/src node2:~/
```

The first run lists `src/` and the three files (282 bytes sent). The second lists nothing and sends only 125 bytes: `rsync` compares and copies differences only. No trailing slash on the source copies the directory itself; with a trailing slash (`src/`) it would copy only its contents.

**sftp**, one file:

```bash
echo "sftp test" > ~/xfer/sftp-test.txt
sftp node2
```

```
sftp> put /home/apantoja/xfer/sftp-test.txt
sftp> ls -l sftp-test.txt
sftp> bye
```

## Verification

- `ssh -v node2 hostname 2>&1 | grep -i authenticated` shows `using "publickey"`.
- No password or passphrase prompt for `scp`, `rsync` and `sftp` while the agent holds the key.
- `cmp` reports the round-trip file identical; the second `rsync` run copies nothing.

## Rollback

On `node2`, delete the key line from `~/.ssh/authorized_keys`; on `node1`, `rm ~/.ssh/id_ed25519*` and `ssh-add -D`. Remove `~/xfer` on `node1` and `~/hello.txt`, `~/src`, `~/sftp-test.txt` on `node2`. Password authentication was never changed on `node2`.

## Mistakes made

- Ran `eval "$(ssh-agent -s)"` in **PowerShell on Windows** (prompt `PS C:\...`): `eval` does not exist there and the Windows agent service is off. The agent that matters is the one in the `node1` shell.
- Ran the `scp` back-copy on `node2` instead of `node1`: it asked for a password and failed because `~/xfer` only exists on `node1`. Check the prompt before pasting.
- `ssh node1 hostname` from `node2` failed with `Could not resolve hostname`: the `node1` alias lives in the Windows SSH config, not in the VMs.
- `rsync` was not installed on `node1`; it had to be installed on both ends.

## Quick reference

| Task | Command |
|---|---|
| New key | `ssh-keygen -t ed25519` |
| Install key | `ssh-copy-id user@host` |
| Agent | `eval "$(ssh-agent -s)"; ssh-add; ssh-add -l` |
| Key-only test | `ssh -o PreferredAuthentications=publickey host` |
| Why was the key refused? | `sudo journalctl -u sshd -n 15` on the server |
| Correct modes | `~/.ssh` 700, `authorized_keys` 600, private key 600 |
| Copy | `scp file host:~/`, `scp host:~/file .` |
| Sync | `rsync -av src host:~/` |
| Interactive | `sftp host` then `put`, `get`, `ls`, `bye` |
