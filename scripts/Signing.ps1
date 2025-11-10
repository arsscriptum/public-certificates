#===============================================================================
# SignatureProperties
#===============================================================================

class SignatureProperties {
    [string]$ValidCertificate = '6B4CF957BD8C08AE7628DC976D903ECE578C175F'
}

function Get-LocalSigningCert {
    <#
    .SYNOPSIS
        Get signing certificate
    .LINK
        https://github.com/arsscriptum/PowerShell.Sandbox/blob/main/Signing/Signing.ps1
    #>    
    $SignProps = [SignatureProperties]::new()
    $Instance = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Where-Object Thumbprint -eq "$($SignProps.ValidCertificate)"
    if (-not $Instance) {
        Write-Warning "⚠️ No signing certificate found with thumbprint $($SignProps.ValidCertificate)"
    }
    return $Instance
}

function Add-Signature {
    <#
    .SYNOPSIS
        Sign a script
    .DESCRIPTION
        Sign a script using a self-signed certificate
    .PARAMETER Path
        The Path of the script to sign
    .EXAMPLE
         Add-Signature -Path .\helloworld.ps1
    .LINK
        https://github.com/arsscriptum/PowerShell.Sandbox/blob/main/Signing/Signing.ps1
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            if (-not (Test-Path $_ -PathType Leaf)) {
                throw "The file '$_' does not exist or is not a valid file."
            }
            return $true
        })]
        [string]$Path
    )

    try {
        $Ok = $False
        $ExceptMsg = ''

        $cert = Get-LocalSigningCert
        if ($null -eq $cert) { throw "Cannot find signing certificate." }
        if ($cert.NotAfter -lt (Get-Date)) { throw "Signing certificate is expired." }

        Write-Host "✅ Get Signing Certificate"
        $Res = Set-AuthenticodeSignature -FilePath $Path -Certificate $cert
        Write-Host "✅ Set-AuthenticodeSignature on $Path. Status: $($Res.Status), $($Res.StatusMessage)"
        $Ok = $True

    } catch {
        [System.Management.Automation.ErrorRecord]$Record = $_
        $ExceptMsg = "[ERROR] Signing $Path : $($Record.FullyQualifiedErrorId)"
        $Ok = $False
    }

    if (-not $Ok) {
        throw [System.InvalidOperationException]::new($ExceptMsg)
    }
}

function Check-Signature {
    <#
    .SYNOPSIS
        Validate a script signature
    .PARAMETER Path
        The Path of the script to validate
    .EXAMPLE
         Check-Signature -Path .\helloworld.ps1
    .LINK
        https://github.com/arsscriptum/PowerShell.Sandbox/blob/main/Signing/Signing.ps1
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            if (-not (Test-Path $_ -PathType Leaf)) {
                throw "The file '$_' does not exist or is not a valid file."
            }
            return $true
        })]
        [string]$Path
    )

    try {
        $Ok = $False
        $ExceptMsg = ''

        $cert = Get-LocalSigningCert
        if ($null -eq $cert) { throw "Cannot find signing certificate." }

        Write-Host "✅ Get Signing Certificate"
        $Res = Get-AuthenticodeSignature -FilePath $Path
        $Status = $Res.Status
        $StatusMessage = $Res.StatusMessage
        $SignerCert = $Res.SignerCertificate

        if ($Status -ne 'Valid') {
            throw "Script not signed or invalid signature!"
        }
        if ($SignerCert.Thumbprint -ne $cert.Thumbprint) {
            throw "Script signed with wrong certificate: $($SignerCert.Thumbprint)"
        }

        Write-Host "✅ Signature $Path. Status: $Status, $StatusMessage"
        $Ok = $True

    } catch {
        [System.Management.Automation.ErrorRecord]$Record = $_
        $ExceptMsg = "[ERROR] Verification failed for $Path : $($Record.FullyQualifiedErrorId)"
        $Ok = $False
    }

    if (-not $Ok) {
        throw [System.InvalidOperationException]::new($ExceptMsg)
    }
}
