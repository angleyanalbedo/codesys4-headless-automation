# CODESYS 4 CI Pipeline Reference

This example is intentionally library-focused. Adapt the installation path and project path to the runner.

```powershell
$ErrorActionPreference = 'Stop'

$C4Cli = 'C:\Program Files\CODESYS-4\c4-cli.exe'
$LibraryPath = Join-Path $env:GITHUB_WORKSPACE 'src\ControlLib.fbslib'
$ArtifactDir = Join-Path $env:GITHUB_WORKSPACE 'artifacts'
$ArtifactPath = Join-Path $ArtifactDir 'ControlLib.compiled-library-v3'

if (-not (Test-Path -LiteralPath $C4Cli)) {
    throw "CODESYS 4 CLI not found: $C4Cli"
}
if (-not (Test-Path -LiteralPath $LibraryPath)) {
    throw "CODESYS 4 library project not found: $LibraryPath"
}

New-Item -ItemType Directory -Force -Path $ArtifactDir | Out-Null

& $C4Cli version
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $C4Cli library resolve $LibraryPath --log-level error
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $C4Cli library check $LibraryPath --log-level error
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $C4Cli library save-compiled $LibraryPath $ArtifactPath --overwrite --log-level error
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$Artifact = Get-Item -LiteralPath $ArtifactPath
if ($Artifact.Length -le 0) {
    throw "Compiled artifact is empty: $ArtifactPath"
}

$Hash = Get-FileHash -Algorithm SHA256 -LiteralPath $ArtifactPath
Write-Host "CODESYS_COMPILE_STATUS=PASS"
Write-Host "CODESYS_ARTIFACT=$($Artifact.FullName)"
Write-Host "CODESYS_ARTIFACT_BYTES=$($Artifact.Length)"
Write-Host "CODESYS_ARTIFACT_SHA256=$($Hash.Hash)"
```

## Expected successful output

The important signals are:

```text
Compile complete -- 0 errors, 0 warnings
CODESYS_COMPILE_STATUS=PASS
```

The command must also return exit code `0` and create a non-empty `.compiled-library-v3` file.

## Tested local baseline

The following local installation was tested successfully:

- `C:\Program Files\CODESYS-4\c4-cli.exe`
- source library: `SmokeLib.fbslib`
- IEC source: `AddOne.fn.st`
- compiler: `3.5.22.30`
- result: `0 errors, 0 warnings`
- compiled artifact size: `6252` bytes

