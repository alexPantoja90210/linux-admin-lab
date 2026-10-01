<#
.SYNOPSIS
    Creates linked clones of a template VM from one of its snapshots.

.DESCRIPTION
    Each clone stores only its differences from the snapshot, so it uses very
    little disk. VirtualBox generates new MAC addresses for each clone.
    After cloning, run scripts/generalize-clone.sh inside every clone.

.EXAMPLE
    .\new-linked-clones.ps1 -Template rhel10-template -Snapshot base -Names node1, node2
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Template,
    [string]$Snapshot = 'base',
    [Parameter(Mandatory)] [string[]]$Names,
    [string]$BaseFolder = 'C:\VMs',
    [switch]$Start
)

$ErrorActionPreference = 'Stop'
$vbm = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'

function Invoke-VBox {
    & $vbm @args
    if ($LASTEXITCODE -ne 0) { throw "VBoxManage $($args -join ' ') failed with exit code $LASTEXITCODE" }
}

$snapshots = & $vbm snapshot $Template list 2>$null
if ($LASTEXITCODE -ne 0 -or -not ($snapshots -match "Name: $([regex]::Escape($Snapshot)) ")) {
    throw "Snapshot '$Snapshot' not found on VM '$Template'"
}

$existing = & $vbm list vms
foreach ($n in $Names) {
    if ($existing -match "^`"$([regex]::Escape($n))`" ") {
        Write-Warning "VM '$n' already exists, skipping."
        continue
    }
    Invoke-VBox clonevm $Template --snapshot $Snapshot --options=link --name $n --basefolder $BaseFolder --register
    Write-Host "Linked clone '$n' created from $Template@$Snapshot." -ForegroundColor Green
    if ($Start) { Invoke-VBox startvm $n }
}

Write-Host "Next: inside each clone run 'sudo bash generalize-clone.sh <hostname>'."
Write-Host "Do not boot '$Template' again; the clones depend on it."
