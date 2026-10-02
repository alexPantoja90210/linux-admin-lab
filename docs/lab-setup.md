# Lab setup

How the lab was built, in order. Following these steps on a similar Windows host reproduces it.

## 1. Host

| Item | Value |
|---|---|
| OS | Windows 11 Home |
| CPU | AMD Ryzen 7 5700U, 8 cores / 16 threads, supports x86-64-v3 (AVX2) |
| RAM | 16 GB |
| Virtualization | Enabled in firmware. Hyper-V / VBS is active on the host (see [ADR 0001](decisions/0001-keep-hyper-v.md)) |
| Free disk | ~125 GB after cleanup; the lab uses about 15-25 GB |

Check the host before starting (PowerShell):

```powershell
"CPU: " + (Get-CimInstance Win32_Processor).Name
"Virtualization in firmware: " + (Get-CimInstance Win32_Processor).VirtualizationFirmwareEnabled
"VBS status: " + (Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard).VirtualizationBasedSecurityStatus
(Get-CimInstance Win32_OperatingSystem).Caption
```

RHEL 10 requires the **x86-64-v3** microarchitecture level (AVX2, BMI2, FMA). RHEL 9 only requires x86-64-v2.

## 2. VirtualBox

1. Download **VirtualBox 7.2.20** for Windows hosts from https://www.virtualbox.org/wiki/Downloads.
2. Verify the installer against the published `SHA256SUMS`:

   ```powershell
   $expected = "a81777d2b36380ce042a29e9c554cf032eb46a793f62e3cc82e7411e535c2c26"
   $actual = (Get-FileHash "$env:USERPROFILE\Downloads\VirtualBox-7.2.20-175154-Win.exe" -Algorithm SHA256).Hash
   if ($actual -eq $expected.ToUpper()) { "MATCH" } else { "MISMATCH" }
   ```

3. Install as administrator. In **Custom Setup**, disable **USB Support** and **Python Support** (not needed by this lab). Keep **Networking**.
4. Do not install the Extension Pack.
5. Set the default machine folder: **File > Preferences > General > Default Machine Folder** = `C:\VMs`.
6. Verify:

   ```powershell
   & "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" --version   # 7.2.20r175154
   ```

> VirtualBox 7.2.8 had a regression that hid x86-64-v3 CPU features from guests when running on top of Hyper-V, so RHEL 10 failed at boot. It was fixed in 7.2.10. Use 7.2.10 or newer.

## 3. Installation media

Use the **Boot ISOs** (~1-1.5 GB), not the DVD ISOs (10-15 GB). The boot ISO installs packages from the Red Hat CDN once the system is registered during install.

1. Create a free account at https://developers.redhat.com and activate the **Red Hat Developer Subscription for Individuals**.
2. From https://access.redhat.com/downloads, download the x86_64 Boot ISO for RHEL 10.2 and RHEL 9.8.
3. Verify each one against the SHA-256 shown on the download page. The expected value must come from the page, never from your own `Get-FileHash` output.

| File | SHA-256 |
|---|---|
| `rhel-10.2-x86_64-boot.iso` | `675001a587c15f0c56c09beca6b1576c3be63cc4a0754e375ce93a6afda3dc8a` |
| `rhel-9.8-x86_64-boot.iso` | `18fecefe070e9c40502287281ec86e3bd4d64e2f48796a1cb166d9371308e5e6` |

4. Store them in `C:\VMs\iso`.

## 4. Network

A VirtualBox **NAT Network** lets VMs reach each other and the internet.

```powershell
$vbm = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
& $vbm natnetwork add --netname labnet --network "10.10.10.0/24" --enable --dhcp on
& $vbm natnetwork list
```

Plain NAT (the VirtualBox default) isolates each VM, so it is not used here.

## 5. Templates

Create each template VM with [`scripts/new-template-vm.ps1`](../scripts/new-template-vm.ps1):

```powershell
.\scripts\new-template-vm.ps1 -Name rhel10-template -IsoPath C:\VMs\iso\rhel-10.2-x86_64-boot.iso
.\scripts\new-template-vm.ps1 -Name rhel9-template  -IsoPath C:\VMs\iso\rhel-9.8-x86_64-boot.iso
```

### Installer settings

| Setting | Value |
|---|---|
| GRUB entry | **Install Red Hat Enterprise Linux** (skip "Test this media"; the ISO is already hash-verified) |
| Language | English (United States) |
| Keyboard | Spanish (Latin American) + English (US) |
| Connect to Red Hat | Register with the developer account |
| Installation source | Red Hat CDN |
| Software selection | Minimal Install |
| Installation destination | Automatic partitioning, 20 GB disk |
| KDUMP | Disabled (saves memory on 2 GB VMs) |
| Security profile | None (hardening is practised manually in W07) |
| Network & host name | Interface ON, host name = VM name, **Apply** |
| Root password | Set |
| User | `apantoja`, **Make this user administrator** checked |

On this host the first boot of the RHEL 10 installer shows a black screen for several minutes before the graphical installer appears. This is slowness under Hyper-V, not a hang.

### After install

```bash
cat /etc/redhat-release
sudo subscription-manager status
hostnamectl
sudo dnf -y update
sudo systemctl poweroff
```

Then, on the host, eject the ISO and take the `base` snapshot:

```powershell
$vbm = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
& $vbm storageattach rhel10-template --storagectl SATA --port 1 --device 0 --type dvddrive --medium emptydrive
& $vbm snapshot rhel10-template take base --description "RHEL 10.2 minimal, registered, updated"
& $vbm snapshot rhel10-template list
```

`rhel9-template` stays on RHEL 9.8; it is the starting point for the Leapp upgrade lab.

## 6. Linked clones

```powershell
.\scripts\new-linked-clones.ps1 -Template rhel10-template -Snapshot base -Names node1, node2
```

A linked clone stores only its differences from the template snapshot, so each one uses a few hundred MB instead of a full disk. The template must not be booted again after cloning.

### Generalize each clone

A clone starts as an exact copy of the template: same host name, same `machine-id` and the same Red Hat system identity. Fix all three before using it. Copy [`scripts/generalize-clone.sh`](../scripts/generalize-clone.sh) into the clone, or type the commands it contains, then:

```bash
sudo bash generalize-clone.sh node1
```

Do not use `subscription-manager register --force` on a clone. It unregisters the identity the clone inherited, which is the template's identity.

## 7. Verification

From `node1`:

```bash
ping -c 3 10.10.10.4                       # node2, VM to VM
curl -sI https://access.redhat.com | head -1   # HTTPS to the internet, expect HTTP/2 200
ping -c 3 8.8.8.8                          # ICMP to the internet
```

`redhat.com` drops ICMP, so it is not a valid ping target.

## 8. SSH from Windows

The VirtualBox console cannot paste text, so day-to-day work is done over SSH from the host. `labnet` is a NAT Network, so the host cannot reach `10.10.10.x` directly; port forwarding maps a local port on the host to port 22 of each VM. Rules bind to `127.0.0.1` only, so nothing else on the home network can reach the VMs.

```powershell
$vbm = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
& $vbm natnetwork modify --netname labnet --port-forward-4 "node1-ssh:tcp:[127.0.0.1]:2221:[10.10.10.3]:22"
& $vbm natnetwork modify --netname labnet --port-forward-4 "node2-ssh:tcp:[127.0.0.1]:2222:[10.10.10.4]:22"
& $vbm natnetwork list
```

| VM | Host endpoint | Guest |
|---|---|---|
| node1 | `127.0.0.1:2221` | `10.10.10.3:22` |
| node2 | `127.0.0.1:2222` | `10.10.10.4:22` |

Add the hosts to `%USERPROFILE%\.ssh\config` so `ssh node1` works:

```
Host node1
    HostName 127.0.0.1
    Port 2221
    User apantoja

Host node2
    HostName 127.0.0.1
    Port 2222
    User apantoja
```

PuTTY does not read this file: save one session per VM with host `127.0.0.1` and the port above.

Start the VMs without a console window:

```powershell
& $vbm startvm node1 --type headless
& $vbm startvm node2 --type headless
```

The forwarding rules point to the DHCP addresses. If a VM gets a different address, SSH to it fails; check with `ip -4 -br addr` on the console and update the rule. Static addressing is planned in W03 (LNX-30).

## 9. Practice disks

The storage labs destroy and rebuild disks, so `node1` has two empty 2 GB disks next to the system disk, and a snapshot taken right after attaching them. Restoring `pre-storage` returns both disks to empty.

```powershell
foreach ($d in "disk1","disk2") {
  & $vbm createmedium disk --filename "C:\VMs\node1\node1-$d.vdi" --size 2048 --format VDI --variant Standard
}
& $vbm storagectl node1 --name SATA --portcount 4
& $vbm storageattach node1 --storagectl SATA --port 2 --device 0 --type hdd --medium "C:\VMs\node1\node1-disk1.vdi"
& $vbm storageattach node1 --storagectl SATA --port 3 --device 0 --type hdd --medium "C:\VMs\node1\node1-disk2.vdi"
& $vbm snapshot node1 take pre-storage --description "Two empty 2 GB practice disks attached"
```

Result on `node1`:

```
sda                              8:0    0   20G  0 disk
├─sda1                           8:1    0  600M  0 part /boot/efi
├─sda2                           8:2    0    2G  0 part /boot
└─sda3                           8:3    0 17.4G  0 part
  ├─rhel_rhel10--template-root 253:0    0 15.4G  0 lvm  /
  └─rhel_rhel10--template-swap 253:1    0    2G  0 lvm  [SWAP]
sdb                              8:16   0    2G  0 disk
sdc                              8:32   0    2G  0 disk
```

`sda` is the system disk and is never used in exercises. Its volume group keeps the template's name (`rhel_rhel10-template`) because clones copy the disk as is.

### Resetting the practice disks

After each storage exercise, or when something breaks:

1. On `node1`: `sudo poweroff`.
2. VirtualBox Manager > `node1` > **Snapshots** tab (*Instantáneas* in the Spanish UI) > select `pre-storage` > **Restore** (*Restaurar*). Restore is disabled while the VM is running.
3. Answer **No** to "create a snapshot of the current state", unless the current state is worth keeping.
4. Start `node1`; `sdb` and `sdc` are empty again.

Or from PowerShell, with the VM powered off:

```powershell
& $vbm snapshot node1 restore pre-storage
```

"Current State (modified)" under a snapshot only means the VM has changed since the snapshot was taken; any boot does that.

## Measured results

| Metric | Value |
|---|---|
| RHEL 10.2 install (2 vCPU / 2 GB, host idle) | 8 min |
| RHEL 9.8 install (2 vCPU / 2 GB, host idle) | ~11 min |
| RHEL 10.2 boot (`systemd-analyze`) | 2 min 2 s: kernel 1 min 50 s, initrd 4 s, userspace 8 s |
| node1 to node2 ping | 0% loss, ~1-3 ms |
