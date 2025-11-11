#╔════════════════════════════════════════════════════════════════════════════════╗
#║                                                                                ║
#║   CertsFuncsExt.ps1                                                            ║
#║                                                                                ║
#╟────────────────────────────────────────────────────────────────────────────────╢
#║   Guillaume Plante <codegp@icloud.com>                                         ║
#║   Code licensed under the GNU GPL v3.0. See the LICENSE file for details.      ║
#╚════════════════════════════════════════════════════════════════════════════════╝
$Global:devcodesignDestPath =  Join-Path "C:\www\public-certificates" "devcodesign"
$Global:devcodesignPriv = Join-Path "$Global:devcodesignDestPath" "devcodesign.pfx"
$Global:devcodesignCer = Join-Path "$Global:devcodesignDestPath" "devcodesign.cer"


<# =====================================================================
   Self-Signed Code Signing Certificate Toolkit
   - PowerShell 7+
   - Creates Code Signing cert in CurrentUser\My
   - Exports PFX (private key) and CER (public cert)
   - Imports CER to LocalMachine\Root and LocalMachine\TrustedPublisher

   USAGE EXAMPLE (Dev machine):
     $cert = New-DevCodeSigningCert -Subject "CN=Guillaume Plante (Dev Code Signing)" -Years 3 -OutDir "$Global:devcodesignDestPath"
     Export-DevCodeSigningCert -Certificate $cert -OutDir "$Global:devcodesignDestPath" -PfxPassword "$Password"

   USAGE EXAMPLE (Target machine, as Administrator):
     Import-DevCodeSigningCertOnLocalMachine -CerPath "C:\www\public-certificates\raw\devcodesign.cer"

   NOTE:
     - Import to LocalMachine requires Admin.
     - Keep .pfx private and protected.
===================================================================== #>

#-------------------------------#
# Helpers
#-------------------------------#
function Write-Info {
    param([Parameter(Mandatory=$True, HelpMessage="Message")][string]$Message)
    Write-Host $Message -ForegroundColor Cyan
}
function Write-Good {
    param([Parameter(Mandatory=$True, HelpMessage="Message")][string]$Message)
    Write-Host $Message -ForegroundColor Green
}
function Write-Warn {
    param([Parameter(Mandatory=$True, HelpMessage="Message")][string]$Message)
    Write-Host $Message -ForegroundColor Yellow
}
function Write-Bad {
    param([Parameter(Mandatory=$True, HelpMessage="Message")][string]$Message)
    Write-Host $Message -ForegroundColor Red
}
function Test-IsAdmin {
    try {
        $id  = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $pr  = New-Object System.Security.Principal.WindowsPrincipal($id)
        return $pr.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $False
    }
}

#-------------------------------#
# Create self-signed code-signing cert
#-------------------------------#
function New-DevCodeSigningCert {
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory=$True, Position=0, HelpMessage="Subject")]
    [ValidateNotNullOrEmpty()]
    [string]$Subject,

    [Parameter(Mandatory=$True, Position=1, HelpMessage="Years")]
    [ValidateRange(1,10)]
    [int]$Years,

    [Parameter(Mandatory=$True, Position=2, HelpMessage="OutDir")]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$OutDir,

    [Parameter(Mandatory=$False, HelpMessage="KeyLength")]
    [ValidateSet(2048,3072,4096)]
    [int]$KeyLength = 3072
)
    Write-Info  "=== Creating self-signed Code Signing cert in CurrentUser\My ==="
    Write-Host "Subject: $Subject" -ForegroundColor DarkCyan
    Write-Host "Years  : $Years" -ForegroundColor DarkCyan
    Write-Host "KeyLen : $KeyLength" -ForegroundColor DarkCyan
    Write-Host "OutDir : $OutDir" -ForegroundColor DarkCyan

    try {
        $notAfter = (Get-Date).AddYears($Years)

        if ($PSCmdlet.ShouldProcess($Subject, "Create CodeSigning cert")) {
            $cert = New-SelfSignedCertificate `
                -Subject $Subject `
                -Type CodeSigningCert `
                -CertStoreLocation Cert:\CurrentUser\My `
                -KeyAlgorithm RSA `
                -KeyLength $KeyLength `
                -HashAlgorithm SHA256 `
                -KeyExportPolicy Exportable `
                -FriendlyName "Personal Dev Code Sign" `
                -NotAfter $notAfter

            if (-not $cert) { throw "New-SelfSignedCertificate returned null." }

            Write-Good "Certificate created."
            Write-Host ("Thumbprint : {0}" -f $cert.Thumbprint) -ForegroundColor Green
            Write-Host ("NotAfter   : {0}" -f $cert.NotAfter) -ForegroundColor Green

            # Save a quick text summary beside outputs for convenience
            $summary = Join-Path $OutDir "devcodesign-info.txt"
            @(
                "Subject    : $($cert.Subject)"
                "Thumbprint : $($cert.Thumbprint)"
                "Issuer     : $($cert.Issuer)"
                "NotBefore  : $($cert.NotBefore)"
                "NotAfter   : $($cert.NotAfter)"
                "Store      : Cert:\CurrentUser\My"
            ) | Out-File -FilePath $summary -Encoding utf8 -Force

            Write-Good "Wrote summary: $summary"
            return $cert
        }
    } catch {
        Write-Bad "ERROR creating certificate: $($_.Exception.Message)"
        throw
    }
}

#-------------------------------#
# Export PFX (private key) and CER (public)
#-------------------------------#
function Export-DevCodeSigningCert {
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory=$True, Position=0, HelpMessage="Certificate")]
    [ValidateNotNull()]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,

    [Parameter(Mandatory=$True, Position=1, HelpMessage="OutDir")]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$OutDir,

    [Parameter(Mandatory=$True, Position=2, HelpMessage="PfxPassword")]
    [ValidateNotNullOrEmpty()]
    [string]$PfxPassword,

    [Parameter(Mandatory=$False, HelpMessage="BaseFileName")]
    [ValidateNotNullOrEmpty()]
    [string]$BaseFileName = "devcodesign"
)
    Write-Info "=== Exporting certificate to PFX and CER ==="
    $pfxPath = Join-Path $OutDir ($BaseFileName + ".pfx")
    $cerPath = Join-Path $OutDir ($BaseFileName + ".cer")
    Write-Host "PFX: $pfxPath" -ForegroundColor DarkCyan
    Write-Host "CER: $cerPath" -ForegroundColor DarkCyan

    try {
        $sec = ConvertTo-SecureString -String $PfxPassword -AsPlainText -Force

        if ($PSCmdlet.ShouldProcess($pfxPath, "Export PFX")) {
            $null = Export-PfxCertificate -Cert $Certificate -FilePath $pfxPath -Password $sec
            Write-Good "Exported PFX."
        }
        if ($PSCmdlet.ShouldProcess($cerPath, "Export CER")) {
            $null = Export-Certificate -Cert $Certificate -FilePath $cerPath -Force
            Write-Good "Exported CER."
        }

        Write-Warn "Keep the PFX private and secure. Distribute only the CER to client machines."
        return [PSCustomObject]@{ PfxPath = $pfxPath; CerPath = $cerPath }
    } catch {
        Write-Bad "ERROR exporting certificate: $($_.Exception.Message)"
        throw
    }
}

#-------------------------------#
# Import CER to LocalMachine stores (Root + TrustedPublisher)
#-------------------------------#
function Import-DevCodeSigningCertOnLocalMachine {
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory=$True, Position=0, HelpMessage="CerPath")]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$CerPath,

    [Parameter(Mandatory=$False, HelpMessage="SkipTrustedPublisher")]
    [switch]$SkipTrustedPublisher
)
    Write-Info "=== Importing CER into LocalMachine trust stores ==="
    Write-Host "CER: $CerPath" -ForegroundColor DarkCyan

    if (-not (Test-IsAdmin)) {
        Write-Bad "This operation requires Administrator privileges."
        throw "Please run PowerShell as Administrator."
    }

    try {
        $rootStore = "Cert:\LocalMachine\Root"
        $pubStore  = "Cert:\LocalMachine\TrustedPublisher"

        if ($PSCmdlet.ShouldProcess($rootStore, "Import to Trusted Root")) {
            $r = Import-Certificate -FilePath $CerPath -CertStoreLocation $rootStore
            if ($r) { Write-Good "Imported into Trusted Root Certification Authorities." }
        }

        if (-not $SkipTrustedPublisher) {
            if ($PSCmdlet.ShouldProcess($pubStore, "Import to Trusted Publishers")) {
                $p = Import-Certificate -FilePath $CerPath -CertStoreLocation $pubStore
                if ($p) { Write-Good "Imported into Trusted Publishers." }
            }
        } else {
            Write-Warn "SkipTrustedPublisher was specified. Only Root was updated."
        }
    } catch {
        Write-Bad "ERROR importing CER: $($_.Exception.Message)"
        throw
    }
}

#-------------------------------#
# Optional: quick view helper
#-------------------------------#
function Show-DevCodeSigningCert {
[CmdletBinding()]
param(
    [Parameter(Mandatory=$False, HelpMessage="SubjectFilter")]
    [string]$SubjectFilter = "Code Signing"
)
    Write-Info "=== Listing Code Signing certs in CurrentUser\My ==="
    Get-ChildItem Cert:\CurrentUser\My |
        Where-Object { $_.EnhancedKeyUsageList.FriendlyName -match "Code Signing" -and $_.Subject -like "*$SubjectFilter*" } |
        Select-Object Subject, Thumbprint, NotAfter, PSParentPath |
        Format-Table -AutoSize
}

#-------------------------------#
# End of Toolkit
#-------------------------------#



<#
On your dev box (non-admin is fine):
$cert = New-DevCodeSigningCert -Subject "CN=Guillaume Plante (Dev Code Signing)" -Years 3 -OutDir "C:\Certs"
Export-DevCodeSigningCert -Certificate $cert -OutDir "C:\Certs" -PfxPassword "StrongP@ssw0rd!"


On each target machine (as Administrator):
Import-DevCodeSigningCertOnLocalMachine -CerPath "C:\Certs\devcodesign.cer"
# or skip TrustedPublisher if your policy only uses Root:
# Import-DevCodeSigningCertOnLocalMachine -CerPath "C:\Certs\devcodesign.cer" -SkipTrustedPublisher


#>