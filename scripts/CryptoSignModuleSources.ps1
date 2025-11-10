#╔════════════════════════════════════════════════════════════════════════════════╗
#║                                                                                ║
#║   CryptoSignModuleSources.ps1                                                  ║
#║                                                                                ║
#╟────────────────────────────────────────────────────────────────────────────────╢
#║   Guillaume Plante <codegp@icloud.com>                                         ║
#║   Code licensed under the GNU GPL v3.0. See the LICENSE file for details.      ║
#╚════════════════════════════════════════════════════════════════════════════════╝



# Sample Code For Example Only 

function Sign-ModuleSources {
<#
.SYNOPSIS
  Iterate module directories, enter ./src, and sign every .ps1 with Add-Signature.

.DESCRIPTION
  Looks under a root folder for module directories (default: PowerShell.Module.*),
  Push-Location into each ./src, and for every matching script:
    - Skip if already Authenticode Valid (counts as Skipped)
    - Otherwise call: Add-Signature -Path <script>
  Verbose + colorized logs. Prints a summary and returns an object.

.PARAMETER Root
  Root folder that contains your module directories.

.PARAMETER ModulePattern
  Directory name filter for modules. Default: PowerShell.Module.*

.PARAMETER SrcFolder
  Subfolder that contains source scripts. Default: src

.PARAMETER Extensions
  File patterns to sign. Default: *.ps1

.PARAMETER Recurse
  Recurse into subfolders of ./src.

.EXAMPLE
  Sign-ModuleSources -Root "C:\Users\gp\Documents\PowerShell\Module-Development" -Verbose
#>
  [CmdletBinding(SupportsShouldProcess=$true)]
  param(
    [Parameter(Mandatory=$true)]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$Root,

    [string]$ModulePattern = "PowerShell.Module.*",
    [string]$SrcFolder     = "src",
    [string[]]$Extensions  = @("*.ps1"),
    [switch]$Recurse
  )

  $counters = [ordered]@{
    ModulesTotal = 0
    ModulesWithSrc = 0
    ScriptsTotal = 0
    Signed = 0
    SkippedAlreadySigned = 0
    Failed = 0
  }

  Write-Host "=== Signing PowerShell sources ===" -ForegroundColor Cyan
  Write-Host "Root           : $Root"           -ForegroundColor DarkCyan
  Write-Host "ModulePattern  : $ModulePattern"  -ForegroundColor DarkCyan
  Write-Host "SrcFolder      : $SrcFolder"      -ForegroundColor DarkCyan
  Write-Host "Extensions     : $($Extensions -join ', ')" -ForegroundColor DarkCyan
  if ($Recurse) { Write-Host "Recurse        : On" -ForegroundColor DarkCyan }

  $modules = Get-ChildItem -Path $Root -Directory -Filter $ModulePattern -ErrorAction Stop
  $counters.ModulesTotal = $modules.Count

  foreach ($mod in $modules) {
    $src = Join-Path $mod.FullName $SrcFolder
    if (-not (Test-Path $src -PathType Container)) {
      Write-Verbose "[$($mod.Name)] No '$SrcFolder' folder. Skipping."
      continue
    }

    $counters.ModulesWithSrc++
    $files = Get-ChildItem -Path $src -File -Filter "*.ps1" -ErrorAction SilentlyContinue
    $foundScriptsCount = $files.Count
    Write-Host "`n-- Module: $($mod.Name)" -ForegroundColor Yellow
    Write-Host "     Looking for Module Scripts in Src: $src"            -ForegroundColor Yellow
    write-Host "     $foundScriptsCount scripts found! "            -ForegroundColor Yellow
    Write-Host ""
    
    if ($foundScriptsCount -eq 0) {
      Write-Host "   No scripts found." -ForegroundColor DarkYellow
      continue
    }

    $counters.ScriptsTotal += $files.Count

    Push-Location $src
    try {
      foreach ($f in $files) {
        $rel = Resolve-Path -LiteralPath $f.FullName -Relative
        Write-Verbose "   Inspect: $rel"

        # Skip already validly signed files
        $sig = $null
        try { $sig = Get-AuthenticodeSignature -FilePath $f.FullName } catch {}
        if ($sig -and $sig.Status -eq 'Valid') {
          Write-Host "   [SKIP] Already signed: $rel" -ForegroundColor DarkGray
          $counters.SkippedAlreadySigned++
          continue
        }

        if ($PSCmdlet.ShouldProcess($f.FullName, "Add-Signature")) {
          try {
            # Per request: CD ./src then call Add-Signature -Path <script>
            # (call with relative name to mirror your workflow)
            Add-Signature -Path $f.Name | Out-Null
            Write-Host "   [OK]   Signed: $rel" -ForegroundColor Green
            $counters.Signed++
          } catch {
            Write-Host "   [ERR]  $rel -> $($_.Exception.Message)" -ForegroundColor Red
            $counters.Failed++
          }
        }
      }
    }
    finally {
      Pop-Location
    }
  }

  Write-Host "`n=== Summary ===" -ForegroundColor Cyan
  Write-Host ("Modules scanned       : {0}" -f $counters.ModulesTotal)       -ForegroundColor Cyan
  Write-Host ("Modules with src      : {0}" -f $counters.ModulesWithSrc)     -ForegroundColor Cyan
  Write-Host ("Scripts discovered    : {0}" -f $counters.ScriptsTotal)       -ForegroundColor Cyan
  Write-Host ("Signed                : {0}" -f $counters.Signed)             -ForegroundColor Green
  Write-Host ("Skipped (already OK)  : {0}" -f $counters.SkippedAlreadySigned) -ForegroundColor DarkGray
  Write-Host ("Failed                : {0}" -f $counters.Failed)             -ForegroundColor Red

  [PSCustomObject]$counters
}
