#╔════════════════════════════════════════════════════════════════════════════════╗
#║                                                                                ║
#║   CertsFuncs.ps1                                                               ║
#║                                                                                ║
#╟────────────────────────────────────────────────────────────────────────────────╢
#║   Guillaume Plante <codegp@icloud.com>                                         ║
#║   Code licensed under the GNU GPL v3.0. See the LICENSE file for details.      ║
#╚════════════════════════════════════════════════════════════════════════════════╝

$Script:privPath = "C:\www\public-certificates\arsscriptum-bmwtools.pfx"
$Script:certPath = "C:\www\public-certificates\arsscriptum-bmwtools.cer"
$Script:DebugLibPath = "C:\Users\guillaumep\Documents\PowerShell\Module-Development\PowerShell.Module.PackageDownloader\cs\bin\Debug\net6.0\PsProtectedModule.dll"
$Script:ReleaseLibPath = "C:\Users\guillaumep\Documents\PowerShell\Module-Development\PowerShell.Module.PackageDownloader\cs\bin\Debug\net6.0\PsProtectedModule.dll"


function Initialize-MyCertificate {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $cert = New-SelfSignedCertificate -Type CodeSigningCert `
         -Subject "CN=Arsscriptum QA CA" `
         -CertStoreLocation "Cert:\LocalMachine\My" `
         -KeyExportPolicy Exportable `
         -KeyUsage DigitalSignature `
         -KeyLength 2048 `
         -HashAlgorithm sha256 `
         -NotAfter (Get-Date).AddYears(1)


    $Credz = Get-AppCredentials -Id "root_certificate_arsscriptum"
    $password = $Credz.GetNetworkCredential().Password

    Export-Certificate -Cert $cert -FilePath "$Script:certPath"
    Export-PfxCertificate -Cert $cert -FilePath "$Script:privPath" -Password (ConvertTo-SecureString "$password" -AsPlainText -Force)
}

# Import usinmg powershell 5
#$Script:certPath = "C:\www\public-certificates\arsscriptum-bmwtools.cer"
#Import-Certificate -FilePath "$Script:certPath" -CertStoreLocation "Cert:\LocalMachine\Root"

function Invoke-SignDll {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0, Mandatory = $true, HelpMessage = "Path to the folder containing split parts")]
        [ValidateScript({ if (-not ($_ | Test-Path)) { throw "`"$Path`" does not exists" }
                elseif (-not ($_ | Test-Path -PathType Leaf)) { throw "directory paths are not allowed" } else { return $true } })]
        [string]$Path,
        [Parameter(Position = 1, Mandatory = $false, HelpMessage = "targets")]
        [ValidateSet("Debug", "Release", "All")]
        [string]$Target = "All"

    )
     $Credz = Get-AppCredentials -Id "root_certificate_arsscriptum"
    $password = $Credz.GetNetworkCredential().Password
    [string[]]$DllTargets = if ($Target -eq 'All') { @("Debug", "Release") } elseif ($Target -eq 'Release') { @("Release") } else { @("Debug") }
    $Pattern = foreach ($t in $DllTargets) { if ($Path.Contains("$t")) { $Path.Replace("$t", "{0}") } }
    [System.Collections.ArrayList]$ResultsList = [System.Collections.ArrayList]::new()
    $n = 0
    $SignTool = Get-SignToolExe
    foreach ($target in $DllTargets) {
        $dllPath = "$Pattern" -f $target
        if( (Test-Path "$($Script:privPath)") -And (Test-Path $dllPath) ) {
            $StdErrStr = ''
            $StdOutStr =
            Write-Verbose "Sign `"$dllPath`""
            [string[]]$Lines = & "$SignTool" "sign" "/f" "$Script:privPath" "/p" "$password" "/fd" "SHA256" "/tr" "http://timestamp.digicert.com" "/td" "SHA256" "$dllPath" 2>&1 | Where { $_.length -gt 0 }

            [pscustomobject]$SignToolResults = [pscustomobject]@{
                FullName = $dllPath
                Target = $target
                ExitCode = $LASTEXITCODE
                PrivateKeyFile = "$Script:privPath"
                FileName = Split-Path "$dllPath" -Leaf
                Success = $Lines.Where({ $_.ToLower().Contains("success") }) | Select -First 1
                Warnings = $Lines.Where({ $_.ToLower().Contains("warnings") }) | Select -First 1
                Errors = $Lines.Where({ $_.ToLower().Contains("errors") }) | Select -First 1
                StdErr = if ($LASTEXITCODE -ne 0) { (Get-Content -Path "$($PWD.Path)\stderr.log" | Where { $_.length -gt 0 }) -join ", " }
                StdOut = ($Lines[($Lines.Count - 1)..$($Lines.Count)] | Where { $_.length -gt 0 }) -join ", "
            }
            [void]$ResultsList.Add($SignToolResults)

        }
    }
    $ResultsList
}

function Get-MyCertificates {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { $_.Subject -eq "CN=Arsscriptum QA CA" }
}


function Remove-MyCertificates {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    if(!isadmin){
        Write-Error "Admin Required!"
    }
    $a=Read-Host "Are You Certain (y/N) ?"
    if($a -ne 'y'){ return }
    Get-MyCertificates | % { Write-host "Delete `"$($_.Thumbprint)`"" -f DarkRed; $_ | Remove-Item -Force -Confirm:$False }
}


function Test-DllSignatures {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0, Mandatory = $true, HelpMessage = "Path to the folder containing split parts")]
        [ValidateScript({ if (-not ($_ | Test-Path)) { throw "`"$Path`" does not exists" }
                elseif (-not ($_ | Test-Path -PathType Leaf)) { throw "directory paths are not allowed" } else { return $true } })]
        [string]$Path,
        [Parameter(Position = 1, Mandatory = $false, HelpMessage = "targets")]
        [ValidateSet("Debug", "Release", "All")]
        [string]$Target = "All"

    )
    [string[]]$DllTargets = if ($Target -eq 'All') { @("Debug", "Release") } elseif ($Target -eq 'Release') { @("Release") } else { @("Debug") }
    $Pattern = foreach ($t in $DllTargets) { if ($Path.Contains("$t")) { $Path.Replace("$t", "{0}") } }
    [System.Collections.ArrayList]$ResultsList = [System.Collections.ArrayList]::new()
    $n = 0
    $SignTool = Get-SignToolExe
    foreach ($target in $DllTargets) {
        $dllPath = "$Pattern" -f $target
        if (Test-Path $dllPath) {
            $StdErrStr = ''
            $StdOutStr =
            Write-Verbose "verify `"$dllPath`""
            [string[]]$Lines = & "$SignTool" "verify" "/pa" "/v" "$dllPath" 2>&1 | Where { $_.length -gt 0 }

            [pscustomobject]$SignToolResults = [pscustomobject]@{
                FullName = $dllPath
                Target = $target
                ExitCode = $LASTEXITCODE
                FileName = Split-Path "$dllPath" -Leaf
                Success = $Lines.Where({ $_.Contains("success") }) | Select -First 1
                Warnings = $Lines.Where({ $_.Contains("warnings") }) | Select -First 1
                Errors = $Lines.Where({ $_.Contains("errors") }) | Select -First 1
                StdErr = if ($LASTEXITCODE -ne 0) { (Get-Content -Path "$($PWD.Path)\stderr.log" | Where { $_.length -gt 0 }) -join ", " }
                StdOut = ($Lines[($Lines.Count - 1)..$($Lines.Count)] | Where { $_.length -gt 0 }) -join ", "
            }
            [void]$ResultsList.Add($SignToolResults)

        }
    }
    $ResultsList
}

function Test-DllSignatureForDebug {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Test-DllSignatures $Script:DebugLibPath "Debug"

}

function Test-DllSignatureForRelease {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Test-DllSignatures $Script:ReleaseLibPath "Release"

}

function Test-AllDllSignatures {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Test-DllSignatures $Script:ReleaseLibPath "All"
}



function Invoke-SignDebugDlls {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Invoke-SignDll $Script:DebugLibPath "Debug"

}

function Invoke-SignReleaseDlls {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Invoke-SignDll $Script:ReleaseLibPath "Release"

}

function Invoke-SignAllDlls {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Invoke-SignDll $Script:ReleaseLibPath "All"
}
