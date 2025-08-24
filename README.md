# Certificates

Public Certificates. Used when signing Dlls or Executables that are to be deployed on the QA network or Production.

**To Get Private Key (pfx)**

```powershell
Invoke-AesBinaryEncryption -InputFile "arsscriptum-bmwtools.pfx.aes" -OutputFile "arsscriptum-bmwtools.pfx" -Password "..." -Mode Decrypt
```