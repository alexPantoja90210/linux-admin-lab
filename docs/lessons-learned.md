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

### Counterfeit external "SSD": 1 TB declared, 64 GB real

Context: freeing ~99 GB on the host by moving screen recordings to an external USB "SSD" before deleting the originals.

- **Symptoms:**
  - First copy (exFAT): the drive disconnected repeatedly; Windows then offered "scan and repair", which hung for hours.
  - Second copy (reformatted as NTFS): robocopy failed with `ERROR 1392 (0x00000570) The file or directory is corrupted and unreadable` on folders written early in the copy.
  - Write speed around 11 MB/s.
- **Evidence:**
  - `Get-PhysicalDisk`: `FriendlyName: SSD 3.0`, `BusType: USB`, `MediaType: Unspecified`, 977 GB. No vendor, generic name.
  - System event log: `disk` event 11 (*controller error*) on `\Device\Harddisk2\DR59`, `DR60`, then `Harddisk1\DR1`. The changing DR number means the device kept dropping and re-enumerating.
  - `Ntfs` event 55: corrupted `$I30:$INDEX_ALLOCATION` on directories that had been written correctly earlier, with no controller errors at that time.
  - The drive shipped with a USB 2 cable, which limits speed and power regardless of the host port.
  - [ValiDrive](https://www.grc.com/validrive.htm) report: **declared 1,048,576,000,000 bytes (1.05 TB), validated 63,826,366,464 bytes (63.8 GB)**; vendor field empty, product `ssd_3.0`.
- **Cause:** a 64 GB flash chip with firmware that reports 1 TB. Writes past the real capacity wrap around and silently overwrite data stored earlier, which corrupts file system metadata. Reformatting cannot fix it.
- **What prevented data loss:** the copy script verified every file on the destination before anything was deleted, and the cleanup script only deletes files whose backup matches. The originals were never touched.
- **Rules:**
  - Validate any new external drive with ValiDrive (minutes) or H2testw (hours) before trusting it with data.
  - Never delete originals until the backup is verified, ideally by hash.
  - Corruption on two different file systems points to hardware, not formatting.
  - Read the system event log (`Get-WinEvent`, providers `disk`, `Ntfs`) before guessing.

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

## Storage

### Disk names changed between boots

- **Symptom:** on one boot `lsblk` showed the system disk as `sda` and the practice disks as `sdb` and `sdc`. On the next boot `/boot` was on `/dev/sdc2`: the system disk had become `sdc`.
- **Cause:** `sdX` names are assigned in the order the kernel detects the disks, which is not guaranteed to be the same on every boot (here, under Hyper-V with three disks on one SATA controller).
- **Rules:**
  - Before any destructive command (`parted`, `mkfs`, `pvcreate`, `wipefs`), run `lsblk` and identify the disk by size and content, not by name. In this lab the practice disks are 2 GB and empty; the system disk is 20 GB with `/boot` and LVM.
  - Never use `/dev/sdX` in `/etc/fstab`. Use `UUID=` or `LABEL=`, which belong to the file system and do not change when the device name does.

### Stray `$` in an `fstab` line

- **Symptom:** `findmnt --verify` reported `[E] unsupported source tag: =d3cfceb6-...` and `swapon -a` failed with `cannot open =d3cfceb6-...`.
- **Cause:** the line was written with `echo "$UUID=$P_UUID none swap ..."`. Inside double quotes the shell expanded `$UUID` as a variable; it was not set, so it became an empty string and the line started with `=` instead of `UUID=`.
- **Fix:** `sudo sed -i 's/^=/UUID=/' /etc/fstab`, then `findmnt --verify` again.
- **Rules:**
  - Read the line back (`tail /etc/fstab`) after appending it, before anything else.
  - Always run `findmnt --verify` and `mount -a` / `swapon -a` before rebooting. Here they caught the error with the system still up; after a reboot, a bad mount line can stop the boot.

## Network testing

### `ping redhat.com` showed 100% loss

- **Symptom:** DNS resolved, but no ICMP replies.
- **Cause:** `redhat.com` drops ICMP. `ping 8.8.8.8` worked, so the NAT network passes ICMP fine.
- **Lesson:** test internet access with the protocol you actually need, e.g. `curl -sI https://access.redhat.com`.
