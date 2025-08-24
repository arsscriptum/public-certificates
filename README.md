
<center>
<img src="img/title.png" alt="title" />
</center>


Public Certificates. Used when signing Dlls or Executables that are to be deployed on the QA network or Production.

### Overview

* The `.pfx` file (PKCS#12) contains your private key plus the certificate. You need it to *sign* things (DLLs, EXEs). **Nobody else** (including QA) should ever need or see your `.pfx`. That’s your signing identity, like the key to your vault.
* The `.cer` file usually contains just the public certificate (and optionally the full chain if you exported with it). That’s what your QA needs to *trust* your signatures.

### Workflow

1. **Owner or Developer, me** use the `.pfx` with `signtool.exe` (or whatever signing tool) to sign the DLL.
2. **QA** machines won’t recognize your self-signed cert by default, so Windows will say “unknown publisher.”
3. To fix that, QA needs to install your **.cer** into the **Trusted Root Certification Authorities** store (or, at minimum, into the **Trusted Publishers** store if you don’t want to make it a root).

👉 Recommendation:

* Export your certificate without the private key (`.cer`).
* Give that to QA.
* They install it in **Trusted Root Certification Authorities** so Windows will treat any DLL/EXE signed by your `.pfx` as valid.

This way, the DLL will show as valid and trusted when they check its digital signature.


### PFX is archived Encrypted using AES Cipher Function ```Invoke-AesBinaryEncryption```

**To Get Private Key (pfx)**

```powershell
Invoke-AesBinaryEncryption -InputFile "arsscriptum-bmwtools.pfx.aes" -OutputFile "arsscriptum-bmwtools.pfx" -Password "..." -Mode Decrypt
```

## Installing Certificates

**Guillaume's Note** -> *Security nudge: for QA environments, **Trusted Publishers** is usually the sweet spot—your signed DLLs validate, but the cert isn’t promoted to a root CA*

here’s the PowerShell way your QA team can do it without poking around in MMC

## Using PowerShell
```powershell
# Run as Administrator if installing into LocalMachine
$CertUrl  = "https://arsscriptum.github.io/public-certificates/arsscriptum-bmwtools.cer"

# Download the certificate bytes
$CertBytes = Invoke-WebRequest -Uri $CertUrl -UseBasicParsing
$Cert      = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
$Cert.Import($CertBytes.Content)

# Install into LocalMachine Trusted Root Certification Authorities
$Store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root","LocalMachine")
$Store.Open("ReadWrite")
$Store.Add($Cert)
$Store.Close()

Write-Host "Installed certificate from $CertUrl into Trusted Root Certification Authorities."
```

#### Important clarifications for QA:

* They must run this **in an elevated PowerShell** (`Run as Administrator`) to install into the LocalMachine root.
* After this, DLLs/EXEs signed by you with the matching `.pfx` will show as trusted.


## Command‑line (no PowerShell)

### A) Machine‑wide (requires **elevated** Command Prompt)

Installs to **Trusted Root Certification Authorities** so Windows fully trusts your signatures.

```bat
:: Run from an elevated CMD (Administrator)
set URL=https://arsscriptum.github.io/public-certificates/arsscriptum-bmwtools.cer
set DST=%TEMP%\arsscriptum-bmwtools.cer

curl -L -o "%DST%" "%URL%"  && ^
certutil -addstore -f "Root" "%DST%"  && ^
del "%DST%"

echo Installed to LocalMachine\Root (Trusted Root Certification Authorities).
```

### (Tighter) Trusted Publishers instead of Root

This trusts only software signed with your cert without making it a root CA:

```bat
:: Elevated CMD
set URL=https://arsscriptum.github.io/public-certificates/arsscriptum-bmwtools.cer
set DST=%TEMP%\arsscriptum-bmwtools.cer

curl -L -o "%DST%" "%URL%"  && ^
certutil -addstore -f "TrustedPublisher" "%DST%"  && ^
del "%DST%"

echo Installed to LocalMachine\TrustedPublisher (Trusted Publishers).
```

## B) Current user only (no admin required)

Installs to the **current user** stores.

```bat
:: Non-elevated CMD
set URL=https://arsscriptum.github.io/public-certificates/arsscriptum-bmwtools.cer
set DST=%TEMP%\arsscriptum-bmwtools.cer

curl -L -o "%DST%" "%URL%"  && ^
certutil -user -addstore -f "Root" "%DST%"  && ^
del "%DST%"

echo Installed to CurrentUser\Root.
```

Or, for **Trusted Publishers** (safer):

```bat
:: Non-elevated CMD
set URL=https://arsscriptum.github.io/public-certificates/arsscriptum-bmwtools.cer
set DST=%TEMP%\arsscriptum-bmwtools.cer

curl -L -o "%DST%" "%URL%"  && ^
certutil -user -addstore -f "TrustedPublisher" "%DST%"  && ^
del "%DST%"

echo Installed to CurrentUser\TrustedPublisher.
```

> Tip: `curl.exe` is built into Windows 10/11. If it’s blocked, you can swap the download line for:
>
> ```
> certutil -urlcache -split -f "%URL%" "%DST%"
> ```

# GUI (MMC) — no scripting at all

1. Press `Win+R`, run `mmc`.
2. File → Add/Remove Snap‑in → **Certificates**.
3. Choose **Computer account** (for machine‑wide) or **My user account** (for user‑scope).
4. Expand **Trusted Root Certification Authorities** (or **Trusted Publishers**).
5. Right‑click **Certificates** → **All Tasks** → **Import…**.
6. Paste the URL into a browser, download the `.cer`, then select it in the wizard → Next → Finish.

# Verify it worked (either method)

* Check presence:

  * Machine store: `certutil -store "Root"` or `certutil -store "TrustedPublisher"`
  * User store: `certutil -user -store "Root"` or `certutil -user -store "TrustedPublisher"`
* Validate DLL signature in File Properties → Digital Signatures.

# Uninstall / rollback

Find the certificate’s **Thumbprint** (from the `certutil -store` output), then:

```bat
:: Remove from LocalMachine Root
certutil -delstore "Root" <THUMBPRINT>

:: Remove from LocalMachine Trusted Publishers
certutil -delstore "TrustedPublisher" <THUMBPRINT>

:: For user stores, add -user
certutil -user -delstore "TrustedPublisher" <THUMBPRINT>
```
