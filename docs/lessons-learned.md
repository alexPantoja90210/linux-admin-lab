# Lessons learned

Problems hit while building the lab, with root cause and fix. Each one is a pattern that shows up again in real environments.

## Installation media

### DVD ISO downloads failed with "network error"

- **Symptom:** both RHEL DVD ISOs (10-15 GB) failed near the end, twice.
- **Cause:** very long downloads over time-limited download links; any interruption restarts from zero.
- **Fix:** use the Boot ISOs (~1-1.5 GB) and install packages from the Red Hat CDN.
- **Also:** delete the partial `.crdownload` files. Four failed attempts left about 50 GB of partial files on disk.

### Checksum verified against itself

- **Symptom:** a SHA-256 "MATCH" that proved nothing.
- **Cause:** the expected value was copied from the local `Get-FileHash` output instead of the vendor's download page.
- **Fix:** the expected hash must come from an independent source (the vendor's checksum page or file). A useful tell: vendors usually publish lowercase hashes, while `Get-FileHash` prints uppercase.

## Host

### Install failed: `PvCreate` lvmdbus timeout

- **Symptom:** `Failed to call the 'PvCreate' method on the '/com/redhat/lvmdbus1/Manager' object: Timeout was reached`.
- **Cause:** a 99 GB file copy was reading from the same host disk that holds the VM disk, on top of the Hyper-V (NEM) overhead. Storage operations inside the installer timed out.
- **Fix:** stop the host copy and restart the install. It finished in 8 minutes with the same VM settings.
- **Rule:** no heavy host disk workloads while lab VMs are running.

### RHEL 10 installer "hung" on a black screen

- **Symptom:** black screen with a cursor for several minutes after selecting the install entry in GRUB.
- **Cause:** slow kernel boot under NEM, not a failure. The installer appeared after about 10 minutes.
- **Lesson:** under the Windows hypervisor, wait 10-15 minutes before declaring a hang, and boot without `quiet` to watch progress. See [ADR 0001](decisions/0001-keep-hyper-v.md).

## Cloning

### Clone left without a machine-id

- **Symptom:** `Cannot open /etc/machine-id: No such file or directory`.
- **Cause:** `sudo rm -f /etc/machine-id && systemd-machine-id-setup`. The first command had `sudo`, the second did not, so the file was deleted and could not be recreated.
- **Fix:** `sudo systemd-machine-id-setup`. Every command in a chain needs its own `sudo`.

### Clone still using the template's Red Hat identity

- **Symptom:** `This system is already registered`.
- **Cause:** a typo (`subscription-manager clear` instead of `clean`) stopped the `&&` chain, so `register` never ran.
- **Fix:** `sudo subscription-manager clean` then `sudo subscription-manager register`, one command at a time, then check with `subscription-manager identity`.
- **Do not** use `register --force` on a clone: it unregisters the inherited identity on the portal, which belongs to the template.

## Users

### User not in the sudoers file

- **Symptom:** `apantoja is not in the sudoers file`.
- **Cause:** the user was created in the installer without **Make this user administrator**, so it is not in the `wheel` group.
- **Fix:** as root, `usermod -aG wheel apantoja`, then log in again. The `-a` matters: without it `-G` replaces all supplementary groups.

## Network testing

### `ping redhat.com` showed 100% loss

- **Symptom:** DNS resolved, but no ICMP replies.
- **Cause:** `redhat.com` drops ICMP. `ping 8.8.8.8` worked, so the NAT network passes ICMP fine.
- **Lesson:** test internet access with the protocol you actually need, e.g. `curl -sI https://access.redhat.com`.
