# Runs entirely with mocked registry/WSL calls; no real Windows settings change.
# Compatible with Windows PowerShell 5.1 and PowerShell 7 on Linux.
$ErrorActionPreference = 'Stop'
$astraInstaller = Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts/install.ps1'
$astraPreviousOS = $env:OS
$astraPreviousUserProfile = $env:USERPROFILE
$astraMockDir = Join-Path ([System.IO.Path]::GetTempPath()) ('astra-win-mock-' + [Guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($astraMockDir) | Out-Null
$env:OS = 'Windows_NT'
$env:USERPROFILE = 'C:\Users\Test User'
$global:astraMockEdition = 'Professional'
$global:astraMockWslVersion = 2
$global:astraMockFailure = $false
$global:LASTEXITCODE = 0
function Get-ItemProperty {
 param([string]$Path)
 if ($Path -like '*CurrentVersion') { return [pscustomobject]@{CurrentBuildNumber='26100';EditionID=$global:astraMockEdition} }
 return [pscustomobject]@{DistributionName='Ubuntu-24.04';Version=$global:astraMockWslVersion}
}
function Get-ChildItem {
 param([string]$Path, $ErrorAction)
 return [pscustomobject]@{PSPath='MockDistro'}
}
function wsl.exe {
 $global:LASTEXITCODE = 0
 if ($args -contains '/usr/bin/id') { return '1000' }
 if ($args -contains '/usr/bin/printenv') { return '/home/Test User' }
 if ($args -contains '/usr/bin/wslpath') {
  if ($args[-1] -eq $env:USERPROFILE) {return '/mnt/c/Users/Test User'}
  return '/mnt/c/Test Source/astra-mcp'
 }
 if ($args -contains '--print-entry') {
  return '{"command":"/home/Test User/node/bin/node","args":["/home/Test User/astra/src/server.mjs"],"env":{"ASTRA_DATA_DIR":"/home/Test User/.local/share/astra-mcp","PATH":"/home/Test User/node/bin:/usr/bin:/bin"}}'
 }
 if ($global:astraMockFailure) {$global:LASTEXITCODE=42}
}
try {
 $config = Join-Path $astraMockDir 'mcp.json'
 $original = '{"mcpServers":{"playwright":{"command":"old"},"other":{"command":"keep"}},"otherSetting":true}'
 [IO.File]::WriteAllText($config,$original)
 & $astraInstaller -ReplaceLegacy -ConfigPath $config
 $after = [IO.File]::ReadAllText($config) | ConvertFrom-Json
 if ($after.mcpServers.PSObject.Properties['playwright']) {throw 'legacy kept'}
 if ($after.mcpServers.other.command -ne 'keep') {throw 'other lost'}
 if ($after.mcpServers.astra.command -ne 'wsl.exe') {throw 'wrong launcher'}
 if (-not ($after.mcpServers.astra.args -contains 'ASTRA_FILE_ROOTS=["/home/Test User","/mnt/c/Users/Test User"]')) {throw 'file roots quotes not preserved'}
 $backups = [IO.Directory]::GetFiles($astraMockDir,'*.backup-*')
 if ($backups.Length -ne 1 -or [IO.File]::ReadAllText($backups[0]) -ne $original) {throw 'backup mismatch'}
 $saved = [IO.File]::ReadAllText($config)
 $global:astraMockEdition = 'Core'
 try { & $astraInstaller -ConfigPath $config; throw 'Home not rejected' } catch {if ($_.Exception.Message -notlike '*Windows 11 Pro*') {throw}}
 $global:astraMockEdition = 'Professional'
 $global:astraMockWslVersion = 1
 try { & $astraInstaller -ConfigPath $config; throw 'WSL1 not rejected' } catch {if ($_.Exception.Message -notlike '*WSL 1*') {throw}}
 $global:astraMockWslVersion = 2
 $global:astraMockFailure = $true
 try { & $astraInstaller -ConfigPath $config; throw 'install failure not rejected' } catch {if ($_.Exception.Message -notlike '*setup failed*') {throw}}
 if ([IO.File]::ReadAllText($config) -ne $saved) {throw 'failed setup changed config'}
 Write-Host 'Windows installer mocks: configuration, backup, spaces, file-root JSON, Home/WSL1 rejection, and failed-install preservation passed.'
 # The expected failed WSL mock must not become GitHub Actions' final exit code.
 $global:LASTEXITCODE = 0
} finally {
 [IO.Directory]::Delete($astraMockDir,$true)
 $env:OS = $astraPreviousOS
 $env:USERPROFILE = $astraPreviousUserProfile
}
