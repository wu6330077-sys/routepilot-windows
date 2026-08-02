[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [string]$DataRoot = (Join-Path $env:ProgramData 'RoutePilot'),
    [switch]$RemoveData
)

$ErrorActionPreference = 'Stop'
$serviceName = 'RoutePilotHysteriaClient'
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script from an elevated PowerShell terminal.'
}

$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($service -and $PSCmdlet.ShouldProcess($serviceName, 'Stop and delete Windows service')) {
    Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
    & sc.exe delete $serviceName | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Failed to delete service: $LASTEXITCODE" }
    Write-Output 'service=removed'
} elseif (-not $service) {
    Write-Output 'service=not_found'
}

if ($RemoveData) {
    $fullDataRoot = [IO.Path]::GetFullPath($DataRoot).TrimEnd('\')
    $driveRoot = [IO.Path]::GetPathRoot($fullDataRoot).TrimEnd('\')
    $protectedRoots = @(
        $driveRoot,
        ([IO.Path]::GetFullPath($env:ProgramData).TrimEnd('\')),
        ([IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\'))
    )
    if ($fullDataRoot -in $protectedRoots) {
        throw "Refusing to remove a broad data path: $fullDataRoot"
    }
    if ((Test-Path -LiteralPath $fullDataRoot) -and $PSCmdlet.ShouldProcess($fullDataRoot, 'Recursively remove RoutePilot service data')) {
        Remove-Item -LiteralPath $fullDataRoot -Recurse -Force
        Write-Output 'data=removed'
    }
} else {
    Write-Output "data=retained:$DataRoot"
}
