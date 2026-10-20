# WB-GUARD installer (ASCII only, no external dependencies)
#
# Installs a removeChild guard at the top of WorkDaddy's inject.js so that the
# React unmount error "NotFoundError: removeChild is not a child of this node"
# no longer replaces the whole WorkBuddy page with the error screen.
#
# Usage (PowerShell):
#   powershell -ExecutionPolicy Bypass -File .\install-wb-guard.ps1
#   powershell -ExecutionPolicy Bypass -File .\install-wb-guard.ps1 -Verify
#   powershell -ExecutionPolicy Bypass -File .\install-wb-guard.ps1 -Restore
#
# Optional: -ScriptsDir "D:\path\to\WorkDaddy\scripts"
#
# After install, restart WorkDaddy (or WorkBuddy) so inject.js is re-injected.
# Verify in DevTools console: window.__wbRCGuardInstalled === true

param(
  [string]$ScriptsDir = "",
  [switch]$Verify,
  [switch]$Restore
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ScriptsDir)) {
  $ScriptsDir = Join-Path $env:LOCALAPPDATA "Programs\WorkDaddy\scripts"
}

$inject = Join-Path $ScriptsDir "inject.js"
$backup = Join-Path $ScriptsDir "inject.js.bak-wbguard"
$marker = "__wbRCGuardInstalled"

if (-not (Test-Path $inject)) {
  Write-Host "ERROR: not found -> $inject"
  exit 2
}

$guard = @'
/* WB-GUARD: removeChild unmount guard */
(function () {
  if (typeof Node === 'undefined' || !Node.prototype || !Node.prototype.removeChild) return;
  if (window.__wbRCGuardInstalled) return;
  window.__wbRCGuardInstalled = true;
  window.__wbRCGuarded = 0;
  var orig = Node.prototype.removeChild;
  Node.prototype.removeChild = function (child) {
    try {
      if (!child || child.parentNode !== this) { window.__wbRCGuarded++; return child; }
      return orig.call(this, child);
    } catch (e) {
      window.__wbRCGuarded++;
      return child;
    }
  };
})();

'@

$text = [System.IO.File]::ReadAllText($inject, [System.Text.Encoding]::UTF8)
$patched = $text.Contains($marker)

if ($Verify) {
  Write-Host ("file      : " + $inject)
  Write-Host ("size      : " + $text.Length + " chars")
  Write-Host ("patched   : " + $patched)
  Write-Host ("backup    : " + (Test-Path $backup))
  if ($patched) { exit 0 } else { exit 1 }
}

if ($Restore) {
  if (-not (Test-Path $backup)) {
    Write-Host "ERROR: backup not found -> $backup"
    exit 3
  }
  Copy-Item -LiteralPath $backup -Destination $inject -Force
  Write-Host "RESTORED: inject.js replaced by backup"
  Write-Host "Restart WorkDaddy / WorkBuddy to take effect."
  exit 0
}

if ($patched) {
  Write-Host "SKIP: guard already present in inject.js"
  exit 0
}

if (-not (Test-Path $backup)) {
  Copy-Item -LiteralPath $inject -Destination $backup -Force
  Write-Host ("BACKUP  : " + $backup)
} else {
  Write-Host ("BACKUP  : existing backup kept -> " + $backup)
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($inject, $guard + $text, $utf8)

$check = [System.IO.File]::ReadAllText($inject, [System.Text.Encoding]::UTF8)
if ($check.Contains($marker) -and $check.Length -gt $text.Length) {
  Write-Host ("PATCHED : " + $inject)
  Write-Host ("size    : " + $text.Length + " -> " + $check.Length + " chars")
  Write-Host "Restart WorkDaddy / WorkBuddy, then check window.__wbRCGuardInstalled === true"
  exit 0
}

Write-Host "ERROR: patch verification failed"
exit 4
