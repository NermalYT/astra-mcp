#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Distribution = 'Ubuntu-24.04',
    [switch]$InstallSystemDeps,
    [switch]$ReplaceLegacy,
    [string]$ConfigPath = (Join-Path $env:USERPROFILE '.lmstudio\mcp.json'),
    [switch]$CheckOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Full Astra runs in WSL2. This launcher never injects host mouse or keyboard input.
if ($env:OS -ne 'Windows_NT') { throw 'Run this launcher in Windows 11 Pro PowerShell.' }
$astraWindows = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
if ([int]$astraWindows.CurrentBuildNumber -lt 22000 -or $astraWindows.EditionID -notin @('Professional', 'ProfessionalN')) {
    throw 'Astra supports Windows 11 Pro and Pro N (build 22000+) only. Home, Enterprise, Education, and Pro for Workstations are outside this release support policy.'
}
if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    throw 'WSL is missing. In an Administrator terminal run: wsl --install -d Ubuntu-24.04 . Restart Windows if requested, open Ubuntu, create your Linux user, and rerun this script.'
}
$astraDistributions = @(Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss' -ErrorAction SilentlyContinue | ForEach-Object { Get-ItemProperty $_.PSPath })
$astraDistro = @($astraDistributions | Where-Object { $_.DistributionName -eq $Distribution })
if ($astraDistro.Count -ne 1) {
    throw "Distribution '$Distribution' is not initialized for this Windows user. Run wsl --list --verbose. Install with wsl --install -d Ubuntu-24.04, open Ubuntu and create your Linux user, then rerun with -Distribution <installed-name>."
}
if ([int]$astraDistro[0].Version -ne 2) {
    throw "'$Distribution' uses WSL 1. Run wsl --set-version `"$Distribution`" 2, then retry."
}

function Invoke-AstraWslCapture {
    param([string[]]$Arguments)
    $astraOutput = & wsl.exe --distribution $Distribution --exec @Arguments
    if ($LASTEXITCODE -ne 0) { throw "WSL command failed (exit $LASTEXITCODE): $($Arguments[0])" }
    return (($astraOutput -join "`n") -replace "`0", '').Trim()
}

$astraLinuxUser = Invoke-AstraWslCapture -Arguments @('/usr/bin/id', '-u')
if ($astraLinuxUser -eq '0') { throw 'Your WSL default user is root. Configure an ordinary default Linux user before installing Astra.' }
$astraLinuxHome = Invoke-AstraWslCapture -Arguments @('/usr/bin/printenv', 'HOME')
if (-not $astraLinuxHome.StartsWith('/')) { throw 'WSL did not return an absolute Linux home directory.' }
$astraRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath (Join-Path $astraRoot 'package-lock.json'))) { throw 'Run install.ps1 from the complete Astra checkout or release archive, including package-lock.json.' }
$astraLinuxSource = Invoke-AstraWslCapture -Arguments @('/usr/bin/wslpath', '-u', $astraRoot)
$astraWindowsProfile = Invoke-AstraWslCapture -Arguments @('/usr/bin/wslpath', '-u', $env:USERPROFILE)

if ($CheckOnly) {
    & wsl.exe --distribution $Distribution --exec bash "$astraLinuxSource/scripts/install.sh" --check
    if ($LASTEXITCODE -ne 0) { throw 'Linux dependency check failed. Rerun without -CheckOnly and include -InstallSystemDeps.' }
    Write-Host 'Windows 11 Pro / WSL2 checks passed. No LM Studio configuration changed.'
    return
}

# A fresh source directory makes an upgrade reversible: old config backups still
# point to the old working source. No existing checkout or user data is deleted.
$astraStamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
$astraLinuxTarget = "$astraLinuxHome/.local/share/astra-mcp/sources/$astraStamp"
$astraInstallArgs = @('--distribution', $Distribution, '--exec', 'bash', "$astraLinuxSource/scripts/install.sh", '--copy-to', $astraLinuxTarget, '--skip-config')
if ($InstallSystemDeps) { $astraInstallArgs += '--system-deps' }
& wsl.exe @astraInstallArgs
if ($LASTEXITCODE -ne 0) { throw "Astra setup failed in WSL. Windows configuration is unchanged. The staged source is $astraLinuxTarget ." }
$astraLinuxEntry = (Invoke-AstraWslCapture -Arguments @('bash', "$astraLinuxTarget/scripts/install.sh", '--print-entry')) | ConvertFrom-Json

# Supply the Linux environment as arguments to Linux env, never as Windows PATH.
$astraLaunchArgs = @('--distribution', $Distribution, '--exec', '/usr/bin/env')
foreach ($astraProperty in $astraLinuxEntry.env.PSObject.Properties) { $astraLaunchArgs += "$($astraProperty.Name)=$($astraProperty.Value)" }
$astraFileRoots = ConvertTo-Json -InputObject @($astraLinuxHome, $astraWindowsProfile) -Compress
$astraLaunchArgs += "ASTRA_FILE_ROOTS=$astraFileRoots"
$astraLaunchArgs += [string]$astraLinuxEntry.command
$astraLaunchArgs += @($astraLinuxEntry.args)
$astraEntry = [ordered]@{ command = 'wsl.exe'; args = $astraLaunchArgs }
$ConfigPath = [System.IO.Path]::GetFullPath($ConfigPath)
$astraOriginal = $null
if (Test-Path -LiteralPath $ConfigPath) {
    $astraOriginal = [System.IO.File]::ReadAllText($ConfigPath)
    $astraConfig = $astraOriginal | ConvertFrom-Json
    if ($null -eq $astraConfig -or $astraConfig -isnot [System.Management.Automation.PSCustomObject]) { throw 'Existing MCP configuration must be a JSON object.' }
} else { $astraConfig = [pscustomobject]@{} }
if (-not $astraConfig.PSObject.Properties['mcpServers']) {
    $astraConfig | Add-Member -NotePropertyName mcpServers -NotePropertyValue ([pscustomobject]@{})
}
if ($null -eq $astraConfig.mcpServers -or $astraConfig.mcpServers -isnot [System.Management.Automation.PSCustomObject]) { throw 'Existing mcpServers must be a JSON object.' }
if ($ReplaceLegacy) {
    foreach ($astraLegacy in @('playwright', 'desktop-mouse', 'desktop-vision', 'desktop-keyboard', 'desktop-apps', 'terminal-files')) {
        $astraConfig.mcpServers.PSObject.Properties.Remove($astraLegacy)
    }
}
$astraConfig.mcpServers | Add-Member -NotePropertyName astra -NotePropertyValue $astraEntry -Force
$astraDirectory = Split-Path -Parent $ConfigPath
[System.IO.Directory]::CreateDirectory($astraDirectory) | Out-Null
$astraTemporary = "$ConfigPath.tmp-$astraStamp"
$astraBackup = "$ConfigPath.backup-$astraStamp"
$astraUtf8 = New-Object System.Text.UTF8Encoding($false)
try {
    $astraCurrent = if (Test-Path -LiteralPath $ConfigPath) { [System.IO.File]::ReadAllText($ConfigPath) } else { $null }
    if ($astraCurrent -cne $astraOriginal) { throw 'MCP configuration changed during installation. Retry after saving your editor.' }
    [System.IO.File]::WriteAllText($astraTemporary, (($astraConfig | ConvertTo-Json -Depth 100) + "`n"), $astraUtf8)
    if ($null -ne $astraOriginal) {
        [System.IO.File]::Replace($astraTemporary, $ConfigPath, $astraBackup)
        Write-Host "Previous configuration: $astraBackup"
    } else { [System.IO.File]::Move($astraTemporary, $ConfigPath) }
} finally {
    if (Test-Path -LiteralPath $astraTemporary) { Remove-Item -LiteralPath $astraTemporary }
}
Write-Host "Astra registered in $ConfigPath . Restart LM Studio, select a tool-capable model, and enable mcp/astra."
Write-Host "Its independent desktop and headless browser run in WSL2 ($Distribution). Your Windows pointer is unaffected."
