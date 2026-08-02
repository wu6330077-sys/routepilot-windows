[CmdletBinding()]
param([string]$OutputPath)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $projectRoot 'src\RoutePilotService.cs'
if (-not $OutputPath) { $OutputPath = Join-Path $projectRoot 'runtime\build\RoutePilotService.exe' }

$compilerCandidates = @(
    (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'),
    (Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe')
)
$compiler = $compilerCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $compiler) { throw 'The .NET Framework C# compiler was not found.' }
if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw "Service source not found: $sourcePath" }

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath) | Out-Null
& $compiler /nologo /target:exe /optimize+ /reference:System.ServiceProcess.dll "/out:$OutputPath" $sourcePath
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $OutputPath)) {
    throw "Service compilation failed with exit code $LASTEXITCODE."
}

[pscustomobject]@{
    OutputPath = [IO.Path]::GetFullPath($OutputPath)
    Compiler = $compiler
} | ConvertTo-Json -Depth 2
