<#
.SYNOPSIS
    Creates a VirtualBox VM ready to install RHEL from a boot ISO.

.DESCRIPTION
    Creates and registers the VM, attaches a dynamically allocated disk and
    the ISO, connects it to the lab NAT network and starts it. Stops if a VM
    with the same name already exists.

.EXAMPLE
    .\new-template-vm.ps1 -Name rhel10-template -IsoPath C:\VMs\iso\rhel-10.2-x86_64-boot.iso
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Name,
    [Parameter(Mandatory)] [string]$IsoPath,
    [int]$Cpus = 2,
    [int]$MemoryMB = 2048,
    [int]$DiskGB = 20,
    [string]$NatNetwork = 'labnet',
    [string]$BaseFolder = 'C:\VMs',
    [switch]$NoStart
)

$ErrorActionPreference = 'Stop'
$vbm = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'

function Invoke-VBox {
    & $vbm @args
    if ($LASTEXITCODE -ne 0) { throw "VBoxManage $($args -join ' ') failed with exit code $LASTEXITCODE" }
}

if (-not (Test-Path $vbm))     { throw "VBoxManage not found at $vbm" }
if (-not (Test-Path $IsoPath)) { throw "ISO not found: $IsoPath" }
if ((& $vbm list vms) -match "^`"$([regex]::Escape($Name))`" ") { throw "A VM named '$Name' already exists" }
if (-not ((& $vbm natnetwork list) -match "Name:\s+$([regex]::Escape($NatNetwork))$")) {
    throw "NAT network '$NatNetwork' not found. Create it first (see docs/lab-setup.md)."
}

$vdi = Join-Path $BaseFolder "$Name\$Name.vdi"

Invoke-VBox createvm --name $Name --ostype RedHat_64 --basefolder $BaseFolder --register
Invoke-VBox modifyvm $Name --cpus $Cpus --memory $MemoryMB --vram 16 --graphicscontroller vmsvga `
    --firmware efi --nic1 natnetwork --nat-network1 $NatNetwork
Invoke-VBox createmedium disk --filename $vdi --size ($DiskGB * 1024) --format VDI --variant Standard
Invoke-VBox storagectl $Name --name SATA --add sata --controller IntelAhci --portcount 2
Invoke-VBox storageattach $Name --storagectl SATA --port 0 --device 0 --type hdd --medium $vdi
Invoke-VBox storageattach $Name --storagectl SATA --port 1 --device 0 --type dvddrive --medium $IsoPath

Write-Host "VM '$Name' created: $Cpus vCPU, $MemoryMB MB RAM, $DiskGB GB disk, network '$NatNetwork'." -ForegroundColor Green

if (-not $NoStart) {
    Invoke-VBox startvm $Name
    Write-Host 'Under Hyper-V the installer can take several minutes to appear. Do not reset the VM early.'
}
