[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$failures = @()

foreach ($file in Get-ChildItem -LiteralPath $projectRoot -Recurse -Filter '*.ps1' -File) {
    [Management.Automation.Language.Token[]]$tokens = $null
    [Management.Automation.Language.ParseError[]]$errors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    foreach ($parseError in @($errors)) {
        $failures += [pscustomobject]@{
            File = $file.FullName.Substring($projectRoot.Length + 1)
            Line = $parseError.Extent.StartLineNumber
            Message = $parseError.Message
        }
    }
}

if ($failures.Count -gt 0) {
    $failures | Format-Table -AutoSize | Out-String | Write-Error
    exit 1
}

Write-Output 'powershell_syntax=ok'
