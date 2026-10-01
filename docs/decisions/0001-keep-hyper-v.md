# ADR 0001: Keep Hyper-V enabled on the host

- **Status:** Accepted
- **Date:** 2026-10-01

## Context

The host runs Windows 11 Home with Virtualization-Based Security active, so the Windows hypervisor owns the CPU virtualization extensions. VirtualBox cannot use AMD-V directly and falls back to the Windows Hypervisor Platform (NEM). The VM log shows it:

```
HM: HMR3Init: Attempting fall back to NEM: AMD-V is not available
```

In the VM window this shows as a green turtle icon in the status bar.

The first RHEL 10.2 install attempt showed a long black screen after GRUB and was initially misdiagnosed as missing AVX2 support. It was in fact slowness: the graphical installer appeared after about 10 minutes. The install then failed with an `lvmdbus` `PvCreate` timeout while a 99 GB file copy was running on the same host disk.

## Options considered

| Option | Result | Cost |
|---|---|---|
| A. Disable the Windows hypervisor (Memory Integrity off, `hypervisorlaunchtype off`) | VirtualBox runs natively, faster boot | Lower host security; WSL2 and Docker stop working; likely breaks other local VM-based tools. Reboot required. |
| B. Use Hyper-V instead of VirtualBox | Native performance with VBS on | Not available on Windows 11 Home |
| C. RHEL 9 only | Avoids RHEL 10 entirely | The EX200 exam is on RHEL 10 |
| D. AlmaLinux 10 x86_64_v2 | Runs without x86-64-v3 | Not needed: x86-64-v3 works under NEM with VirtualBox 7.2.10+ |

## Decision

Keep Hyper-V / VBS enabled and run RHEL 10 in VirtualBox on top of NEM (option A rejected, kept as fallback).

## Evidence

Measured on `rhel10-template` (2 vCPU, 2 GB RAM) with the host otherwise idle:

| Metric | Value |
|---|---|
| Install | 8 min |
| Boot (`systemd-analyze`) | 2 min 2 s total: kernel 1 min 50 s, initrd 4 s, userspace 8 s |
| `dnf` metadata download | 4-13 MB/s |

The slow part is the kernel phase of boot. Once booted, the system is responsive. The install failure was caused by host disk contention, not by Hyper-V.

## Consequences

- Expect about 2 minutes per VM boot; booting several VMs at once takes longer.
- Wait 10-15 minutes before declaring a boot hung. Remove `quiet` from the kernel command line in GRUB (`e`, edit, `Ctrl+X`) to see progress.
- Do not run heavy host disk workloads while lab VMs are running.
- Revisit if day-to-day lab work becomes too slow.
