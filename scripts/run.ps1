param(
    [Parameter(Mandatory = $true)]
    [string]$Project,

    [Parameter(Mandatory = $true)]
    [ValidateSet('smoke', 'load')]
    [string]$Scenario,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$K6Args
)

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot

Set-Location $Root

$ProjectDir = Join-Path $Root "projects\$Project"
$ScriptPath = Join-Path $ProjectDir "scripts\$Scenario.js"

if (-not (Test-Path $ScriptPath)) {
    Write-Error "Script not found: $ScriptPath"
}

$EnvFile = Join-Path $ProjectDir '.env'
$ComposeArgs = @('compose', '--profile', 'tools', 'run', '--rm')

if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith('#') -and $line -match '^([^=]+)=(.*)$') {
            $ComposeArgs += @('-e', "$($Matches[1].Trim())=$($Matches[2].Trim())")
        }
    }
}

$ComposeArgs += @('k6', 'run', "/projects/$Project/scripts/$Scenario.js")
$ComposeArgs += $K6Args

Write-Host "Running: docker $($ComposeArgs -join ' ')" -ForegroundColor Cyan
& docker @ComposeArgs
exit $LASTEXITCODE
