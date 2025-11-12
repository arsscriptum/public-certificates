

function Sign-BinaryWithPfx {
    param (
        [Parameter(Mandatory=$true)]
        [string]$BinaryPath,
        [Parameter(Mandatory=$true)]
        [string]$PfxPassword
    )

    $pfxPath = "$env:CODESIGNINGCERTPFX"

    if ([string]::IsNullOrWhiteSpace($pfxPath)) {
        Write-Error "Environment variable 'CODESIGNINGCERTPFX' is not set."
        return
    }
    if (-not (Test-Path $pfxPath)) {
        Write-Error "PFX file '$pfxPath' not found."
        return
    }
    if (-not (Test-Path $BinaryPath)) {
        Write-Error "Binary file '$BinaryPath' not found."
        return
    }

    $dir = Split-Path $BinaryPath
    $base = [System.IO.Path]::GetFileNameWithoutExtension($BinaryPath)
    $ext = [System.IO.Path]::GetExtension($BinaryPath)
    $signedPath = Join-Path $dir "${base}_SIGNED${ext}"

    Copy-Item $BinaryPath $signedPath -Force

    $signtool = Get-SignToolExe
    $args = @(
        "sign"
        "/f", $pfxPath
        "/p", $PfxPassword
        "/fd", "sha256"
        "/tr", "http://timestamp.digicert.com"
        "/td", "sha256"
        $signedPath
    )

    & $signtool @args
}

# Example usage:
# Sign-BinaryWithPfx -BinaryPath "C:\tmp\myapp.exe" -PfxPassword "mysecret"
